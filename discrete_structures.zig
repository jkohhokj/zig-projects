//usr/bin/env zig run "$0" -- "$@"; exit
const std = @import("std");
const print = @import("std").debug.print;

const Managed = std.math.big.int.Managed;
const rng = std.crypto.random;
const gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub fn main() !void {
    const pageAllocator = std.heap.page_allocator;
    var argsIterator = try std.process.ArgIterator.initWithAllocator(pageAllocator);
    defer argsIterator.deinit();

    _ = argsIterator.next(); // filename

    var a: i64 = 0;
    var b: i64 = 0;
    if (argsIterator.next()) |_a| {
        a = try std.fmt.parseInt(i64, _a, 10);
    }
    if (argsIterator.next()) |_b| {
        b = try std.fmt.parseInt(i64, _b, 10);
    }
    if (b == 0) {
        print("Usage: ./main.zig number1 number2\n", .{});
        return;
    }
    try egcd(a, b);
}

pub fn egcd(_a: i64, _b: i64) !void {
    //var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    const rows: u8 = 6;
    const cols: u8 = 10;
    var table = try allocator.alloc([cols]i64, rows);
    defer allocator.free(table);
    var a: i64 = _a;
    var b: i64 = _b;
    if (b > a) { //swap variables to make a > b
        a += b;
        b = a - b;
        a -= b;
    }
    var c: u8 = 2;
    table[c][0] = a;
    table[c][1] = b;
    table[c][3] = 1;
    table[c - 2][4] = 1; // s1
    table[c - 1][4] = 0; // s2
    table[c][4] = 1; //s3
    table[c - 2][5] = 0; // t1
    table[c - 1][5] = 1; // t2
    print("   a   |   b   |   q   |   r   |   s   |   t\n", .{});
    while (table[c][3] != 0) {
        table[c][2] = @divTrunc(table[c][0], table[c][1]); //q = a/b
        table[c][3] = @mod(table[c][0], table[c][1]); //r = a%b
        table[c + 1][0] = table[c][1]; //a = b
        table[c + 1][1] = table[c][3]; //b = r
        table[c][4] = table[c - 2][4] - table[c][2] * table[c - 1][4];
        table[c][5] = table[c - 2][5] - table[c][2] * table[c - 1][5];
        for (0..6) |idx| {
            print("{d} | ", .{table[c][idx]});
        }
        print("\n", .{});
        if (table[c][3] == 0) {
            std.debug.print("gcd is {d}\n", .{table[c][1]});
            print("bezier coeffs are s={0d}, t={1d}: {0d}*{2d}+{1d}*{3d}={4d}\n", .{ table[c - 1][4], table[c - 1][5], table[2][0], table[2][1], table[c][1] });
            return;
        }
        c += 1;
    }
    print("gcd is 1\n", .{});
}

pub fn makeBigInt(_: u16) !type{
    //var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var a = try Managed.init(allocator);
    try a.set(1990273423429836742364234234234);
    std.debug.print("{any}\n",.{a});
    return a;
}
test "alloc big number"{
    var gpa2 = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa2.allocator();
    var a = try Managed.init(allocator);
    a = try makeBigInt(1);
    std.debug.print("{any}\n",a);
}

//pub fn inv_mod(&a, &m) !&b{
//    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//    var allocator = gpa.allocator();
//
//}
