extern "c" fn rlImGuiSetup(dark_theme: bool) void;
extern "c" fn rlImGuiShutdown() void;
extern "c" fn rlImGuiBegin() void;
extern "c" fn rlImGuiBeginDelta(delta_time: f32) void;
extern "c" fn rlImGuiEnd() void;

pub fn init() void {
    rlImGuiSetup(true);
}

pub fn deinit() void {
    rlImGuiShutdown();
}

pub fn newFrame() void {
    rlImGuiBegin();
}

pub fn draw() void {
    rlImGuiEnd();
}
