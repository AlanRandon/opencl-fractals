const std = @import("std");

pub const Color = @Vector(3, f32);
pub fn hsvToRgb(h: f32, s: f32, v: f32) @Vector(3, f32) {
    if (s == 0) {
        return .{ v, v, v };
    } else {
        var var_h = h * 6;
        if (var_h == 6) var_h = 0;
        const var_i = std.math.floor(var_h);
        const v1 = v * (1 - s);
        const v2 = v * (1 - s * (var_h - var_i));
        const v3 = v * (1 - s * (1 - var_h + var_i));

        switch (@as(usize, @intFromFloat(var_i))) {
            0 => return .{ v, v3, v1 },
            1 => return .{ v2, v, v1 },
            2 => return .{ v1, v, v3 },
            3 => return .{ v1, v2, v },
            4 => return .{ v3, v1, v },
            5 => return .{ v, v1, v2 },
            else => unreachable,
        }
    }
}
