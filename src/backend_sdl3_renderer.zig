const gui = @import("gui.zig");
const backend_sdl3 = @import("backend_sdl3.zig");

pub fn init(
    window: *const anyopaque, // SDL_Window
    renderer: *const anyopaque, // SDL_Renderer 
) void {
    backend_sdl3.initRenderer(window, renderer);
    if(!ImGui_ImplSDLRenderer3_Init(renderer)){
        unreachable;
    }
}

pub fn processEvent(
    event: *const anyopaque, // SDL_Event
) bool {
    return backend_sdl3.processEvent(event);
}

pub fn deinit() void {
    ImGui_ImplSDLRenderer3_Shutdown();
    backend_sdl3.deinit();
}

pub fn newFrame(fb_width: u32, fb_height: u32) void {
    ImGui_ImplSDLRenderer3_NewFrame();
    backend_sdl3.newFrame();

    gui.io.setDisplaySize(@as(f32, @floatFromInt(fb_width)), @as(f32, @floatFromInt(fb_height)));
    gui.io.setDisplayFramebufferScale(1.0, 1.0);

    gui.newFrame();
}

pub fn draw(
    renderer: *const anyopaque, // SDL_Renderer
) void {
    gui.render();
    ImGui_ImplSDLRenderer3_RenderDrawData(gui.getDrawData(), renderer);
}

extern fn ImGui_ImplSDLRenderer3_Init(renderer: *const anyopaque) bool;
extern fn ImGui_ImplSDLRenderer3_Shutdown() void;
extern fn ImGui_ImplSDLRenderer3_NewFrame() void;
extern fn ImGui_ImplSDLRenderer3_RenderDrawData(draw_data: gui.DrawData, renderer: *const anyopaque) void;

//TODO extern fn ImGui_ImplSDLRenderer3_CreateFontsTexture() bool;
//TODO extern fn ImGui_ImplSDLRenderer3_DestroyFontsTexture() void;
//TODO extern fn ImGui_ImplSDLRenderer3_CreateDeviceObjects() bool;
//TODO extern fn ImGui_ImplSDLRenderer3_DestroyDeviceObjects() void;

