const gui = @import("gui.zig");
const backend_glfw = @import("backend_glfw.zig");

// This call will install GLFW callbacks to handle GUI interactions.
// Those callbacks will chain-call user's previously installed callbacks, if any.
// This means that custom user's callbacks need to be installed *before* calling zgpu.gui.init().
pub fn init(
    window: *const anyopaque, // zglfw.Window
    wgpu_device: *const anyopaque, // wgpu.Device
    wgpu_swap_chain_format: u32, // wgpu.TextureFormat
    wgpu_depth_format: u32, // wgpu.TextureFormat
) void {
    var info = ImGui_ImplWGPU_InitInfo{
        .device = wgpu_device,
        .num_frames_in_flight = 1,
        .rt_format = wgpu_swap_chain_format,
        .depth_format = wgpu_depth_format,
        .pipeline_multisample_state = .{},
    };

    if (!ImGui_ImplWGPU_Init(&info)) {
        unreachable;
    }

    backend_glfw.init(window);
}

pub fn deinit() void {
    ImGui_ImplWGPU_Shutdown();
    backend_glfw.deinit();
}

var _width: u32 = 0;
var _height: u32 = 0;
pub fn newFrame(width: u32, height: u32) void {
    if (width != _width or height != _height) {
        ImGui_ImplWGPU_InvalidateDeviceObjects();
        if (ImGui_ImplWGPU_CreateDeviceObjects()) {
            _width = width;
            _height = height;
        }
    }
    ImGui_ImplWGPU_NewFrame();
    backend_glfw.newFrame();
    gui.newFrame();
}

pub fn draw(wgpu_render_pass: *const anyopaque) void {
    gui.render();
    ImGui_ImplWGPU_RenderDrawData(gui.getDrawData(), wgpu_render_pass);
}

pub const ImGui_ImplWGPU_InitInfo = extern struct {
    device: *const anyopaque,
    num_frames_in_flight: u32 = 1,
    rt_format: u32,
    depth_format: u32,

    pipeline_multisample_state: extern struct {
        next_in_chain: ?*const anyopaque = null,
        count: u32 = 1,
        mask: u32 = @bitCast(@as(i32, -1)),
        alpha_to_coverage_enabled: bool = false,
    },
};

// Those functions are defined in 'imgui_impl_wgpu.cpp`
// (they include few custom changes).
extern fn ImGui_ImplWGPU_Init(init_info: *ImGui_ImplWGPU_InitInfo) callconv(.c) bool;
extern fn ImGui_ImplWGPU_InvalidateDeviceObjects() callconv(.c) void;
extern fn ImGui_ImplWGPU_CreateDeviceObjects() callconv(.c) bool;
extern fn ImGui_ImplWGPU_NewFrame() callconv(.c) void;
extern fn ImGui_ImplWGPU_RenderDrawData(draw_data: *const anyopaque, pass_encoder: *const anyopaque) callconv(.c) void;
extern fn ImGui_ImplWGPU_Shutdown() callconv(.c) void;
