const gui = @import("gui.zig");

// This call will install GLFW callbacks to handle GUI interactions.
// Those callbacks will chain-call user's previously installed callbacks, if any.
// This means that custom user's callbacks need to be installed *before* calling zgpu.gui.init().
pub fn init(
    window: *const anyopaque, // zglfw.Window
) void {
    if (!ImGui_ImplGlfw_InitForOther(window, true)) {
        unreachable;
    }
}

pub fn initOpenGL(
    window: *const anyopaque, // zglfw.Window
) void {
    if (!ImGui_ImplGlfw_InitForOpenGL(window, true)) {
        unreachable;
    }
}

pub fn initVulkan(
    window: *const anyopaque, // zglfw.Window
) void {
    if (!ImGui_ImplGlfw_InitForVulkan(window, true)) {
        unreachable;
    }
}

pub fn deinit() void {
    ImGui_ImplGlfw_Shutdown();
}

pub fn newFrame(scale_x: f32, scale_y: f32) void {
    ImGui_ImplGlfw_NewFrame(scale_x, scale_y);
}

// Those functions are defined in `imgui_impl_glfw.cpp`
// (they include few custom changes).
extern fn ImGui_ImplGlfw_InitForOther(window: *const anyopaque, install_callbacks: bool) bool;
extern fn ImGui_ImplGlfw_InitForOpenGL(window: *const anyopaque, install_callbacks: bool) bool;
extern fn ImGui_ImplGlfw_InitForVulkan(window: *const anyopaque, install_callbacks: bool) bool;
extern fn ImGui_ImplGlfw_NewFrame(scale_x: f32, scale_y: f32) void;
extern fn ImGui_ImplGlfw_Shutdown() void;
