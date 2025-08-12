const gui = @import("gui.zig");
const options = @import("zgui_options");

// This call will install GLFW callbacks to handle GUI interactions.
// Those callbacks will chain-call user's previously installed callbacks, if any.
// This means that custom user's callbacks need to be installed *before* calling zgpu.gui.init().
pub fn init(
    window: *const anyopaque, // zglfw.Window
) void {
    const ImGui_ImplGlfw_InitForOther = @extern(*const fn (window: *const anyopaque, install_callbacks: bool) callconv(.c) bool, .{
        .name = "ImGui_ImplGlfw_InitForOther",
        .is_dll_import = options.shared,
    });

    if (!ImGui_ImplGlfw_InitForOther(window, true)) {
        unreachable;
    }
}

pub fn initOpenGL(
    window: *const anyopaque, // zglfw.Window
) void {
    const ImGui_ImplGlfw_InitForOpenGL = @extern(*const fn (window: *const anyopaque, install_callbacks: bool) callconv(.c) bool, .{
        .name = "ImGui_ImplGlfw_InitForOpenGL",
        .is_dll_import = options.shared,
    });

    if (!ImGui_ImplGlfw_InitForOpenGL(window, true)) {
        unreachable;
    }
}

pub fn initVulkan(
    window: *const anyopaque, // zglfw.Window
) void {
    const ImGui_ImplGlfw_InitForVulkan = @extern(*const fn (window: *const anyopaque, install_callbacks: bool) callconv(.c) bool, .{
        .name = "ImGui_ImplGlfw_InitForVulkan",
        .is_dll_import = options.shared,
    });

    if (!ImGui_ImplGlfw_InitForVulkan(window, true)) {
        unreachable;
    }
}

pub fn deinit() void {
    const ImGui_ImplGlfw_Shutdown = @extern(*const fn () callconv(.c) void, .{
        .name = "ImGui_ImplGlfw_Shutdown",
        .is_dll_import = options.shared,
    });
    ImGui_ImplGlfw_Shutdown();
}

pub fn newFrame() void {
    const ImGui_ImplGlfw_NewFrame = @extern(*const fn () callconv(.c) void, .{
        .name = "ImGui_ImplGlfw_NewFrame",
        .is_dll_import = options.shared,
    });
    ImGui_ImplGlfw_NewFrame();
}
