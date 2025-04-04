const builtin = @import("builtin");
const std = @import("std");

const Complex32 = struct {
    real: f32,
    imaginary: f32,

    fn square(z: *const Complex32) Complex32 {
        return .{
            .real = z.real * z.real - z.imaginary * z.imaginary,
            .imaginary = z.real * z.imaginary * 2,
        };
    }

    fn add(lhs: *const Complex32, rhs: *const Complex32) Complex32 {
        return .{
            .real = rhs.real + lhs.real,
            .imaginary = rhs.imaginary + lhs.imaginary,
        };
    }

    fn magnitude(z: *const Complex32) f32 {
        // return std.math.hypot(z.real, z.imaginary);
        return std.math.sqrt(z.real * z.real + z.imaginary * z.imaginary);
    }
};

pub fn pixel(out: [*]addrspace(.global) u8, width: u32) callconv(.spirv_kernel) void {
    const x = @workGroupId(0) * @workGroupSize(0) + @workItemId(0);
    const y = @workGroupId(1) * @workGroupSize(1) + @workItemId(1);
    const index = (y * width + x) * 3;

    const size = 0.01 / @as(f32, @floatFromInt(width));
    const bound = 2;
    const max_iterations: usize = 10_000;

    var z = Complex32{ .real = 0, .imaginary = 0 };
    const c = Complex32{
        .real = @mulAdd(f32, @floatFromInt(x), size, -1.402),
        .imaginary = @mulAdd(f32, @floatFromInt(y), size, -0.005),
    };

    var iterations: usize = 1000;
    for (0..max_iterations) |i| {
        iterations = i;
        if (z.magnitude() >= bound) {
            break;
        } else {
            z = z.square().add(&c);
        }
    }

    if (iterations >= max_iterations - 1) {
        out[index] = 0;
        out[index + 1] = 0;
        out[index + 2] = 0;
    } else {
        const h = @mod(@mulAdd(
            f32,
            @as(f32, @floatFromInt(iterations)) / @as(f32, @floatFromInt(max_iterations)),
            3,
            0.52,
        ), 1);
        const rgb = hsvToRgb(h, 0.7, 0.7);
        const bytes: @Vector(3, u8) = @intFromFloat(@as(@Vector(3, f32), @splat(255)) * rgb);
        out[index] = bytes[0];
        out[index + 1] = bytes[1];
        out[index + 2] = bytes[2];
    }
}
