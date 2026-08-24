const gui = @import("gui.zig");
const backend_glfw = @import("backend_glfw.zig");

pub fn init(
    window: *const anyopaque, // zglfw.Window
) void {
    backend_glfw.initOpenGL(window);

    _ = ImGui_ImplOpenGL2_Init();
}

pub fn deinit() void {
    ImGui_ImplOpenGL2_Shutdown();
    backend_glfw.deinit();
}

pub fn newFrame(fb_width: u32, fb_height: u32) void {
    backend_glfw.newFrame();
    ImGui_ImplOpenGL2_NewFrame();

    gui.io.setDisplaySize(@as(f32, @floatFromInt(fb_width)), @as(f32, @floatFromInt(fb_height)));
    gui.io.setDisplayFramebufferScale(1.0, 1.0);

    gui.newFrame();
}

pub fn draw() void {
    gui.render();
    ImGui_ImplOpenGL2_RenderDrawData(gui.getDrawData());
}

// Those functions are defined in 'imgui_impl_opengl2.cpp`.
extern fn ImGui_ImplOpenGL2_Init() bool;
extern fn ImGui_ImplOpenGL2_Shutdown() void;
extern fn ImGui_ImplOpenGL2_NewFrame() void;
extern fn ImGui_ImplOpenGL2_RenderDrawData(data: *const anyopaque) void;
