const gui = @import("gui.zig");

pub fn init(
    view: *const anyopaque, // NSView*
) void {
    if (!ImGui_ImplOSX_Init(view)) {
        unreachable;
    }
}

pub fn deinit() void {
    ImGui_ImplOSX_Shutdown();
}

pub fn newFrame(view: *const anyopaque) void {
    ImGui_ImplOSX_NewFrame(view);
}

// These functions are defined in `imgui_impl_osx.cpp`
extern fn ImGui_ImplOSX_Init(view: *const anyopaque) bool;
extern fn ImGui_ImplOSX_Shutdown() void;
extern fn ImGui_ImplOSX_NewFrame(view: *const anyopaque) void;
