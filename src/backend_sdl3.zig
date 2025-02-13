const gui = @import("gui.zig");

pub fn initGPU(
    window: *const anyopaque, // SDL_Window
) void {
    if (!ImGui_ImplSDL3_InitForSDLGPU(window)) {
        unreachable;
    }
}

pub fn processEvent(
    event: *const anyopaque, // SDL_Event
) bool {
    return ImGui_ImplSDL3_ProcessEvent(event);
}

pub fn deinit() void {
    ImGui_ImplSDL3_Shutdown();
}

pub fn newFrame() void {
    ImGui_ImplSDL3_NewFrame();
}

// Those functions are defined in `imgui_impl_sdl3.cpp`
// (they include few custom changes).
extern fn ImGui_ImplSDL3_InitForSDLGPU(window: *const anyopaque) bool;
extern fn ImGui_ImplSDL3_ProcessEvent(event: *const anyopaque) bool;
extern fn ImGui_ImplSDL3_NewFrame() void;
extern fn ImGui_ImplSDL3_Shutdown() void;
