const std = @import("std");
const rng = std.crypto.random;
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var a = try allocator.alloc(u8, 10);
    var b = try allocator.alloc(u8, 10);
    populateString(a);
    populateString(b);
    std.debug.print("{s} {s}\n", .{ a, b });
    var newString = try concateStrings(allocator, a, b);
    std.debug.print("{s}\n", .{newString});
    defer allocator.free(newString);
}

fn getRandomCount() u8 {
    return rng.int(u8);
}
pub fn populateString(a: []u8) void {
    for (0..a.len) |i| {
        a[i] = getRandomCount() % 26 + 0x41;
    }
}
pub fn concateStrings(allocator: std.mem.Allocator, a: []u8, b: []u8) ![]u8 {
    var memory = try allocator.alloc(u8, a.len + b.len);
    for (a, 0..) |c, i| {
        memory[i] = c;
    }
    for (b, 0..) |c, i| {
        memory[i + a.len] = c;
    }
    defer allocator.free(a);
    defer allocator.free(b);
    return memory;
}

test "gpa heap strings with concatenation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var a = try allocator.alloc(u8, 10);
    var b = try allocator.alloc(u8, 10);
    populateString(a);
    populateString(b);
    std.debug.print("{s} {s} {any}\n", .{ a, b, @TypeOf(a) });
    var newString = try concateStrings(allocator, a, b);
    std.mem.reverse(u8, newString);
    std.debug.print("{s}, {d}\n", .{ newString, newString.len });
    defer allocator.free(newString);
}

test "zig string builtins" {
    var a: [10]u8 = undefined;
    var b: [10]u8 = undefined;
    populateString(&a);
    populateString(&b);
    std.debug.print("{s} {s} {any}\n", .{ a, b, @TypeOf(a) });
    var c = a ++ b;
    std.mem.reverse(u8, &c);
    std.debug.print("{s}, {d}\n", .{ c, c.len });
}
test "zig mutable string literals" {
    var a = "asdfghjkl0123456789".*;
    populateString(&a);
    std.debug.print("{s} {any} {any}\n", .{ &a, a, @TypeOf(a) });
    a[0] = 'A';
    std.mem.reverse(u8, &a);
    std.debug.print("{s}, {d}\n", .{ a[4..], a[4..].len });
}
