const gui = @import("gui.zig");
const backend_sdl2 = @import("backend_sdl2.zig");

pub fn init(
    window: *const anyopaque, // SDL_Window
    renderer: *const anyopaque, // SDL_Renderer 
) void {
    backend_sdl2.initRenderer(window, renderer);
    if(!ImGui_ImplSDLRenderer2_Init(renderer)){
        unreachable;
    }
}

pub fn processEvent(
    event: *const anyopaque, // SDL_Event
) bool {
    return backend_sdl2.processEvent(event);
}

pub fn deinit() void {
    ImGui_ImplSDLRenderer2_Shutdown();
    backend_sdl2.deinit();
}

pub fn newFrame(fb_width: u32, fb_height: u32) void {
    ImGui_ImplSDLRenderer2_NewFrame();
    backend_sdl2.newFrame();

    gui.io.setDisplaySize(@as(f32, @floatFromInt(fb_width)), @as(f32, @floatFromInt(fb_height)));
    gui.io.setDisplayFramebufferScale(1.0, 1.0);

    gui.newFrame();
}

pub fn draw(
    renderer: *const anyopaque, // SDL_Renderer
) void {
    gui.render();
    ImGui_ImplSDLRenderer2_RenderDrawData(gui.getDrawData(), renderer);
}

extern fn ImGui_ImplSDLRenderer2_Init(renderer: *const anyopaque) bool;
extern fn ImGui_ImplSDLRenderer2_Shutdown() void;
extern fn ImGui_ImplSDLRenderer2_NewFrame() void;
extern fn ImGui_ImplSDLRenderer2_RenderDrawData(draw_data: gui.DrawData, renderer: *const anyopaque) void;

//TODO: extern fn ImGui_ImplSDLRenderer2_CreateFontsTexture() bool;
//TODO: extern fn ImGui_ImplSDLRenderer2_DestroyFontsTexture() void;
//TODO: extern fn ImGui_ImplSDLRenderer2_CreateDeviceObjects() bool;
//TODO: extern fn ImGui_ImplSDLRenderer2_DestroyDeviceObjects() void;

