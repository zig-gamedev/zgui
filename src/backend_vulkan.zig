const gui = @import("gui.zig");

pub const VkHandle = ?*const anyopaque;

pub const VkPipelineRenderingCreateInfo = extern struct {
    s_type: u32 = 0,
    p_next: ?*const void = null,
    view_mask: u32 = 0,
    color_attachment_count: u32 = 0,
    p_color_attachment_formats: ?[*]const c_int = null, // VkFormat
    depth_attachment_format: c_int = 0, // VkFormat
    stencil_attachment_format: c_int = 0, // VkFormat
};

pub const ImGui_ImplVulkan_InitInfo = extern struct {
    instance: VkHandle, // VkInstance
    physical_device: VkHandle, // VkPhysicalDevice
    device: VkHandle, // VkDevice
    queue_family: u32,
    queue: VkHandle, // VkQueue
    descriptor_pool: VkHandle, // VkDescriptorPool
    render_pass: VkHandle, // VkRenderPass
    min_image_count: u32,
    image_count: u32,
    msaa_samples: u32 = 0, // vkSampleCountFlags

    // Optional fields
    pipeline_cache: VkHandle = null, // VkPipelineCache
    subpass: u32 = 0,
    descriptor_pool_size: u32 = 0,

    use_dynamic_rendering: bool = false,
    pipeline_rendering_create_info: VkPipelineRenderingCreateInfo = .{},

    allocator: ?*const anyopaque = null,
    check_vk_result_fn: ?*const fn (err: u32) callconv(.C) void = null,
    min_allocation_size: u64 = 0,
};

pub fn init(init_info: ImGui_ImplVulkan_InitInfo) void {
    var vk_init: ImGui_ImplVulkan_InitInfo = init_info;
    if (!ImGui_ImplVulkan_Init(&vk_init)) {
        @panic("failed to init Vulkan for ImGui");
    }
    ImGui_ImplVulkan_CreateFontsTexture();
}

pub fn loadFunctions(
    loader: fn (function_name: [*:0]const u8, user_data: ?*anyopaque) callconv(.C) ?*anyopaque,
    user_data: ?*anyopaque,
) bool {
    return ImGui_ImplVulkan_LoadFunctions(loader, user_data);
}

pub fn deinit() void {
    ImGui_ImplVulkan_DestroyFontsTexture();
    ImGui_ImplVulkan_Shutdown();
}

pub fn newFrame() void {
    ImGui_ImplVulkan_NewFrame();
}

pub fn render(
    command_buffer: VkHandle,
) void {
    gui.render();
    ImGui_ImplVulkan_RenderDrawData(gui.getDrawData(), command_buffer, null);
}

pub fn set_min_image_count(min_image_count: u32) void {
    ImGui_ImplVulkan_SetMinImageCount(min_image_count);
}

// Those functions are defined in 'imgui_impl_vulkan.cpp`
// (they include few custom changes).
extern fn ImGui_ImplVulkan_Init(init_info: *ImGui_ImplVulkan_InitInfo) bool;
extern fn ImGui_ImplVulkan_Shutdown() void;
extern fn ImGui_ImplVulkan_NewFrame() void;
extern fn ImGui_ImplVulkan_RenderDrawData(
    draw_data: *const anyopaque, // *ImDrawData
    command_buffer: VkHandle, // VkCommandBuffer
    pipeline: VkHandle,
) void;
extern fn ImGui_ImplVulkan_CreateFontsTexture() void;
extern fn ImGui_ImplVulkan_DestroyFontsTexture() void;
extern fn ImGui_ImplVulkan_SetMinImageCount(min_image_count: u32) void;
extern fn ImGui_ImplVulkan_LoadFunctions(
    loader_func: *const fn (function_name: [*:0]const u8, user_data: ?*anyopaque) callconv(.C) ?*anyopaque,
    user_data: ?*anyopaque,
) bool;
