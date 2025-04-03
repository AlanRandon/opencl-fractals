const std = @import("std");
const c = @import("c.zig");
const checkClError = @import("error.zig").checkClError;

pub fn main() !void {
    var device_id: c.cl_device_id = undefined;
    try checkClError(c.clGetDeviceIDs(null, c.CL_DEVICE_TYPE_ALL, 1, &device_id, null));

    var err: c.cl_int = undefined;
    const context = c.clCreateContext(0, 1, &device_id, null, null, &err) orelse {
        try checkClError(err);
        unreachable;
    };

    const commands = c.clCreateCommandQueue(context, device_id, 0, &err) orelse {
        try checkClError(err);
        unreachable;
    };

    const il = @embedFile("kernels.spv");
    const program = c.clCreateProgramWithIL(context, il.ptr, il.len, &err) orelse {
        try checkClError(err);
        unreachable;
    };

    try checkClError(c.clBuildProgram(program, 0, null, null, null, null));

    const kernel = c.clCreateKernel(program, "pixel", &err) orelse {
        try checkClError(err);
        unreachable;
    };

    const RayTrace = @import("kernels/RayTrace.zig");
    const args = comptime RayTrace.Args.init(1024);
    var args_mut = args;

    const args_buf = c.clCreateBuffer(
        context,
        c.CL_MEM_READ_ONLY | c.CL_MEM_USE_HOST_PTR,
        @sizeOf(RayTrace.Args),
        @ptrCast(&args_mut),
        &err,
    ) orelse {
        try checkClError(err);
        unreachable;
    };

    var results: [args.image_width_int * args.image_height_int * 3]u8 = undefined;
    const out = c.clCreateBuffer(
        context,
        c.CL_MEM_WRITE_ONLY | c.CL_MEM_HOST_READ_ONLY,
        results.len,
        null,
        &err,
    ) orelse {
        try checkClError(err);
        unreachable;
    };

    try checkClError(c.clSetKernelArg(kernel, 0, @sizeOf(c.cl_mem), @ptrCast(&out)));
    try checkClError(c.clSetKernelArg(kernel, 1, @sizeOf(c.cl_mem), @ptrCast(&args_buf)));

    var sizes: [2]usize = .{ args.image_width_int, args.image_height_int };
    try checkClError(c.clEnqueueNDRangeKernel(commands, kernel, 2, null, @constCast(&sizes), null, 0, null, null));
    try checkClError(c.clFinish(commands));
    try checkClError(c.clEnqueueReadBuffer(commands, out, c.CL_TRUE, 0, results.len, &results, 0, null, null));

    const file = try std.fs.cwd().createFile("out.png", .{});
    defer file.close();

    _ = c.stbi_write_png("out.png", args.image_width_int, args.image_height_int, 3, &results, 0);
}
