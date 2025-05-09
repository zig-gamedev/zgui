const gui = @import("gui.zig");
const backend_sdl3 = @import("backend_sdl3.zig");

pub fn initWithGlSlVersion(
    window: *const anyopaque, // SDL_Window
    context: *const anyopaque, // SDL_GL_Context
    glsl_version: ?[:0]const u8, // e.g. "#version 130"
) void {
    backend_sdl3.initOpenGL(window, context);

    ImGui_ImplOpenGL3_Init(@ptrCast(glsl_version));
}

pub fn init(
    window: *const anyopaque, // SDL_Window
    context: *const anyopaque, // SDL_GL_Context
) void {
    initWithGlSlVersion(window, context, null);
}

pub fn processEvent(
    event: *const anyopaque, // SDL_Event
) bool {
    return backend_sdl3.processEvent(event);
}

pub fn deinit() void {
    ImGui_ImplOpenGL3_Shutdown();
    backend_sdl3.deinit();
}

pub fn newFrame(fb_width: u32, fb_height: u32) void {
    ImGui_ImplOpenGL3_NewFrame();
    backend_sdl3.newFrame();

    gui.io.setDisplaySize(@as(f32, @floatFromInt(fb_width)), @as(f32, @floatFromInt(fb_height)));
    gui.io.setDisplayFramebufferScale(1.0, 1.0);

    gui.newFrame();
}

pub fn draw() void {
    gui.render();
    ImGui_ImplOpenGL3_RenderDrawData(gui.getDrawData());
}

// These functions are defined in 'imgui_impl_opengl3.cpp`
// (they include few custom changes).
extern fn ImGui_ImplOpenGL3_Init(glsl_version: [*c]const u8) void;
extern fn ImGui_ImplOpenGL3_Shutdown() void;
extern fn ImGui_ImplOpenGL3_NewFrame() void;
extern fn ImGui_ImplOpenGL3_RenderDrawData(data: *const anyopaque) void;
