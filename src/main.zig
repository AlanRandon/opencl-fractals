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

    const width: c.cl_uint = 2048;
    const height: c.cl_uint = width;
    var results: [width * height * 3]u8 = undefined;

    const out = c.clCreateBuffer(context, c.CL_MEM_WRITE_ONLY, results.len, null, &err) orelse {
        try checkClError(err);
        unreachable;
    };

    try checkClError(c.clSetKernelArg(kernel, 0, @sizeOf(c.cl_mem), @ptrCast(&out)));
    try checkClError(c.clSetKernelArg(kernel, 1, @sizeOf(c.cl_mem), @ptrCast(&@as(u32, width))));

    var sizes: [2]usize = .{ width, height };
    try checkClError(c.clEnqueueNDRangeKernel(commands, kernel, 2, null, @constCast(&sizes), null, 0, null, null));
    try checkClError(c.clFinish(commands));
    try checkClError(c.clEnqueueReadBuffer(commands, out, c.CL_TRUE, 0, results.len, &results, 0, null, null));

    const file = try std.fs.cwd().openFile("out.png", .{ .mode = .write_only });
    defer file.close();

    _ = c.stbi_write_png("out.png", width, height, 3, &results, 0);
}
