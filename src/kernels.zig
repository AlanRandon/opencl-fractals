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

fn hsvToRgb(h: f32, s: f32, v: f32) @Vector(3, f32) {
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

comptime {
    exportKernels(struct {
        pub fn pixel(out: [*]addrspace(.global) u8, width: u32) callconv(.spirv_kernel) void {
            const x = @workGroupId(0) * @workGroupSize(0) + @workItemId(0);
            const y = @workGroupId(1) * @workGroupSize(1) + @workItemId(1);
            const index = (y * width + x) * 3;

            const size = 0.05 / @as(f32, @floatFromInt(width));
            const bound = 2;
            const max_iterations: usize = 5000;

            var z = Complex32{ .real = 0, .imaginary = 0 };
            const c = Complex32{
                .real = @mulAdd(f32, @floatFromInt(x), size, -1.41),
                .imaginary = @mulAdd(f32, @floatFromInt(y), size, -0.025),
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

            if (iterations >= max_iterations - 10) {
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
    });
}

fn exportKernels(K: anytype) void {
    if (builtin.os.tag == .opencl) {
        for (@typeInfo(K).@"struct".decls) |decl| {
            const kernel = @field(K, decl.name);
            switch (@typeInfo(@TypeOf(kernel))) {
                .@"fn" => |signature| {
                    if (signature.calling_convention != .spirv_kernel) {
                        @compileError("kernel `" ++ decl.name ++ "` must use callconv(.spirv_kernel)");
                    }

                    @export(&kernel, .{ .name = decl.name });
                },
                else => {},
            }
        }
    }
}
