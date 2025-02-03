const std = @import("std");

const gui = @import("gui.zig");
const backend_dx12 = @import("backend_dx12.zig");

pub fn init(
    hwnd: *const anyopaque, // HWND
    init_info: backend_dx12.ImGui_ImplDX12_InitInfo,
) void {
    std.debug.assert(ImGui_ImplWin32_Init(hwnd));
    backend_dx12.init(init_info);
}

pub fn deinit() void {
    backend_dx12.deinit();
    ImGui_ImplWin32_Shutdown();
}

pub fn newFrame(fb_width: u32, fb_height: u32) void {
    ImGui_ImplWin32_NewFrame();
    backend_dx12.newFrame();

    gui.io.setDisplaySize(@as(f32, @floatFromInt(fb_width)), @as(f32, @floatFromInt(fb_height)));
    gui.io.setDisplayFramebufferScale(1.0, 1.0);

    gui.newFrame();
}

pub fn draw(graphics_command_list: *const anyopaque) void {
    gui.render();
    backend_dx12.render(gui.getDrawData(), graphics_command_list);
}

extern fn ImGui_ImplWin32_Init(hwnd: *const anyopaque) bool;
extern fn ImGui_ImplWin32_Shutdown() void;
extern fn ImGui_ImplWin32_NewFrame() void;
