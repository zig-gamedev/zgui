const gui = @import("gui.zig");
const backend_osx = @import("backend_osx.zig");

pub fn init(
    view: *const anyopaque, // NSView*
    device: *const anyopaque, // MTL::Device*
) void {
    backend_osx.init(view);
    if (!ImGui_ImplMetal_Init(device)) {
        unreachable;
    }
}

pub fn deinit() void {
    ImGui_ImplMetal_Shutdown();
    backend_osx.deinit();
}

pub fn newFrame(
    fb_width: u32,
    fb_height: u32,
    view: *const anyopaque, // NSView*
    render_pass_descriptor: *const anyopaque // MTL::RenderPassDescriptor*
) void {
    backend_osx.newFrame(view);
    ImGui_ImplMetal_NewFrame(render_pass_descriptor);

    gui.io.setDisplaySize(@as(f32, @floatFromInt(fb_width)), @as(f32, @floatFromInt(fb_height)));
    gui.io.setDisplayFramebufferScale(1.0, 1.0);

    gui.newFrame();
}

pub fn draw(
    command_buffer: *const anyopaque, // MTL::CommandBuffer*
    command_encoder: *const anyopaque, // MTL::RenderCommandEncoder*
) void {
    gui.render();
    ImGui_ImplMetal_RenderDrawData(gui.getDrawData(), command_buffer, command_encoder);
}

// These functions are defined in 'imgui_impl_metal.cpp`
extern fn ImGui_ImplMetal_Init(device: *const anyopaque) bool;
extern fn ImGui_ImplMetal_Shutdown() void;
extern fn ImGui_ImplMetal_NewFrame(renderPassDescriptor: *const anyopaque) void;
extern fn ImGui_ImplMetal_RenderDrawData(draw_data: *const anyopaque,
    commandBuffer: *const anyopaque,
    commandEncoder: *const anyopaque) void;
