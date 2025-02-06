pub const D3D12_CPU_DESCRIPTOR_HANDLE = extern struct {
    ptr: c_ulonglong,
};

pub const D3D12_GPU_DESCRIPTOR_HANDLE = extern struct {
    ptr: c_ulonglong,
};

pub const ImGui_ImplDX12_InitInfo = extern struct {
    device: *const anyopaque, // ID3D12Device
    command_queue: *const anyopaque, // ID3D12CommandQueue
    num_frames_in_flight: u32,
    rtv_format: c_uint, // DXGI_FORMAT
    dsv_format: c_uint, // DXGI_FORMAT
    user_data: ?*const anyopaque = null,
    cbv_srv_heap: *const anyopaque, // ID3D12DescriptorHeap
    srv_desc_alloc_fn: ?*const fn (
        *ImGui_ImplDX12_InitInfo,
        *D3D12_CPU_DESCRIPTOR_HANDLE,
        *D3D12_GPU_DESCRIPTOR_HANDLE,
    ) callconv(.C) void = null,
    srv_desc_free_fn: ?*const fn (
        *ImGui_ImplDX12_InitInfo,
        D3D12_CPU_DESCRIPTOR_HANDLE,
        D3D12_GPU_DESCRIPTOR_HANDLE,
    ) callconv(.C) void = null,
    font_srv_cpu_desc_handle: D3D12_CPU_DESCRIPTOR_HANDLE,
    font_srv_gpu_desc_handle: D3D12_GPU_DESCRIPTOR_HANDLE,
};

pub fn init(init_info: ImGui_ImplDX12_InitInfo) void {
    if (!ImGui_ImplDX12_Init(&init_info)) {
        @panic("failed to init d3d12 for imgui");
    }
}

pub fn deinit() void {
    ImGui_ImplDX12_Shutdown();
}

pub fn newFrame() void {
    ImGui_ImplDX12_NewFrame();
}

pub fn render(
    draw_data: *const anyopaque, // *gui.DrawData
    gfx_command_list: *const anyopaque, // *ID3D12GraphicsCommandList
) void {
    ImGui_ImplDX12_RenderDrawData(draw_data, gfx_command_list);
}

// Those functions are defined in 'imgui_impl_dx12.cpp`
// (they include few custom changes).
extern fn ImGui_ImplDX12_Init(init_info: *const ImGui_ImplDX12_InitInfo) bool;
extern fn ImGui_ImplDX12_Shutdown() void;
extern fn ImGui_ImplDX12_NewFrame() void;
extern fn ImGui_ImplDX12_RenderDrawData(
    draw_data: *const anyopaque, // *ImDrawData
    graphics_command_list: *const anyopaque, // *ID3D12GraphicsCommandList
) void;
