const gui = @import("gui.zig");
const backend_glfw = @import("backend_glfw.zig");
const backend_dx12 = @import("backend_dx12.zig");

pub const ImGui_ImplDX12_InitInfo = backend_dx12.ImGui_ImplDX12_InitInfo;
pub const D3D12_CPU_DESCRIPTOR_HANDLE = backend_dx12.D3D12_CPU_DESCRIPTOR_HANDLE;
pub const D3D12_GPU_DESCRIPTOR_HANDLE = backend_dx12.D3D12_GPU_DESCRIPTOR_HANDLE;

pub fn init(
    window: *const anyopaque, // zglfw.Window
    init_info: ImGui_ImplDX12_InitInfo,
) void {
    backend_glfw.init(window);
    backend_dx12.init(init_info);
}

pub fn deinit() void {
    backend_dx12.deinit();
    backend_glfw.deinit();
}

pub fn newFrame(fb_width: u32, fb_height: u32) void {
    backend_glfw.newFrame();
    backend_dx12.newFrame();

    gui.io.setDisplaySize(@as(f32, @floatFromInt(fb_width)), @as(f32, @floatFromInt(fb_height)));
    gui.io.setDisplayFramebufferScale(1.0, 1.0);

    gui.newFrame();
}

pub fn draw(
    graphics_command_list: *const anyopaque, // *ID3D12GraphicsCommandList
) void {
    gui.render();
    backend_dx12.render(gui.getDrawData(), graphics_command_list);
}
