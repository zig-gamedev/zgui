const std = @import("std");

const gui = @import("gui.zig");
const backend_dx12 = @import("backend_dx12.zig");

pub const ImGui_ImplDX12_InitInfo = backend_dx12.ImGui_ImplDX12_InitInfo;
pub const D3D12_CPU_DESCRIPTOR_HANDLE = backend_dx12.D3D12_CPU_DESCRIPTOR_HANDLE;
pub const D3D12_GPU_DESCRIPTOR_HANDLE = backend_dx12.D3D12_GPU_DESCRIPTOR_HANDLE;

pub fn init(
    hwnd: *const anyopaque, // HWND
    init_info: ImGui_ImplDX12_InitInfo,
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

pub fn defaultWndProcHandler(hwnd: *const anyopaque, msg: u32, wparam: usize, lparam: isize) i32 {
    return ImGui_ImplWin32_WndProcHandler(hwnd, msg, wparam, lparam);
}

pub fn enableDpiAwareness() void {
    ImGui_ImplWin32_EnableDpiAwareness();
}

extern fn ImGui_ImplWin32_Init(hwnd: *const anyopaque) bool;
extern fn ImGui_ImplWin32_Shutdown() void;
extern fn ImGui_ImplWin32_NewFrame() void;
extern fn ImGui_ImplWin32_WndProcHandler(hwnd: *const anyopaque, msg: u32, wparam: usize, lparam: isize) i32;
extern fn ImGui_ImplWin32_EnableDpiAwareness() void;
