const std = @import("std");
const expect = std.testing.expect;

const vm = @import("hardware/vm.zig");
const registers = @import("hardware/registers.zig");
const r = registers.Register;
const cond = registers.Condition;

const builtin = @import("builtin");
var is_debug = true;
// const is_debug = builtin.mode;
pub fn debugPrint(comptime fmt: []const u8, args: anytype) void {
    if (is_debug) {
        std.debug.print(fmt, args);
    }
}

const c = @cImport({
    @cInclude("termios.h");
});

var original_tio: c.termios = undefined;

const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();

pub fn disableInputBuffering() void {
    const stdin_fd = std.os.linux.STDIN_FILENO;
    _ = c.tcgetattr(stdin_fd, &original_tio);
    var new_tio: c.termios = original_tio;
    new_tio.c_lflag &= @as(c_uint, @bitCast(~c.ICANON & ~c.ECHO));
    _ = c.tcsetattr(stdin_fd, c.TCSANOW, &new_tio);
}

pub fn restoreInputBuffering() void {
    const stdin_fd = std.os.linux.STDIN_FILENO;
    _ = c.tcsetattr(stdin_fd, c.TCSANOW, &original_tio);
}

pub fn main() void {
    // std.debug.print("{any}\n", .{is_debug});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = std.process.argsAlloc(allocator) catch unreachable;
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("zig build run -- filename ?release\n", .{});
        return;
    }
    if (args.len > 2) {
        if (std.mem.eql(u8, args[2], "release")) {
            is_debug = false;
        }
    }

    var buffer: [0xFDFF - 0x3000]u8 = [1]u8{0} ** (0xFDFF - 0x3000);
    _ = std.fs.cwd().readFile(args[1], &buffer) catch {
        std.debug.print("Filename invalid\n", .{});
        return;
    };
    var i: usize = 0;
    while (i < 0x6700 - 1) : (i += 1) {
        vm.memory[0x3000 + i] = (@as(u16, buffer[i * 2]) << 8) + @as(u16, buffer[i * 2 + 1]);
    }
    debugPrint("File start: {x}\n", .{vm.memory[0x3000]});
    if (vm.memory[0x3000] != 0x3000) {
        std.debug.print("Your program thinks it's fancy with a special ROM offset so I can't run it.\n", .{});
        return;
    }
    debugPrint("Filename: {s} {s}\n", .{ args[0], args[1] });

    std.debug.print("Starting the VM...\n", .{});
    vm.reg[@as(usize, @intFromEnum(r.R_COND))] = @intFromEnum(cond.FL_Z);
    const PC_START = 0x3000;
    vm.reg[@intFromEnum(r.R_PC)] = PC_START;

    var op: u16 = undefined;
    var opcode: vm.Instruction = undefined;
    vm.reg[@intFromEnum(r.R_PC)] += 1; //skip the .ORIGIN
    var running: u32 = 0;
    disableInputBuffering();

    while (true) {
        defer restoreInputBuffering();
        op = vm.memory[vm.reg[@intFromEnum(r.R_PC)]];
        opcode = @enumFromInt(@as(u4, @truncate(op >> 12)));
        debugPrint("Breakdown of instruction: {b:0>16} {}\n", .{ op, opcode });
        running += 1;
        vm.reg[@intFromEnum(r.R_PC)] += 1;
        switch (opcode) {
            vm.Instruction.OP_ADD => vm.opADD(op),
            vm.Instruction.OP_AND => vm.opAND(op),
            vm.Instruction.OP_BR => vm.opBR(op),
            vm.Instruction.OP_JMP => vm.opJMP(op),
            vm.Instruction.OP_JSR => vm.opJSR(op),
            vm.Instruction.OP_LD => vm.opLD(op),
            vm.Instruction.OP_LDI => vm.opLDI(op),
            vm.Instruction.OP_LDR => vm.opLDR(op),
            vm.Instruction.OP_LEA => vm.opLEA(op),
            vm.Instruction.OP_NOT => vm.opNOT(op),
            //RET is the same as JMP
            vm.Instruction.OP_RTI => {},
            vm.Instruction.OP_ST => vm.opST(op),
            vm.Instruction.OP_STI => vm.opSTI(op),
            vm.Instruction.OP_STR => vm.opSTR(op),
            vm.Instruction.OP_TRAP => vm.opTRAP(op) catch std.debug.print("Trap failed!!!\n", .{}),
            vm.Instruction.OP_RES => {},
        }
        debugPrint("Registers in 0x: {x}\n", .{vm.reg});
    }
}
