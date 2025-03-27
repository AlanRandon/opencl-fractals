const builtin = @import("builtin");

pub usingnamespace @cImport({
    @cInclude("stb/stb_image_write.h");
    if (builtin.os.tag.isDarwin()) {
        @cInclude("OpenCL/opencl.h");
    } else {
        @cInclude("CL/cl.h");
    }
});
