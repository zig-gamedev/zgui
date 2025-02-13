const gui = @import("gui.zig");
const backend_sdl3 = @import("backend_sdl3.zig");

pub const ImGui_ImplSDLGPU3_InitInfo = extern struct {
    device: *const anyopaque, // SDL_GPUDevice
    color_target_format: c_uint, // SDL_GPUTextureFormat
    msaa_samples: c_int, // SDL_GPUSampleCount
};

pub fn init(
    window: *const anyopaque, // SDL_Window
    init_info: ImGui_ImplSDLGPU3_InitInfo,
) void {
    backend_sdl3.initGPU(window);

    if (!ImGui_ImplSDLGPU3_Init(&init_info)) {
        unreachable;
    }
}

pub fn deinit() void {
    backend_sdl3.deinit();
    ImGui_ImplSDLGPU3_Shutdown();
}

pub fn processEvent(event: *const anyopaque) bool {
    return backend_sdl3.processEvent(event);
}

pub fn newFrame(fb_width: u32, fb_height: u32, fb_scale: f32) void {
    ImGui_ImplSDLGPU3_NewFrame();
    backend_sdl3.newFrame();

    gui.io.setDisplaySize(@as(f32, @floatFromInt(fb_width)), @as(f32, @floatFromInt(fb_height)));
    gui.io.setDisplayFramebufferScale(fb_scale, fb_scale);

    gui.newFrame();
}

pub fn render() void {
    gui.render();
}

pub fn prepareDrawData(
    command_buffer: *const anyopaque, // SDL_GPUCommandBuffer
) void {
    Imgui_ImplSDLGPU3_PrepareDrawData(gui.getDrawData(), command_buffer);
}

pub fn renderDrawData(
    command_buffer: *const anyopaque, // SDL_GPUCommandBuffer
    render_pass: *const anyopaque, // SDL_GPURenderPass
    pipeline: ?*const anyopaque, // SDL_GPUGraphicsPipeline
) void {
    ImGui_ImplSDLGPU3_RenderDrawData(
        gui.getDrawData(),
        command_buffer,
        render_pass,
        pipeline,
    );
}

// Those functions are defined in `imgui_impl_sdlgpu3.cpp`
// (they include few custom changes).
extern fn ImGui_ImplSDLGPU3_Init(info: *const anyopaque) bool;
extern fn ImGui_ImplSDLGPU3_Shutdown() void;
extern fn ImGui_ImplSDLGPU3_NewFrame() void;
extern fn Imgui_ImplSDLGPU3_PrepareDrawData(
    draw_data: *const anyopaque,
    command_buffer: *const anyopaque, // SDL_GPUCommandBuffer
) void;
extern fn ImGui_ImplSDLGPU3_RenderDrawData(
    draw_data: *const anyopaque,
    command_buffer: *const anyopaque, // SDL_GPUCommandBuffer
    render_pass: *const anyopaque, // SDL_GPURenderPass
    pipeline: ?*const anyopaque, // SDL_GPUGraphicsPipeline
) void;
