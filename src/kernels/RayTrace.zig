const std = @import("std");

pub const Args = extern struct {
    const c = @import("../c.zig");

    image_width_int: u32,
    image_height_int: u32,
    viewport_delta_u: Direction,
    viewport_delta_v: Direction,
    upper_left_pixel: Point,

    pub fn init(width: c.cl_uint) Args {
        const aspect_ratio: f32 = 16.0 / 9.0;
        const height: c.cl_uint = @max(1, @as(c.cl_uint, @intFromFloat(@as(f32, @floatFromInt(width)) / aspect_ratio)));

        const viewport_height = 2.0;
        const viewport_width = viewport_height * @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height));
        const viewport_u = Direction{ viewport_width, 0, 0 };
        const viewport_v = Direction{ 0, -viewport_height, 0 };
        const viewport_delta_u = viewport_u * @as(Direction, @splat(1.0 / @as(f32, @floatFromInt(width))));
        const viewport_delta_v = viewport_v * @as(Direction, @splat(1.0 / @as(f32, @floatFromInt(height))));

        const viewport_upper_left = camera_center -
            Direction{ 0, 0, focal_length } -
            viewport_u * @as(Direction, @splat(0.5)) -
            viewport_v * @as(Direction, @splat(0.5));
        const upper_left_pixel = viewport_upper_left + (viewport_delta_u + viewport_delta_v) * @as(Direction, @splat(0.5));

        return .{
            .image_width_int = width,
            .image_height_int = height,
            .viewport_delta_u = viewport_delta_u,
            .viewport_delta_v = viewport_delta_v,
            .upper_left_pixel = upper_left_pixel,
        };
    }
};

const Point = @Vector(3, f32);
const Color = @Vector(3, f32);
const Direction = @Vector(3, f32);

const camera_center: Point = .{ 0, 0, 0 };
const focal_length: f32 = 1.0;

fn unitVec(comptime size: comptime_int, vec: @Vector(size, f32)) @Vector(size, f32) {
    var magnitude_sq: f32 = 0;
    for (@as([size]f32, vec)) |i| {
        magnitude_sq += i * i;
    }
    const magnitude = std.math.sqrt(magnitude_sq);
    return mulVec(size, 1 / magnitude, vec);
}

fn mulVec(comptime size: comptime_int, parameter: f32, vec: @Vector(size, f32)) @Vector(size, f32) {
    return @as(@TypeOf(vec), @splat(parameter)) * vec;
}

fn lerpVec(comptime size: comptime_int, a: f32, start: @Vector(size, f32), end: @Vector(size, f32)) @Vector(size, f32) {
    return mulVec(size, 1 - a, start) + mulVec(size, a, end);
}

fn dot(comptime size: comptime_int, lhs: @Vector(size, f32), rhs: @Vector(size, f32)) f32 {
    var result: f32 = 0;
    for (0..size) |i| {
        result += lhs[i] * rhs[i];
    }
    return result;
}

const Sphere = struct {
    center: Point,
    radius: f32,

    fn checkRay(sphere: *const Sphere, ray: *const Ray, out: *Ray) bool {
        const oc = sphere.center - ray.origin;
        const a = dot(3, ray.direction, ray.direction);
        const h = dot(3, ray.direction, oc);
        const c = dot(3, oc, oc) - sphere.radius * sphere.radius;
        const discriminant = h * h - a * c;
        if (discriminant > 0) {
            const discriminant_sqrt = std.math.sqrt(discriminant);
            const t = @min(h - discriminant_sqrt, h + discriminant_sqrt) / a;
            const intersection = ray.pointAt(t);
            out.* = .{
                .origin = intersection,
                .direction = mulVec(3, 1 / sphere.radius, intersection - sphere.center),
            };
            return true;
        } else {
            return false;
        }
    }
};

const Ray = struct {
    origin: Point,
    direction: Direction,

    fn color(ray: *const Ray) Color {
        for (0..20) |j_int| {
            const j: f32 = @floatFromInt(j_int);
            for (0..20) |i_int| {
                const i: f32 = @floatFromInt(i_int);
                const sphere = Sphere{
                    .center = .{
                        std.math.cos(i / 20.0 * std.math.pi * 2.0) * 5,
                        std.math.sin(i / 20.0 * std.math.pi * 2.0) * 5,
                        j * 2,
                    },
                    .radius = 0.5,
                };
                var reflection: Ray = undefined;
                if (sphere.checkRay(ray, &reflection)) {
                    return lerpVec(3, reflection.direction[2], .{ 0.5, 0, 0 }, .{ 1, 0, 0 });
                }
            }
        }

        const unit = unitVec(3, ray.direction);
        return lerpVec(3, 0.5 * (unit[1] + 1), .{ 1, 1, 1 }, .{ 0.5, 0.7, 1 });
    }

    fn pointAt(ray: *const Ray, t: f32) Point {
        return ray.origin + mulVec(3, t, ray.direction);
    }
};

pub fn pixel(out: [*]addrspace(.global) u8, args_ptr: *addrspace(.global) const Args) callconv(.spirv_kernel) void {
    const args = args_ptr.*;
    const x_int = @workGroupId(0) * @workGroupSize(0) + @workItemId(0);
    const y_int = @workGroupId(1) * @workGroupSize(1) + @workItemId(1);

    const x: f32 = @floatFromInt(x_int);
    const y: f32 = @floatFromInt(y_int);

    const pixel_center = args.upper_left_pixel +
        (@as(Direction, @splat(x)) * args.viewport_delta_u) +
        (@as(Direction, @splat(y)) * args.viewport_delta_v);

    const ray_direction = pixel_center - camera_center;
    const ray: Ray = .{ .origin = camera_center, .direction = ray_direction };

    const index = (y_int * args.image_width_int + x_int) * 3;
    const scaled_color = @as(Color, @splat(255)) * ray.color();
    out[index] = @intFromFloat(scaled_color[0]);
    out[index + 1] = @intFromFloat(scaled_color[1]);
    out[index + 2] = @intFromFloat(scaled_color[2]);
}
