const std = @import("std");
pub fn signExtend(int: anytype) u16 {
    return @as(u16, @bitCast(@as(i16, @intCast(int))));
}
test "test" {
    const value = signExtend(0b11011 & 0b11_111);
    std.debug.print("{d}\n", .{value});
}
