const gui = @import("gui.zig");

pub fn init(
    window: *const anyopaque, // SDL_Window
) void {
    if (!ImGui_ImplSDL2_InitForOther(window)) {
        unreachable;
    }
}

pub fn initOpenGL(
    window: *const anyopaque, // SDL_Window
    context: *const anyopaque, // SDL_GL_Context
) void {
    if (!ImGui_ImplSDL2_InitForOpenGL(window, context)) {
        unreachable;
    }
}

pub fn processEvent(
    event: *const anyopaque, // SDL_Event
) bool {
    return ImGui_ImplSDL2_ProcessEvent(event);
}

pub fn deinit() void {
    ImGui_ImplSDL2_Shutdown();
}

pub fn newFrame() void {
    ImGui_ImplSDL2_NewFrame();
}

// These functions are defined in `imgui_impl_sdl2.cpp`
extern fn ImGui_ImplSDL2_InitForOther(window: *const anyopaque) bool;
extern fn ImGui_ImplSDL2_InitForOpenGL(window: *const anyopaque, sdl_gl_context: *const anyopaque) bool;
extern fn ImGui_ImplSDL2_ProcessEvent(event: *const anyopaque) bool;
extern fn ImGui_ImplSDL2_NewFrame() void;
extern fn ImGui_ImplSDL2_Shutdown() void;
