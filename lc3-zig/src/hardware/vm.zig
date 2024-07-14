const std = @import("std");
const expect = std.testing.expect;

const stdin = std.io.getStdIn().reader(); // does not work if running on Windows, stdin is runtime on Windows, put it inside a function
const stdout = std.io.getStdOut().writer();

const registers = @import("registers.zig");
const r = registers.Register;
const cond = registers.Condition;

pub var memory = [_]u16{0} ** 0xFFFF;
pub var reg = [_]u16{0} ** @intFromEnum(r.R_COUNT);

pub const Instruction = enum(u4) {
    OP_BR = 0, // branch
    OP_ADD, // add
    OP_LD, // load
    OP_ST, // store
    OP_JSR, // jump register
    OP_AND, // bitwise and
    OP_LDR, // load register
    OP_STR, // store register
    OP_RTI, // unused
    OP_NOT, // bitwise not
    OP_LDI, // load indirect
    OP_STI, // store indirect
    OP_JMP, // jump
    OP_RES, // reserved (unused)
    OP_LEA, // load effective address
    OP_TRAP, // execute trap
};

pub const TrapCodes = enum(u8) {
    TRAP_GETC = 0x20,
    TRAP_OUT = 0x21,
    TRAP_PUTS = 0x22,
    TRAP_IN = 0x23,
    TRAP_PUTSP = 0x24,
    TRAP_HALT = 0x25,
};

fn nextLine(reader: anytype, buffer: []u8) !?[]const u8 {
    const line = (try reader.readUntilDelimiterOrEof(
        buffer,
        '\n',
    )) orelse return null;
    // trim annoying windows-only carriage return character
    if (@import("builtin").os.tag == .windows) {
        return std.mem.trimRight(u8, line, "\r");
    } else {
        return line;
    }
}

fn write(writer: anytype, buffer: []const u8) void {
    writer.print("{s}", .{buffer}) catch std.debug.print("Could not write to stdout\n", .{});
}

pub fn signExtend(uint: anytype, bit_count: u4) i16 {
    var raw_uint: u16 = undefined;
    if ((uint >> (bit_count - 1)) & 1 == 1) {
        raw_uint = uint | (@as(u16, 0xFFFF)) << bit_count;
    } else {
        raw_uint = uint;
    }
    return @as(i16, @bitCast(raw_uint));
}

pub fn readSigned(uint: u16) i16 {
    return @as(i16, @bitCast(uint));
}

pub fn addSigned(uint: u16, int: i16) u16 {
    if (int < 0) {
        return uint -% @as(u16, @intCast(-1 * int));
    } else {
        return uint +% @as(u16, @intCast(int));
    }
}

pub fn updateFlag(register: r) void {
    if (reg[@intFromEnum(register)] == 0) {
        reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);
    } else if (reg[@intFromEnum(register)] >> 15 == 1) {
        reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_N);
    } else {
        reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_P);
    }
}
pub fn opADD(op: u16) void {
    var value: i16 = undefined;
    if (op >> 5 & 1 == 1) { //immediate
        value = signExtend(op & 0b11_111, 5);
    } else {
        const register = op & 0b111;
        const raw_value = reg[@as(usize, @intCast(register))];
        value = readSigned(raw_value);
    }
    const DR = @shrExact(op & 0b111_000_000_000, 9);
    const SR = @shrExact(op & 0b111_000_000, 6);
    reg[DR] = addSigned(reg[SR], value);
    updateFlag(@enumFromInt(DR));
}
test "ADD test" {
    const op = 0b0001_010_000_000_001; //R2 = R0 + R1
    const op2 = 0b0001_010_000_1_10000; //R2 = R0 + -16
    reg[@intFromEnum(r.R_0)] = 30;
    reg[@intFromEnum(r.R_1)] = 10;
    reg[@intFromEnum(r.R_2)] = 50;
    std.debug.print("ADD Before: {any}\n", .{reg});

    opADD(op);
    std.debug.print("After 1: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_2)] == 30 + 10);
    opADD(op2);
    std.debug.print("After 2: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_2)] == 30 - 16);
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);
}
pub fn opAND(op: u16) void {
    var value: i16 = undefined;
    if (op >> 5 & 1 == 1) { //immediate
        value = signExtend(op & 0b11_111, 5);
    } else {
        const register = @shrExact(op & 0b111, 0);
        const raw_value = reg[@as(usize, @intCast(register))];
        value = readSigned(raw_value);
    }
    const DR = @shrExact(op & 0b111_000_000_000, 9);
    const SR = @shrExact(op & 0b111_000_000, 6);
    reg[DR] = reg[SR] & @as(u16, @bitCast(value));
    updateFlag(@enumFromInt(DR));
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);
}
test "AND test" {
    const op = 0b0101_010_000_000_001; //R2 = R0 & R1
    const op2 = 0b0101_010_000_1_10000; //R2 = R0 & -16
    reg[@intFromEnum(r.R_0)] = 0b111_111; // 63
    reg[@intFromEnum(r.R_1)] = 91;
    reg[@intFromEnum(r.R_2)] = 10;
    std.debug.print("AND Before: {any}\n", .{reg});
    opAND(op);
    std.debug.print("After 1: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_2)] == 63 & 91);
    opAND(op2);
    std.debug.print("After 2: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_2)] == 63 & -16);
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);
}
pub fn opBR(op: u16) void {
    const pc_offset: i16 = signExtend(op & 0b111_111_111, 9);
    if (op >> 9 & reg[@intFromEnum(r.R_COND)] != 0) {
        reg[@intFromEnum(r.R_PC)] = addSigned(reg[@intFromEnum(r.R_PC)], pc_offset);
        // const raw_value, _ = @addWithOverflow(@as(i17, reg[@intFromEnum(r.R_PC)]), @as(i16, @bitCast(pc_offset)));
        // reg[@intFromEnum(r.R_PC)] = @as(u16, @bitCast(@as(i16, @truncate(raw_value))));
    }
}
test "BR test" {
    const op = 0b0000_001_000_000_001; //PC += 1
    const op2 = 0b0000_100_111_111_111; //PC -= 1
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_P);
    reg[@intFromEnum(r.R_PC)] = 1000;
    std.debug.print("BR Before: {any}\n", .{reg});
    opBR(op);
    std.debug.print("After 1: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_PC)] == 1000 + 1);

    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_N);
    opBR(op2);
    std.debug.print("After 2: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_PC)] == 1001 - 1);
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);
}
pub fn opJMP(op: u16) void {
    const BaseR = @as(usize, op >> 6 & 0b111);
    reg[@intFromEnum(r.R_PC)] = reg[BaseR];
}
test "JMP test" {
    const op = 0b1100_000_001_000_000; //PC = R1
    reg[@intFromEnum(r.R_PC)] = 1000;
    reg[@intFromEnum(r.R_1)] = 5000;
    std.debug.print("JMP Before: {any}\n", .{reg});
    opJMP(op);
    std.debug.print("After 1: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_PC)] == 5000);
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);
}
pub fn opJSR(op: u16) void {
    reg[@intFromEnum(r.R_7)] = reg[@intFromEnum(r.R_PC)];
    var value: i16 = undefined;
    if (op >> 11 & 1 == 1) { //immediate
        value = signExtend(op & 0b111_111_111_11, 11);
        reg[@intFromEnum(r.R_PC)] = addSigned(reg[@intFromEnum(r.R_PC)], value);
        // const raw_value, _ = @addWithOverflow(@as(i17, reg[@intFromEnum(r.R_PC)]), @as(i16, @bitCast(value)));
        // reg[@intFromEnum(r.R_PC)] = @as(u16, @bitCast(@as(i16, @truncate(raw_value))));
    } else {
        const BaseR = @as(usize, op >> 6 & 0b111);
        reg[@intFromEnum(r.R_PC)] = reg[BaseR];
    }
}
test "JSR/JSRR test" {
    const op = 0b0100_1_000_000_100_00; //PC += 0b10000
    const op2 = 0b0100_0_00_001_000_000; //PC = R1
    reg[@intFromEnum(r.R_PC)] = 1234;
    reg[@intFromEnum(r.R_1)] = 5000;
    std.debug.print("Before: {any}\n", .{reg});
    opJSR(op);
    std.debug.print("After 1: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_PC)] == 1234 + 0b10000);
    try expect(reg[@intFromEnum(r.R_7)] == 1234);
    opJSR(op2);
    std.debug.print("After 1: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_PC)] == 5000);
    try expect(reg[@intFromEnum(r.R_7)] == 1234 + 0b10000);
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);
}
pub fn opLD(op: u16) void {
    const DR = @as(usize, op >> 9 & 0b111);
    const pc_offset: i16 = signExtend(op & 0b111_111_111, 9);
    const addr: usize = addSigned(reg[@intFromEnum(r.R_PC)], pc_offset);
    reg[DR] = memory[addr];
    updateFlag(@enumFromInt(DR));
}
test "LD test" {
    const op = 0b0010_001_001_000_000; //R1 = mem[PC + 0b1000000]
    reg[@intFromEnum(r.R_PC)] = 1234;
    reg[@intFromEnum(r.R_1)] = 5000;
    memory[0b1_000_000 + 1234] = 0xBEEF;
    std.debug.print("LD Before 1: {any}", .{reg});
    std.debug.print("{x}\n", .{memory[0b1_000_000 + 1234]});
    opLD(op);
    std.debug.print("After 1: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_1)] == 0xBEEF); //48879
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);

    const op2 = 0b0010_001_111_111_000; //R1 = mem[PC - 0b1000]
    reg[@intFromEnum(r.R_PC)] = 1234;
    reg[@intFromEnum(r.R_1)] = 5000;
    memory[-8 + 1234] = 0xDEAD;
    std.debug.print("LD Before 2: {any}", .{reg});
    std.debug.print("{x}\n", .{memory[-8 + 1234]});
    opLD(op2);
    std.debug.print("After 2: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_1)] == 0xDEAD); //57005
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);
}

pub fn opLDI(op: u16) void {
    const DR = @as(usize, op >> 9 & 0b111);
    const pc_offset: i16 = signExtend(op & 0b111_111_111, 9);
    const addr: usize = addSigned(reg[@intFromEnum(r.R_PC)], pc_offset);
    reg[DR] = memory[addr];
    reg[DR] = memory[@as(usize, reg[DR])];
    updateFlag(@enumFromInt(DR));
}

test "LDI test" {
    const op = 0b1010_001_001_000_000; //PC = mem[mem[0b1000000+PC]]
    reg[@intFromEnum(r.R_PC)] = 1234;
    reg[@intFromEnum(r.R_1)] = 5000;
    memory[0b1_000_000 + 1234] = 0xBEEF;
    memory[0xBEEF] = 0xEEEE;
    std.debug.print("Before: {any}", .{reg});
    std.debug.print("{x}\n", .{memory[0b1_000_000 + 1234]});
    std.debug.print("{x}\n", .{memory[0xBEEF]});
    opLDI(op);
    std.debug.print("After 1: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_1)] == 0xEEEE); //61166
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);

    const op2 = 0b1010_001_111_000_000; //PC = mem[mem[-0b1000000+PC]]
    reg[@intFromEnum(r.R_PC)] = 1234;
    reg[@intFromEnum(r.R_1)] = 5000;
    memory[-0b1_000_000 + 1234] = 0xBEEF;
    memory[0xBEEF] = 0xFFFF;
    std.debug.print("Before: {any}", .{reg});
    std.debug.print("{x}\n", .{memory[-0b1_000_000 + 1234]});
    std.debug.print("{x}\n", .{memory[0xBEEF]});
    opLDI(op2);
    std.debug.print("After 1: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_1)] == 0xFFFF); //65535
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);
}

pub fn opLDR(op: u16) void {
    const DR = @as(usize, op >> 9 & 0b111);
    const BaseR = @as(usize, op >> 6 & 0b111);
    const offset6: i16 = signExtend(op & 0b111_111, 6);
    reg[DR] = memory[addSigned(reg[BaseR], offset6)];
    updateFlag(@enumFromInt(DR));
}

test "LDR test" {
    const op = 0b0110_001_010_000_100; //R1 = mem[R2+0b100]
    reg[@intFromEnum(r.R_2)] = 1234;
    reg[@intFromEnum(r.R_1)] = 5000;
    memory[0b100 + 1234] = 0xBEEF;
    std.debug.print("LDR Before 1: {any}", .{reg});
    std.debug.print("{x}\n", .{memory[0b100 + 1234]});
    opLDR(op);
    std.debug.print("After 1: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_1)] == 0xBEEF);
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);

    const op2 = 0b0110_001_010_111_100; //R1 = mem[R2-0b100]
    reg[@intFromEnum(r.R_2)] = 1234;
    reg[@intFromEnum(r.R_1)] = 5000;
    memory[-0b100 + 1234] = 0xDEAD;
    std.debug.print("LDR Before 2: {any}", .{reg});
    std.debug.print("{x}\n", .{memory[-0b100 + 1234]});
    opLDR(op2);
    std.debug.print("After 2: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_1)] == 0xDEAD);
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);
}

pub fn opLEA(op: u16) void {
    const DR = @as(usize, op >> 9 & 0b111);
    const pc_offset = signExtend(op & 0b111_111_111, 9);
    reg[DR] = addSigned(reg[@intFromEnum(r.R_PC)], pc_offset);
    updateFlag(@enumFromInt(DR));
}
test "LEA test" {
    const op = 0b1110_001_000_000_100; //R1 = PC+0b100
    reg[@intFromEnum(r.R_1)] = 5000;
    reg[@intFromEnum(r.R_PC)] = 1234;
    std.debug.print("LEA Before: {any}\n", .{reg});
    opLEA(op);
    std.debug.print("After 1: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_1)] == 1234 + 0b100);
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);

    const op2 = 0b1110_001_111_111_000; //R1 = PC-0b1_000
    reg[@intFromEnum(r.R_1)] = 5000;
    reg[@intFromEnum(r.R_PC)] = 1234;
    opLEA(op2);
    std.debug.print("After 2: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_1)] == 1234 - 0b1000);
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);
}

pub fn opNOT(op: u16) void {
    const DR = op >> 9 & 0b111;
    const SR = op >> 6 & 0b111;
    reg[DR] = ~reg[SR];
    updateFlag(@enumFromInt(DR));
}

test "NOT test" {
    const op = 0b1001_001_010_111_111; //PC = mem[R2+0b100]
    reg[@intFromEnum(r.R_1)] = 5000;
    reg[@intFromEnum(r.R_2)] = 0b1111_0000_1111_0000;
    std.debug.print("NOT Before: {any}\n", .{reg});
    opNOT(op);
    std.debug.print("After 1: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_1)] == 0b0000_1111_0000_1111);
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);
}

pub fn opRET(op: u16) void {
    const BaseR = @as(usize, op >> 6 & 0b111);
    reg[@intFromEnum(r.R_PC)] = reg[BaseR];
}
test "RET test" {
    const op = 0b1100_000_111_000_000; //PC = R7
    reg[@intFromEnum(r.R_PC)] = 1000;
    reg[@intFromEnum(r.R_7)] = 5000;
    std.debug.print("RET Before: {any}\n", .{reg});
    opJMP(op);
    std.debug.print("After 1: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_PC)] == 5000);
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);
}

pub fn opST(op: u16) void {
    const SR = @as(usize, op >> 9 & 0b111);
    const pc_offset: i16 = signExtend(op & 0b111_111_111, 9);
    const addr: usize = addSigned(reg[@intFromEnum(r.R_PC)], pc_offset);
    memory[addr] = reg[SR];
}
test "ST test" {
    const op = 0b0011_001_000_100_000; //PC = mem[0b100000+PC]
    reg[@intFromEnum(r.R_PC)] = 1234;
    reg[@intFromEnum(r.R_1)] = 5555;
    std.debug.print("ST Before: {any}\n", .{reg});
    opST(op);
    std.debug.print("After 1: {any}", .{reg});
    std.debug.print("{}\n", .{memory[0b100_000 + 1234]});
    try expect(memory[1234 + 0b100_000] == 5555);
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);

    const op2 = 0b0011_001_111_100_000; //PC = mem[-0b100000+PC]
    reg[@intFromEnum(r.R_PC)] = 1234;
    reg[@intFromEnum(r.R_1)] = 5555;
    opST(op2);
    std.debug.print("After 2: {any}", .{reg});
    std.debug.print("{}\n", .{memory[-0b100_000 + 1234]});
    try expect(memory[1234 + -0b100_000] == 5555);
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);
}

pub fn opSTI(op: u16) void {
    const SR = @as(usize, op >> 9 & 0b111);
    const pc_offset: i16 = signExtend(op & 0b111_111_111, 9);
    const addr: usize = addSigned(reg[@intFromEnum(r.R_PC)], pc_offset);
    memory[addr] = reg[SR];
}
test "STI test" {
    const op = 0b0011_001_000_100_000; //PC = mem[mem[0b100000+PC]]
    reg[@intFromEnum(r.R_PC)] = 1234;
    reg[@intFromEnum(r.R_1)] = 5555;
    memory[0b100_000 + 1234] = 0xAAAA;
    memory[0xAAAA] = 5555;
    std.debug.print("STI Before 1: {any}", .{reg});
    std.debug.print("{x}\n", .{memory[0b100_000 + 1234]});
    opSTI(op);
    std.debug.print("After 1: {any}", .{reg});
    std.debug.print("{}\n", .{memory[0xAAAA]});
    try expect(memory[0xAAAA] == 5555);
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);

    const op2 = 0b0011_001_111_100_000; //PC = mem[mem[-0b100000+PC]]
    reg[@intFromEnum(r.R_PC)] = 1234;
    reg[@intFromEnum(r.R_1)] = 5555;
    memory[-0b100_000 + 1234] = 0xBBBB;
    memory[0xBBBB] = 4444;
    std.debug.print("STI Before 2: {any}", .{reg});
    std.debug.print("{x}\n", .{memory[-0b100_000 + 1234]});
    opSTI(op2);
    std.debug.print("After 2: {any}", .{reg});
    std.debug.print("{}\n", .{memory[0xBBBB]});
    try expect(memory[0xBBBB] == 4444);
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);
}
pub fn opSTR(op: u16) void {
    const SR = @as(usize, op >> 9 & 0b111);
    const BaseR = @as(u16, op >> 6 & 0b111);
    const pc_offset: i16 = signExtend(op & 0b111_111, 6);
    const addr: usize = addSigned(reg[BaseR], pc_offset);
    memory[addr] = reg[SR];
}

test "STR test" {
    const op = 0b0111_001_010_000_100; //mem[R2+0b100] = R1
    reg[@intFromEnum(r.R_2)] = 1234;
    reg[@intFromEnum(r.R_1)] = 727;
    std.debug.print("Before: {any}\n", .{reg});
    opSTR(op);
    std.debug.print("After 1: {any}", .{reg});
    std.debug.print("{}\n", .{memory[0b100 + 1234]});
    try expect(memory[0b100 + 1234] == 727);
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);

    const op2 = 0b0111_001_010_111_100; //mem[R2+-0b100] = R1
    reg[@intFromEnum(r.R_2)] = 1234;
    reg[@intFromEnum(r.R_1)] = 9999;
    std.debug.print("Before: {any}\n", .{reg});
    opSTR(op2);
    std.debug.print("After 1: {any}", .{reg});
    std.debug.print("{}\n", .{memory[-0b100 + 1234]});
    try expect(memory[-0b100 + 1234] == 9999);
    reg = [1]u16{0} ** 10;
    reg[@intFromEnum(r.R_COND)] = @intFromEnum(cond.FL_Z);
}

const IOError = error{
    InputError,
    OutputError,
};

pub fn opTRAP(op: u16) IOError!void {
    reg[@intFromEnum(r.R_7)] = reg[@intFromEnum(r.R_PC)];
    const trap_code: TrapCodes = @enumFromInt(op & 0b1111_1111);
    switch (trap_code) {
        TrapCodes.TRAP_GETC => {
            const char: u8 = stdin.readByte() catch '0';
            reg[@intFromEnum(r.R_0)] = @as(u16, char);
        },
        TrapCodes.TRAP_OUT => {
            stdout.print("{u}", .{reg[@intFromEnum(r.R_0)]}) catch return IOError.OutputError;
        },
        TrapCodes.TRAP_PUTS => {
            const ptr = @as(usize, reg[@intFromEnum(r.R_0)]);
            var i: usize = 0;
            while (memory[ptr + i] != 0) : (i += 1) {
                stdout.print("{u}", .{memory[ptr + i]}) catch return IOError.OutputError;
                if (ptr + i > memory.len) break;
            }
        },
        TrapCodes.TRAP_IN => {
            const char: u8 = stdin.readByte() catch '0';
            stdout.print("{u}", .{char}) catch return IOError.OutputError;
            reg[@intFromEnum(r.R_0)] = @as(u16, char);
        },
        TrapCodes.TRAP_PUTSP => {
            const ptr = @as(usize, reg[@intFromEnum(r.R_0)]);
            var i: usize = 0;
            while (memory[ptr + i] >> 8 != 0) : (i += 1) {
                stdout.print("{u}{u}", .{ memory[ptr + i] & 0b1111_1111, memory[ptr + i] >> 8 }) catch return IOError.OutputError;
                if (ptr + i > memory.len) break;
            }
        },
        TrapCodes.TRAP_HALT => {
            stdout.print("HALT\n", .{}) catch return IOError.OutputError;
            std.process.exit(0);
        },
    }
}

test "TRAP test" {
    std.debug.print("Before: {any}\n", .{reg});
    std.debug.print("Enter C\\n\n", .{});
    const op1 = 0b1111_0000_0000_0000 + 0x20;
    opTRAP(op1) catch |err| std.debug.print("{any} Errored\n", .{err});
    std.debug.print("After GETC: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_0)] == 'C');

    const op2 = 0b1111_0000_0000_0000 + 0x21;
    opTRAP(op2) catch |err| std.debug.print("{any} Errored\n", .{err});
    std.debug.print("\t<- Should have printed \"C\"\n", .{});

    const op3 = 0b1111_0000_0000_0000 + 0x22;
    reg[@intFromEnum(r.R_0)] = 0x4000;
    var data: [5]u16 = undefined;
    _ = std.unicode.utf8ToUtf16Le(&data, "HELLO") catch unreachable;
    std.mem.copyForwards(u16, memory[0x4000..0x400A], data[0..]);
    opTRAP(op3) catch |err| std.debug.print("{any} Errored\n", .{err});
    std.debug.print("\t<- Should have printed \"HELLO\"\n", .{});

    const op4 = 0b1111_0000_0000_0000 + 0x23;
    std.debug.print("Enter C\\n\n", .{});
    opTRAP(op4) catch |err| std.debug.print("{any} Errored\n", .{err});
    std.debug.print("After IN: {any}\n", .{reg});
    try expect(reg[@intFromEnum(r.R_0)] == 'C');

    const op5 = 0b1111_0000_0000_0000 + 0x24;
    reg[@intFromEnum(r.R_0)] = 0x400A;

    const str = "hellohello";
    var i: usize = 0;
    while (i < str.len) : (i += 2) {
        var wide: u16 = str[i];
        if (i < str.len) wide |= @as(u16, str[i + 1]) << 8;
        memory[0x400A + @as(usize, @divExact(i, 2))] = wide;
    }
    std.debug.print("{}\n", .{i});
    opTRAP(op5) catch |err| std.debug.print("{any} Errored\n", .{err});
    std.debug.print("\t<- Should have printed \"hellohello\"\n", .{});

    const op6 = 0b1111_0000_0000_0000 + 0x25;
    std.debug.print("Exiting...", .{});
    opTRAP(op6) catch |err| std.debug.print("{any} Errored\n", .{err});
}
pub fn getchar() u8 {
    var buf: 1[u8] = undefined;
    const char = std.read(buf[0..]);
    return char;
    // const char = stdin.readByte() catch unreachable;
    // return char;
    // reg[@intFromEnum(r.R_0)] = @as(u16, char);
    // std.debug.print("Input a character.\n", .{});
    // var buffer: [2]u8 = undefined;
    // const input = (nextLine(stdin, &buffer) catch blk: {
    //     std.debug.print("Please enter 1 character\n", .{});
    //     break :blk "0";
    // }).?;
    // return input[0];
}
// test "getchar" {
//     std.debug.print("{}\n", .{getchar()});
// }
