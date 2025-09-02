//--------------------------------------------------------------------------------------------------
//
// Zig bindings for 'dear imgui' library. Easy to use, hand-crafted API with default arguments,
// named parameters and Zig style text formatting.
//
//--------------------------------------------------------------------------------------------------
pub const plot = @import("plot.zig");
pub const gizmo = @import("gizmo.zig");
pub const node_editor = @import("node_editor.zig");
pub const te = @import("te.zig");

pub const cimgui = @cImport({
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", "");
    @cInclude("cimgui.h");
});

pub const backend = switch (@import("zgui_options").backend) {
    .glfw_wgpu => @import("backend_glfw_wgpu.zig"),
    .glfw_opengl3 => @import("backend_glfw_opengl.zig"),
    .glfw_dx12 => @import("backend_glfw_dx12.zig"),
    .glfw_vulkan => @import("backend_glfw_vulkan.zig"),
    .glfw => @import("backend_glfw.zig"),
    .win32_dx12 => @import("backend_win32_dx12.zig"),
    .osx_metal => @import("backend_osx_metal.zig"),
    .sdl2 => @import("backend_sdl2.zig"),
    .sdl2_opengl3 => @import("backend_sdl2_opengl.zig"),
    .sdl2_renderer => @import("backend_sdl2_renderer.zig"),
    .sdl3 => @import("backend_sdl3.zig"),
    .sdl3_opengl3 => @import("backend_sdl3_opengl.zig"),
    .sdl3_renderer => @import("backend_sdl3_renderer.zig"),
    .sdl3_gpu => @import("backend_sdl3_gpu.zig"),
    .no_backend => .{},
};
const te_enabled = @import("zgui_options").with_te;
//--------------------------------------------------------------------------------------------------
const std = @import("std");
const assert = std.debug.assert;
//--------------------------------------------------------------------------------------------------
pub const f32_min: f32 = 1.17549435082228750796873653722225e-38;
pub const f32_max: f32 = 3.40282346638528859811704183484517e+38;
//--------------------------------------------------------------------------------------------------
pub const DrawIdx = if (@import("zgui_options").use_32bit_draw_idx) u32 else u16;
pub const DrawVert = cimgui.ImDrawVert;
//--------------------------------------------------------------------------------------------------

pub fn init(allocator: std.mem.Allocator) void {
    if (cimgui.igGetCurrentContext() == null) {
        mem_allocator = allocator;
        mem_allocations = std.AutoHashMap(usize, usize).init(allocator);
        mem_allocations.?.ensureTotalCapacity(32) catch @panic("zgui: out of memory");
        cimgui.igSetAllocatorFunctions(zguiMemAlloc, zguiMemFree, null);

        _ = cimgui.igCreateContext(null);

        temp_buffer = std.ArrayList(u8){};
        temp_buffer.?.resize(allocator, 3 * 1024 + 1) catch unreachable;

        if (te_enabled) {
            te.init();
        }
    }
}
/// Allows sharing a context across static/DLL boundaries. This is useful for
/// hot-reloading mechanisms which rely on shared libraries.
/// See "CONTEXT AND MEMORY ALLOCATORS" section of ImGui docs.
pub fn initWithExistingContext(allocator: std.mem.Allocator, ctx: Context) void {
    mem_allocator = allocator;
    mem_allocations = std.AutoHashMap(usize, usize).init(allocator);
    mem_allocations.?.ensureTotalCapacity(32) catch @panic("zgui: out of memory");
    cimgui.igSetAllocatorFunctions(zguiMemAlloc, zguiMemFree, null);

    cimgui.igSetCurrentContext(ctx);

    temp_buffer = std.ArrayList(u8){};
    temp_buffer.?.resize(allocator, 3 * 1024 + 1) catch unreachable;

    if (te_enabled) {
        te.init();
    }
}
pub fn getCurrentContext() ?Context {
    return cimgui.igGetCurrentContext();
}
pub fn deinit() void {
    
    if (cimgui.igGetCurrentContext() != null) {
        temp_buffer.?.deinit(mem_allocator.?);
        cimgui.igDestroyContext(null);

        // Must be after destroy imgui context.
        // And before allocation check
        if (te_enabled) {
            te.deinit();
        }

        if (mem_allocations.?.count() > 0) {
            var it = mem_allocations.?.iterator();
            while (it.next()) |kv| {
                const address = kv.key_ptr.*;
                const size = kv.value_ptr.*;
                mem_allocator.?.free(@as([*]align(mem_alignment.toByteUnits()) u8, @ptrFromInt(address))[0..size]);
                std.log.info(
                    "[zgui] Possible memory leak or static memory usage detected: (address: 0x{x}, size: {d})",
                    .{ address, size },
                );
            }
            mem_allocations.?.clearAndFree();
        }

        assert(mem_allocations.?.count() == 0);
        mem_allocations.?.deinit();
        mem_allocations = null;
        mem_allocator = null;
    }
}
pub fn initNoContext() void {
    if (temp_buffer == null) {
        temp_buffer = std.ArrayList(u8){};
        temp_buffer.?.resize(mem_allocator.?, 3 * 1024 + 1) catch unreachable;
    }
}
pub fn deinitNoContext() void {
    temp_buffer.?.deinit(mem_allocator.?);
}
//--------------------------------------------------------------------------------------------------
var mem_allocator: ?std.mem.Allocator = null;
var mem_allocations: ?std.AutoHashMap(usize, usize) = null;
var mem_mutex: std.Thread.Mutex = .{};
const mem_alignment: std.mem.Alignment = .@"16";

fn zguiMemAlloc(size: usize, _: ?*anyopaque) callconv(.c) ?*anyopaque {
    mem_mutex.lock();
    defer mem_mutex.unlock();

    const mem = mem_allocator.?.alignedAlloc(
        u8,
        mem_alignment,
        size,
    ) catch @panic("zgui: out of memory");

    mem_allocations.?.put(@intFromPtr(mem.ptr), size) catch @panic("zgui: out of memory");

    return mem.ptr;
}

fn zguiMemFree(maybe_ptr: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
    if (maybe_ptr) |ptr| {
        mem_mutex.lock();
        defer mem_mutex.unlock();

        if (mem_allocations != null) {
            if (mem_allocations.?.fetchRemove(@intFromPtr(ptr))) |kv| {
                const size = kv.value;
                const mem = @as([*]align(mem_alignment.toByteUnits()) u8, @ptrCast(@alignCast(ptr)))[0..size];
                mem_allocator.?.free(mem);
            }
        }
    }
}

//--------------------------------------------------------------------------------------------------
pub const ConfigFlags = packed struct(c_int) {
    nav_enable_keyboard: bool = false,
    nav_enable_gamepad: bool = false,
    nav_enable_set_mouse_pos: bool = false,
    nav_no_capture_keyboard: bool = false,
    no_mouse: bool = false,
    no_mouse_cursor_change: bool = false,
    no_keyboard: bool = false,
    dock_enable: bool = false,
    _padding0: u2 = 0,
    viewport_enable: bool = false,
    _padding1: u3 = 0,
    dpi_enable_scale_viewport: bool = false,
    dpi_enable_scale_fonts: bool = false,
    user_storage: u4 = 0,
    is_srgb: bool = false,
    is_touch_screen: bool = false,
    _padding: u10 = 0,
};

pub const BackendFlags = packed struct(c_int) {
    has_gamepad: bool = false,
    has_mouse_cursors: bool = false,
    has_set_mouse_pos: bool = false,
    renderer_has_vtx_offset: bool = false,
    renderer_has_textures: bool = false,
    _pading0: u5 = 0,
    platform_has_viewports: bool = false,
    has_mouse_hovered_viewports: bool = false,
    renderer_has_viewports: bool = false,
    _padding: u19 = 0,
};

pub const FreeTypeLoaderFlags = packed struct(c_uint) {
    no_hinting: bool = false,
    no_auto_hint: bool = false,
    force_auto_hint: bool = false,
    light_hinting: bool = false,
    mono_hinting: bool = false,
    bold: bool = false,
    oblique: bool = false,
    monochrome: bool = false,
    load_color: bool = false,
    bitmap: bool = false,
    _padding: u22 = 0,
};

pub const FontConfig = cimgui.ImFontConfig;

pub const io = struct {
    pub const GetIO = cimgui.igGetIO_Nil;

    pub fn addFontDefault(config: ?FontConfig) Font {
        return cimgui.ImFontAtlas_AddFontDefault(GetIO().*.Fonts, if (config) |c| &c else null);
    }

    pub fn addFontFromFile(filename: [:0]const u8, size_pixels: f32) Font {
        const fonts = cimgui.igGetIO_Nil().*.Fonts;
        return cimgui.ImFontAtlas_AddFontFromFileTTF(fonts, filename, size_pixels, null, null);
    }

    pub fn addFontFromFileWithConfig(
        filename: [:0]const u8,
        size_pixels: f32,
        config: ?FontConfig,
        ranges: ?[*]const Wchar,
    ) Font {
        return cimgui.ImFontAtlas_AddFontFromFileTTF(
            cimgui.igGetIO_Nil().*.Fonts,
            filename,
            size_pixels, 
            if (config) |c| &c else null,
            ranges
        );
    }

    pub fn addFontFromMemory(fontdata: []const u8, size_pixels: f32) Font {
        const config = cimgui.ImFontConfig_ImFontConfig();
        config.*.FontDataOwnedByAtlas = false;

        return cimgui.ImFontAtlas_AddFontFromMemoryTTF(
            GetIO().*.Fonts,
            @constCast(fontdata.ptr), @intCast(fontdata.len),
            size_pixels,
            config,
            null);
    }

    pub fn addFontFromMemoryWithConfig(
        fontdata: []const u8,
        size_pixels: f32,
        config: ?FontConfig,
        ranges: ?[*]const Wchar,
    ) Font {
        return cimgui.ImFontAtlas_AddFontFromMemoryTTF(
            GetIO().*.Fonts,
            @constCast(fontdata.ptr), @intCast(fontdata.len),
            size_pixels,
            if (config) |c| &c else null,
            ranges,
        );
    }

    pub fn removeFont(font: Font) void {
        cimgui.ImFontAtlas_RemoveFont(GetIO().*.Fonts, font);
    }

    pub fn getFont(index: u32) Font {
        return GetIO().*.Fonts.*.Fonts.Data[index];
    }

    pub fn setDefaultFont(font: Font) void{
        GetIO().*.FontDefault = font;
    }

    pub fn getGlyphRangesDefault() [*]const Wchar{
        return cimgui.ImFontAtlas_GetGlyphRangesDefault(GetIO().*.Fonts);
    }
    
    pub fn setConfigWindowsMoveFromTitleBarOnly(enabled: bool) void{
        var IO = GetIO().*;
        IO.ConfigWindowsMoveFromTitleBarOnly = enabled;
    }

    pub fn getWantCaptureMouse() bool{
        return GetIO().*.WantCaptureMouse;
    }

    pub fn getWantCaptureKeyboard() bool{
        return GetIO().*.WantCaptureKeyboard;
    }

    pub fn getWantTextInput() bool{
        return GetIO().*.WantTextInput;
    }

    pub fn getFramerate() f32{
        return GetIO().*.Framerate;
    }

    pub fn getFontsTexRef() TextureRef{
        return GetIO().*.Fonts.*.TexRef;
        
    }

    pub fn setIniFilename(filename: ?[*:0]const u8) void {
        var IO = GetIO().*;
        IO.IniFilename = filename;
    }

    pub fn setDisplaySize(width: f32, height: f32) void{
        var IO = GetIO().*;
        IO.DisplaySize = .{.x = width, .y = height};
    }

    pub fn getDisplaySize() Vec2 {
        return @bitCast(GetIO().*.DisplaySize);
    }

    pub fn setDisplayFramebufferScale(sx: f32, sy: f32) void{
        var IO = GetIO().*;
        IO.DisplayFramebufferScale = .{.x = sx, .y = sy};
    }

    pub fn setConfigFlags(flags: ConfigFlags) void{
        var IO = GetIO().*;
        IO.ConfigFlags = @bitCast(flags);
    }

    pub fn setDeltaTime(delta_time: f32) void{
        var IO = GetIO().*;
        IO.DeltaTime = delta_time;
    }

    pub fn setBackendFlags(flags: BackendFlags) void{
        var IO = GetIO().*;
        IO.BackendFlags = @bitCast(flags);
    }


    pub fn addFocusEvent(focused: bool) void{
        cimgui.ImGuiIO_AddFocusEvent(GetIO(), focused);
    }

    pub fn addMousePositionEvent(x: f32, y: f32) void{
        cimgui.ImGuiIO_AddMousePosEvent(GetIO(), x, y);
    }

    pub fn addMouseButtonEvent(btn: MouseButton, down: bool) void{
        cimgui.ImGuiIO_AddMouseButtonEvent(GetIO(), @intFromEnum(btn), down);
    }

    pub fn addMouseWheelEvent(x: f32, y: f32) void{
        cimgui.ImGuiIO_AddMouseWheelEvent(GetIO(), x, y);
    }

    pub fn addKeyEvent(key: Key, down: bool) void{
        cimgui.ImGuiIO_AddKeyEvent(GetIO(), @intFromEnum(key), down);
    }

    pub fn addInputCharactersUTF8(utf8_chars: ?[*:0]const u8) void{
        cimgui.ImGuiIO_AddInputCharactersUTF8(GetIO(), utf8_chars);
    }

    pub fn setKeyEventNativeData(key: Key, keycode: i32, scancode: i32) void {
        cimgui.ImGuiIO_SetKeyEventNativeData(GetIO(), @intFromEnum(key), keycode, scancode, -1);
    }

    pub fn addCharacterEvent(char: i32) void {
        cimgui.ImGuiIO_AddInputCharacter(GetIO(), @intCast(char));
    }
};

pub fn setClipboardText(value: [:0]const u8) void {
    cimgui.igSetClipboardText(value);
}
pub fn getClipboardText() [:0]const u8 {
    const value = cimgui.igGetClipboardText();
    return std.mem.span(value);
}
//--------------------------------------------------------------------------------------------------
pub const Context = *cimgui.ImGuiContext;
pub const DrawData = *cimgui.ImDrawData;
pub const Font = *cimgui.ImFont;
pub const Ident = u32;
pub const Vec2 = cimgui.ImVec2;
pub const Vec4 = cimgui.ImVec4;
pub const TextureIdent = cimgui.ImTextureID;
pub const TextureRef = cimgui.ImTextureRef;
pub const Wchar = if (@import("zgui_options").use_wchar32) u32 else u16;
pub const Key = enum(c_uint) {
    none = 0,
    tab = 512,
    left_arrow,
    right_arrow,
    up_arrow,
    down_arrow,
    page_up,
    page_down,
    home,
    end,
    insert,
    delete,
    back_space,
    space,
    enter,
    escape,
    left_ctrl,
    left_shift,
    left_alt,
    left_super,
    right_ctrl,
    right_shift,
    right_alt,
    right_super,
    menu,
    zero,
    one,
    two,
    three,
    four,
    five,
    six,
    seven,
    eight,
    nine,
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
    o,
    p,
    q,
    r,
    s,
    t,
    u,
    v,
    w,
    x,
    y,
    z,
    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,
    f13,
    f14,
    f15,
    f16,
    f17,
    f18,
    f19,
    f20,
    f21,
    f22,
    f23,
    f24,
    apostrophe,
    comma,
    minus,
    period,
    slash,
    semicolon,
    equal,
    left_bracket,
    back_slash,
    right_bracket,
    grave_accent,
    caps_lock,
    scroll_lock,
    num_lock,
    print_screen,
    pause,
    keypad_0,
    keypad_1,
    keypad_2,
    keypad_3,
    keypad_4,
    keypad_5,
    keypad_6,
    keypad_7,
    keypad_8,
    keypad_9,
    keypad_decimal,
    keypad_divide,
    keypad_multiply,
    keypad_subtract,
    keypad_add,
    keypad_enter,
    keypad_equal,

    app_back,
    app_forward,

    gamepad_start,
    gamepad_back,
    gamepad_faceleft,
    gamepad_faceright,
    gamepad_faceup,
    gamepad_facedown,
    gamepad_dpadleft,
    gamepad_dpadright,
    gamepad_dpadup,
    gamepad_dpaddown,
    gamepad_l1,
    gamepad_r1,
    gamepad_l2,
    gamepad_r2,
    gamepad_l3,
    gamepad_r3,
    gamepad_lstickleft,
    gamepad_lstickright,
    gamepad_lstickup,
    gamepad_lstickdown,
    gamepad_rstickleft,
    gamepad_rstickright,
    gamepad_rstickup,
    gamepad_rstickdown,

    mouse_left,
    mouse_right,
    mouse_middle,
    mouse_x1,
    mouse_x2,

    mouse_wheel_x,
    mouse_wheel_y,

    mod_ctrl = 1 << 12,
    mod_shift = 1 << 13,
    mod_alt = 1 << 14,
    mod_super = 1 << 15,
    mod_mask_ = 0xf000,
};

//--------------------------------------------------------------------------------------------------
pub const WindowFlags = packed struct(c_int) {
    no_title_bar: bool = false,
    no_resize: bool = false,
    no_move: bool = false,
    no_scrollbar: bool = false,
    no_scroll_with_mouse: bool = false,
    no_collapse: bool = false,
    always_auto_resize: bool = false,
    no_background: bool = false,
    no_saved_settings: bool = false,
    no_mouse_inputs: bool = false,
    menu_bar: bool = false,
    horizontal_scrollbar: bool = false,
    no_focus_on_appearing: bool = false,
    no_bring_to_front_on_focus: bool = false,
    always_vertical_scrollbar: bool = false,
    always_horizontal_scrollbar: bool = false,
    no_nav_inputs: bool = false,
    no_nav_focus: bool = false,
    unsaved_document: bool = false,
    no_docking: bool = false,
    _padding: u12 = 0,

    pub const no_nav = WindowFlags{ .no_nav_inputs = true, .no_nav_focus = true };
    pub const no_decoration = WindowFlags{
        .no_title_bar = true,
        .no_resize = true,
        .no_scrollbar = true,
        .no_collapse = true,
    };
    pub const no_inputs = WindowFlags{
        .no_mouse_inputs = true,
        .no_nav_inputs = true,
        .no_nav_focus = true,
    };
};

pub const ChildFlags = packed struct(c_int) {
    border: bool = false,
    always_use_window_padding: bool = false,
    resize_x: bool = false,
    resize_y: bool = false,
    auto_resize_x: bool = false,
    auto_resize_y: bool = false,
    always_auto_resize: bool = false,
    frame_style: bool = false,
    nav_flattened: bool = false,
    _padding: u23 = 0,
};

//--------------------------------------------------------------------------------------------------
pub const SliderFlags = packed struct(c_int) {
    _reserved0: bool = false,
    _reserved1: bool = false,
    _reserved2: bool = false,
    _reserved3: bool = false,
    always_clamp: bool = false,
    logarithmic: bool = false,
    no_round_to_format: bool = false,
    no_input: bool = false,
    wrap_around: bool = false,
    _padding: u23 = 0,
};
//--------------------------------------------------------------------------------------------------
pub const ButtonFlags = packed struct(c_int) {
    mouse_button_left: bool = false,
    mouse_button_right: bool = false,
    mouse_button_middle: bool = false,
    _padding: u29 = 0,
};
//--------------------------------------------------------------------------------------------------
pub const Direction = enum(c_int) {
    none = -1,
    left = 0,
    right = 1,
    up = 2,
    down = 3,
};
//--------------------------------------------------------------------------------------------------
pub const DataType = enum(c_int) { I8, U8, I16, U16, I32, U32, I64, U64, F32, F64, BOOL };
//--------------------------------------------------------------------------------------------------
pub const Condition = enum(c_int) {
    none = 0,
    always = 1,
    once = 2,
    first_use_ever = 4,
    appearing = 8,
};
//--------------------------------------------------------------------------------------------------
//
// Main
//
//--------------------------------------------------------------------------------------------------
/// `pub fn newFrame() void`
pub const newFrame = cimgui.igNewFrame;
/// `pub fn endFrame() void`
pub const endFrame = cimgui.igEndFrame;
//--------------------------------------------------------------------------------------------------
/// `pub fn render() void`
pub const render = cimgui.igRender;
//--------------------------------------------------------------------------------------------------
/// `pub fn getDrawData() DrawData`
pub const getDrawData = cimgui.igGetDrawData;
//--------------------------------------------------------------------------------------------------
//
// Demo, Debug, Information
//
//--------------------------------------------------------------------------------------------------
/// `pub fn showDemoWindow(popen: ?*bool) void`
pub const showDemoWindow = cimgui.igShowDemoWindow;

pub const showMetricsWindow = cimgui.igShowMetricsWindow;
//--------------------------------------------------------------------------------------------------
//
// Windows
//
//--------------------------------------------------------------------------------------------------
pub fn setNextWindowViewport(viewport_id: Ident) void {
    cimgui.igSetNextWindowViewport(viewport_id);
}
//--------------------------------------------------------------------------------------------------
const SetNextWindowPos = struct {
    pos: Vec2 = .{},
    cond: Condition = .none,
    pivot: Vec2 = .{}
};
pub fn setNextWindowPos(args: SetNextWindowPos) void {
    cimgui.igSetNextWindowPos(args.pos, @intFromEnum(args.cond), args.pivot);
}
//--------------------------------------------------------------------------------------------------
// fn igSetNextWindowSize(size: ImVec2, cond: ImGuiCond) void
pub const setNextWindowSize = cimgui.igSetNextWindowSize;
//--------------------------------------------------------------------------------------------------
//
// fn igSetNextWindowContentSize(size: ImVec2) void;
pub const setNextWindowContentSize = cimgui.igSetNextWindowContentSize;
//--------------------------------------------------------------------------------------------------
const SetNextWindowCollapsed = struct {
    collapsed: bool,
    cond: Condition = .none,
};
// fn igSetNextWindowCollapsed(collapsed: bool, cond: ImGuiCond) void;
pub const setNextWindowCollapsed = cimgui.igSetNextWindowCollapsed;

//--------------------------------------------------------------------------------------------------
// fn igSetNextWindowFocus() void;
pub const setNextWindowFocus = cimgui.igSetNextWindowFocus;
//--------------------------------------------------------------------------------------------------
// fn igSetNextWindowScroll(scroll: ImVec2) void;
pub const setNextWindowScroll = cimgui.igSetNextWindowScroll;
//--------------------------------------------------------------------------------------------------
// fn igSetNextWindowBgAlpha(alpha: f32) void;
pub const setNextWindowBgAlpha = cimgui.igSetNextWindowBgAlpha;
//--------------------------------------------------------------------------------------------------
pub fn setWindowFocus(name: ?[:0]const u8) void {
    if(name) |n|{
        cimgui.igSetWindowFocus_Str(n);
    }else{
        cimgui.igSetWindowFocus_Nil();
    }
}
//-------------------------------------------------------------------------------------------------

// fn igSetKeyboardFocusHere(offset: c_int) void;
pub const setKeyboardFocusHere = cimgui.igSetKeyboardFocusHere; 

// fn igSetNavCursorVisible(visible: bool) void;
pub const setNavCursorVisible = cimgui.igSetNavCursorVisible;

// fn igSetNextItemAllowOverlap() void;
pub const setNextItemAllowOverlap = cimgui.igSetNextItemAllowOverlap;
//--------------------------------------------------------------------------------------------------
const Begin = struct {
    popen: ?*bool = null,
    flags: WindowFlags = .{},
};
pub fn begin(name: [:0]const u8, args: Begin) bool {
    return cimgui.igBegin(name, args.popen, @bitCast(args.flags));
}
pub const end = cimgui.igEnd;
//--------------------------------------------------------------------------------------------------
const BeginChild = struct {
    size: Vec2 = .{},
    child_flags: ChildFlags = .{},
    window_flags: WindowFlags = .{},
};
pub fn beginChild(str_id: [:0]const u8, args: BeginChild) bool {
    return cimgui.igBeginChild_Str(str_id, args.size, @bitCast(args.child_flags), @bitCast(args.window_flags));
}
pub fn beginChildId(id: Ident, args: BeginChild) bool {
    return cimgui.igBeginChild_ID(id, args.size, @bitCast(args.child_flags), @bitCast(args.window_flags));
}
// fn igEndChild() void;
pub const endChild = cimgui.igEndChild;
//--------------------------------------------------------------------------------------------------
pub const getScrollX = cimgui.igGetScrollX;
pub const getScrollY = cimgui.igGetScrollY;
pub const setScrollX = cimgui.igSetScrollX_Float;
pub const setScrollY = cimgui.igSetScrollY_Float;
pub const getScrollMaxX = cimgui.igGetScrollMaxX;
pub const getScrollMaxY = cimgui.igGetScrollMaxY;
pub const setScrollHereX = cimgui.igSetScrollHereX;
pub const setScrollHereY = cimgui.igSetScrollHereY;
pub const setScrollFromPosX = cimgui.igSetScrollFromPosX_Float;
pub const setScrollFromPosY = cimgui.igSetScrollFromPosY_Float;
//--------------------------------------------------------------------------------------------------
pub const FocusedFlags = packed struct(c_int) {
    child_windows: bool = false,
    root_window: bool = false,
    any_window: bool = false,
    no_popup_hierarchy: bool = false,
    dock_hierarchy: bool = false,
    _padding: u27 = 0,

    pub const root_and_child_windows = FocusedFlags{ .root_window = true, .child_windows = true };
};
//--------------------------------------------------------------------------------------------------
pub const HoveredFlags = packed struct(c_int) {
    child_windows: bool = false,
    root_window: bool = false,
    any_window: bool = false,
    no_popup_hierarchy: bool = false,
    dock_hierarchy: bool = false,
    allow_when_blocked_by_popup: bool = false,
    _reserved1: bool = false,
    allow_when_blocked_by_active_item: bool = false,
    allow_when_overlapped_by_item: bool = false,
    allow_when_overlapped_by_window: bool = false,
    allow_when_disabled: bool = false,
    no_nav_override: bool = false,
    for_tooltip: bool = false,
    stationary: bool = false,
    delay_none: bool = false,
    delay_normal: bool = false,
    delay_short: bool = false,
    no_shared_delay: bool = false,
    _padding: u14 = 0,

    pub const rect_only = HoveredFlags{
        .allow_when_blocked_by_popup = true,
        .allow_when_blocked_by_active_item = true,
        .allow_when_overlapped_by_item = true,
        .allow_when_overlapped_by_window = true,
    };
    pub const root_and_child_windows = HoveredFlags{ .root_window = true, .child_windows = true };
};
//--------------------------------------------------------------------------------------------------
pub const isWindowAppearing = cimgui.igIsWindowAppearing;
pub const isWindowCollapsed = cimgui.igIsWindowCollapsed;
pub fn isWindowFocused(flags: FocusedFlags) bool {
    return cimgui.igIsWindowFocused(@bitCast(flags));
}
pub fn isWindowHovered(flags: HoveredFlags) bool {
    return cimgui.igIsWindowHovered(@bitCast(flags));
}
//--------------------------------------------------------------------------------------------------
pub fn getWindowPos() Vec2 {
    var pos: Vec2 = undefined;
    cimgui.igGetWindowPos(&pos);
    return pos;
}
pub fn getWindowSize() Vec2 {
    var size: Vec2 = undefined;
    cimgui.igGetWindowSize(&size);
    return size;
}

pub fn getContentRegionAvail() Vec2 {
    var size: Vec2 = undefined;
    cimgui.igGetContentRegionAvail(&size);
    return size;
}
// https://github.com/ocornut/imgui/issues/7838
// pub fn getContentRegionMax() Vec2;
// pub fn getWindowContentRegionMin() Vec2 ;
// pub fn getWindowContentRegionMax() Vec2;

pub const getWindowWidth = cimgui.igGetWindowWidth;
pub const getWindowHeight = cimgui.igGetWindowHeight;
//--------------------------------------------------------------------------------------------------
//
// Docking
//
//--------------------------------------------------------------------------------------------------
pub const DockNodeFlags = packed struct(c_int) {
    keep_alive_only: bool = false,
    _reserved: u1 = 0,
    no_docking_over_central_node: bool = false,
    passthru_central_node: bool = false,
    no_docking_split: bool = false,
    no_resize: bool = false,
    auto_hide_tab_bar: bool = false,
    no_undocking: bool = false,
    _padding_0: u2 = 0,

    // Extended enum entries from imgui_internal (unstable, subject to change, use at own risk)
    dock_space: bool = false,
    central_node: bool = false,
    no_tab_bar: bool = false,
    hidden_tab_bar: bool = false,
    no_window_menu_button: bool = false,
    no_close_button: bool = false,
    no_resize_x: bool = false,
    no_resize_y: bool = false,
    docked_windows_in_focus_route: bool = false,
    no_docking_split_other: bool = false,
    no_docking_over_me: bool = false,
    no_docking_over_other: bool = false,
    no_docking_over_empty: bool = false,
    _padding_1: u9 = 0,
};

pub fn DockSpace(str_id: [:0]const u8, size: Vec2, flags: DockNodeFlags) Ident {
    return cimgui.igDockSpace(cimgui.igGetID_Str(str_id), size, @bitCast(flags), null);
}

pub const DockSpaceOverViewport = cimgui.igDockSpaceOverViewport;


//--------------------------------------------------------------------------------------------------
//
// ListClipper
//
//--------------------------------------------------------------------------------------------------

pub const ListClipper = struct {
    base: *cimgui.ImGuiListClipper,

    pub fn init() ListClipper {
        return .{ .base = cimgui.ImGuiListClipper_ImGuiListClipper() };
    }
    
    pub fn begin(self: *ListClipper, items_count: ?i32, items_height: ?f32) void{
        cimgui.ImGuiListClipper_Begin(self.base, items_count orelse std.math.maxInt(i32), items_height orelse -1);
    }

    pub fn end(self: *ListClipper) void{
        cimgui.ImGuiListClipper_End(self.base);
    }

    pub fn includeItemsByIndex(self: *ListClipper, item_begin: c_int, item_end: c_int) void{
        cimgui.ImGuiListClipper_IncludeItemsByIndex(self.base, item_begin, item_end);
    }


    pub fn step(self: *ListClipper) bool{
        return cimgui.ImGuiListClipper_Step(self.base);
    }
};

//--------------------------------------------------------------------------------------------------
//
// Style
//
//--------------------------------------------------------------------------------------------------
pub const Style = extern struct {
    base: *cimgui.ImGuiStyle,

    pub fn init() Style{
        return .{.base = cimgui.ImGuiStyle_ImGuiStyle()};
    }

    // `pub fn getStyle() *Style`
    pub const getStyle = cimgui.igGetStyle;

    // fn ImGuiStyle_ScaleAllSizes(*Style, scale_factor: f32) void;
    pub fn scaleAllSizes(self: *Style, scale_factor: f32) void{
        cimgui.ImGuiStyle_ScaleAllSizes(self.base, scale_factor);
    } 

    /// fn styleColorsDark(*Style)`
    pub fn setColorsDark(self: *Style) void{
        cimgui.igStyleColorsDark(self.base);
    } 

    /// fn styleColorsLight(*Style)`
    pub fn setColorsLight(self: *Style) void{
        cimgui.igStyleColorsLight(self.base);
    } 

    /// fn styleColorsClassic(*Style)`
    pub fn setColorsClassic(self: *Style) void{
        cimgui.igStyleColorsClassic(self.base);
    }

    pub const StyleColorsBuiltin = enum {
        dark,
        light,
        classic,
    };
    pub fn setColorsBuiltin(style: *Style, variant: StyleColorsBuiltin) void {
        switch (variant) {
            .dark => setColorsDark(style),
            .light => setColorsLight(style),
            .classic => setColorsDark(style),
        }
    }

    pub fn getColor(style: Style, idx: StyleCol) Vec4 {
        return style.base.Colors[@intCast(@intFromEnum(idx))];
    }

    pub fn setColor(style: *Style, idx: StyleCol, color: Vec4) void {
        style.base.Colors[@intCast(@intFromEnum(idx))] = color;
    }

};

//--------------------------------------------------------------------------------------------------
pub const StyleCol = enum(c_int) {
    text,
    text_disabled,
    window_bg,
    child_bg,
    popup_bg,
    border,
    border_shadow,
    frame_bg,
    frame_bg_hovered,
    frame_bg_active,
    title_bg,
    title_bg_active,
    title_bg_collapsed,
    menu_bar_bg,
    scrollbar_bg,
    scrollbar_grab,
    scrollbar_grab_hovered,
    scrollbar_grab_active,
    check_mark,
    slider_grab,
    slider_grab_active,
    button,
    button_hovered,
    button_active,
    header,
    header_hovered,
    header_active,
    separator,
    separator_hovered,
    separator_active,
    resize_grip,
    resize_grip_hovered,
    resize_grip_active,
    input_text_cursor,
    tab_hovered,
    tab,
    tab_selected,
    tab_selected_overline,
    tab_dimmed,
    tab_dimmed_selected,
    tab_dimmed_selected_overline,
    docking_preview,
    docking_empty_bg,
    plot_lines,
    plot_lines_hovered,
    plot_histogram,
    plot_histogram_hovered,
    table_header_bg,
    table_border_strong,
    table_border_light,
    table_row_bg,
    table_row_bg_alt,
    text_link,
    text_selected_bg,
    tree_lines,
    drag_drop_target,
    nav_cursor,
    nav_windowing_highlight,
    nav_windowing_dim_bg,
    modal_window_dim_bg,
};

pub const pushStyleColor4f = cimgui.igPushStyleColor_Vec4;
pub const pushStyleColor1u = cimgui.igPushStyleColor_U32;
pub const popStyleColor = cimgui.igPopStyleColor;
pub const pushTextWrapPos = cimgui.igPushTextWrapPos; 
pub const popTextWrapPos = cimgui.igPopTextWrapPos;

//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
pub const StyleVar = enum(c_int) {
    alpha, // 1f
    disabled_alpha, // 1f
    window_padding, // 2f
    window_rounding, // 1f
    window_border_size, // 1f
    window_min_size, // 2f
    window_title_align, // 2f
    child_rounding, // 1f
    child_border_size, // 1f
    popup_rounding, // 1f
    popup_border_size, // 1f
    frame_padding, // 2f
    frame_rounding, // 1f
    frame_border_size, // 1f
    item_spacing, // 2f
    item_inner_spacing, // 2f
    indent_spacing, // 1f
    cell_padding, // 2f
    scrollbar_size, // 1f
    scrollbar_rounding, // 1f
    grab_min_size, // 1f
    grab_rounding, // 1f
    tab_rounding, // 1f
    tab_border_size, // 1f
    tab_bar_border_size, // 1f
    tab_bar_overline_size, // 1f
    table_angled_headers_angle, // 1f
    table_angled_headers_text_align, // 2f
    button_text_align, // 2f
    selectable_text_align, // 2f
    separator_text_border_size, // 1f
    separator_text_align, // 2f
    separator_text_padding, // 2f
    docking_separator_size, // 1f
};

pub const pushStyleVar1f = cimgui.igPushStyleVar_Float;
pub const pushStyleVar2f = cimgui.igPushStyleVar_Vec2;
pub const popStyleVar = cimgui.igPopStyleVar;

//--------------------------------------------------------------------------------------------------
pub const ItemFlag = enum(c_int) {
    none = 0,
    no_tab_stop = 1 << 0,
    no_nav = 1 << 1,
    no_nav_default_focus = 1 << 2,
    button_repeat = 1 << 3,
    auto_close_popups = 1 << 4,
    allow_duplicate_id = 1 << 5,
};
pub fn pushItemFlag(item_flag: ItemFlag, enabled: bool) void{
    cimgui.igPushItemFlag(@intFromEnum(item_flag), enabled);
}
pub const popItemFlag = cimgui.igPopItemFlag; 
pub const pushItemWidth = cimgui.igPushItemWidth; 
pub const popItemWidth = cimgui.igPopItemWidth;
pub const setNextItemWidth = cimgui.igSetNextItemWidth; 
pub const setItemDefaultFocus = cimgui.igSetItemDefaultFocus;
//--------------------------------------------------------------------------------------------------
pub const getFont = cimgui.igGetFont;
pub const getFontSize = cimgui.igGetFontSize;
pub const pushFont = cimgui.igPushFont;
pub const popFont = cimgui.igPopFont;

pub fn getFontTexUvWhitePixel() Vec2 {
    var uv: Vec2 = undefined;
    cimgui.igGetFontTexUvWhitePixel(&uv);
    return uv;
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
pub const beginDisabled = cimgui.igBeginDisabled;
pub const endDisabled = cimgui.igEndDisabled;
//--------------------------------------------------------------------------------------------------
//
// Cursor / Layout
//
//--------------------------------------------------------------------------------------------------
pub const separator = cimgui.igSeparator;
pub const separatorText = cimgui.igSeparatorText;
//--------------------------------------------------------------------------------------------------
const SameLine = struct {
    offset_from_start_x: f32 = 0.0,
    spacing: f32 = -1.0,
};
pub fn sameLine(args: SameLine) void {
    cimgui.igSameLine(args.offset_from_start_x, args.spacing);
}
//--------------------------------------------------------------------------------------------------
pub const newLine = cimgui.igNewLine;
pub const spacing = cimgui.igSpacing;
//--------------------------------------------------------------------------------------------------
pub const dummy = cimgui.igDummy;
//--------------------------------------------------------------------------------------------------
pub const indent = cimgui.igIndent;
pub const unindent = cimgui.igUnindent;
//--------------------------------------------------------------------------------------------------
pub const beginGroup = cimgui.igBeginGroup;
pub const endGroup = cimgui.igEndGroup;
//--------------------------------------------------------------------------------------------------
pub fn getCursorPos() Vec2 {
    var pos: Vec2 = undefined;
    cimgui.igGetCursorPos(&pos);
    return pos;
}
pub const getCursorPosX = cimgui.igGetCursorPosX;
pub const getCursorPosY = cimgui.igGetCursorPosY;
//--------------------------------------------------------------------------------------------------
pub const setCursorPos = cimgui.igSetCursorPos;
pub const setCursorPosX = cimgui.igSetCursorPosX;
pub const setCursorPosY = cimgui.igSetCursorPosY;
//--------------------------------------------------------------------------------------------------
pub fn getCursorStartPos() Vec2 {
    var pos: Vec2 = undefined;
    cimgui.igGetCursorStartPos(&pos);
    return pos;
}
pub fn getCursorScreenPos() Vec2 {
    var pos: Vec2 = undefined;
    cimgui.igGetCursorScreenPos(&pos);
    return pos;
}

pub const setCursorScreenPos = cimgui.igSetCursorScreenPos;
//--------------------------------------------------------------------------------------------------
pub const Cursor = enum(c_int) {
    none = -1,
    arrow = 0,
    text_input,
    resize_all,
    resize_ns,
    resize_ew,
    resize_nesw,
    resize_nwse,
    hand,
    not_allowed,
    count,
};
/// `pub fn getMouseCursor() MouseCursor`
pub const getMouseCursor = cimgui.igGetMouseCursor;
/// `pub fn setMouseCursor(cursor: MouseCursor) void`
pub const setMouseCursor = cimgui.igSetMouseCursor;

pub const setNextFrameWantCaptureMouse = cimgui.igSetNextFrameWantCaptureMouse;
//--------------------------------------------------------------------------------------------------
pub fn getMousePos() Vec2 {
    var pos: Vec2 = undefined;
    cimgui.igGetMousePos(&pos);
    return pos;
}
//--------------------------------------------------------------------------------------------------
/// `pub fn alignTextToFramePadding() void`
pub const alignTextToFramePadding = cimgui.igAlignTextToFramePadding;
/// `pub fn getTextLineHeight() f32`
pub const getTextLineHeight = cimgui.igGetTextLineHeight;
/// `pub fn getTextLineHeightWithSpacing() f32`
pub const getTextLineHeightWithSpacing = cimgui.igGetTextLineHeightWithSpacing;
/// `pub fn getFrameHeight() f32`
pub const getFrameHeight = cimgui.igGetFrameHeight;
/// `pub fn getFrameHeightWithSpacing() f32`
pub const getFrameHeightWithSpacing = cimgui.igGetFrameHeightWithSpacing;
//--------------------------------------------------------------------------------------------------
pub fn getItemRectMax() Vec2 {
    var rect: Vec2 = undefined;
    cimgui.igGetItemRectMax(&rect);
    return rect;
}
pub fn getItemRectMin() Vec2 {
    var rect: Vec2 = undefined;
    cimgui.igGetItemRectMin(&rect);
    return rect;
}
pub fn getItemRectSize() Vec2 {
    var rect: Vec2 = undefined;
    cimgui.igGetItemRectSize(&rect);
    return rect;
}
//--------------------------------------------------------------------------------------------------
//
// ID stack/scopes
//
//--------------------------------------------------------------------------------------------------
pub fn pushStrId(str_id: []const u8) void {
    cimgui.igPushID_StrStr(str_id.ptr, str_id.ptr + str_id.len);
}

pub fn pushStrIdZ(str_id: [:0]const u8) void {
    cimgui.igPushID_Str(str_id);
}

pub fn pushPtrId(ptr_id: *const anyopaque) void {
    cimgui.igPushID_Ptr(ptr_id);
}

pub fn pushIntId(int_id: i32) void {
    cimgui.igPushID_Int(int_id);
}

/// `pub fn popId() void`
pub const popId = cimgui.igPopID;

pub fn getStrId(str_id: []const u8) Ident {
    return cimgui.igGetID_StrStr(str_id.ptr, str_id.ptr + str_id.len);
}

pub fn getStrIdZ(str_id: [:0]const u8) Ident {
    return cimgui.igGetID_Str(str_id);
}

pub fn getPtrId(ptr_id: *const anyopaque) Ident {
    return cimgui.igGetID_Ptr(ptr_id);
}

//--------------------------------------------------------------------------------------------------
//
// Widgets: Text
//
//--------------------------------------------------------------------------------------------------
pub fn textUnformatted(txt: []const u8) void {
    cimgui.igTextUnformatted(txt.ptr, txt.ptr + txt.len);
}
pub fn textUnformattedColored(color: Vec4, txt: []const u8) void {
    pushStyleColor4f(@intFromEnum(StyleCol.text), color);
    textUnformatted(txt);
    popStyleColor(0);
}
//--------------------------------------------------------------------------------------------------
pub fn text(comptime fmt: []const u8, args: anytype) void {
    const result = format(fmt, args);
    cimgui.igTextUnformatted(result.ptr, result.ptr + result.len);
}
pub fn textColored(color: Vec4, comptime fmt: []const u8, args: anytype) void {
    pushStyleColor4f(.{ .idx = .text, .c = color });
    text(fmt, args);
    popStyleColor(0);
}
//--------------------------------------------------------------------------------------------------
pub fn textDisabled(comptime fmt: []const u8, args: anytype) void {
    cimgui.igTextDisabled("%s", formatZ(fmt, args).ptr);
}
//--------------------------------------------------------------------------------------------------
pub fn textWrapped(comptime fmt: []const u8, args: anytype) void {
    cimgui.igTextWrapped("%s", formatZ(fmt, args).ptr);
}
//--------------------------------------------------------------------------------------------------
pub fn bulletText(comptime fmt: []const u8, args: anytype) void {
    bullet();
    text(fmt, args);
}
//--------------------------------------------------------------------------------------------------
pub fn labelText(label: [:0]const u8, comptime fmt: []const u8, args: anytype) void {
    cimgui.igLabelText(label, "%s", formatZ(fmt, args).ptr);
}
//--------------------------------------------------------------------------------------------------
const CalcTextSize = struct {
    hide_text_after_double_hash: bool = false,
    wrap_width: f32 = -1.0,
};
pub fn calcTextSize(txt: []const u8, args: CalcTextSize) Vec2 {
    var size: Vec2 = undefined;
    cimgui.igCalcTextSize(
        &size,
        txt.ptr,
        txt.ptr + txt.len,
        args.hide_text_after_double_hash,
        args.wrap_width,
    );
    return size;
}
//--------------------------------------------------------------------------------------------------
//
// Widgets: Main
//
//--------------------------------------------------------------------------------------------------
pub fn button(label: [:0]const u8, size: Vec2) bool {
    return cimgui.igButton(label, size);
}
//--------------------------------------------------------------------------------------------------
pub fn smallButton(label: [:0]const u8) bool {
    return cimgui.igSmallButton(label);
}
//--------------------------------------------------------------------------------------------------
const InvisibleButton = struct {
    size: Vec2 = .{},
    flags: ButtonFlags = .{},
};
pub fn invisibleButton(str_id: [:0]const u8, args: InvisibleButton) bool {
    return cimgui.igInvisibleButton(str_id, args.size, @bitCast(args.flags));
}
//--------------------------------------------------------------------------------------------------
pub fn arrowButton(label: [:0]const u8, dir: Direction) bool {
    return cimgui.igArrowButton(label, @intFromEnum(dir));
}
//--------------------------------------------------------------------------------------------------
const Image = struct {
    size: Vec2,
    uv0: Vec2 = .{},
    uv1: Vec2 = .{ .x=1.0, .y=1.0 },
};
pub fn image(user_texture_ref: TextureRef, args: Image) void {
    cimgui.igImage(user_texture_ref, args.size, args.uv0, args.uv1);
}
//--------------------------------------------------------------------------------------------------
const ImageWithBg = struct {
    size: Vec2 = .{},
    uv0: Vec2 = .{},
    uv1: Vec2 = .{ .x=1.0, .y=1.0 },
    bg_col: Vec4 = .{},
    tint_col: Vec4 = .{ .x=1.0, .y=1.0, .z=1.0, .w=1.0 },
};
pub fn imageWithBg(user_texture_ref: TextureRef, args: ImageWithBg) void {
    cimgui.igImageWithBg(user_texture_ref, args.size, args.uv0, args.uv1, args.bg_col, args.tint_col);
}
//--------------------------------------------------------------------------------------------------
const ImageButton = struct {
    size: Vec2 = .{},
    uv0: Vec2 = .{},
    uv1: Vec2 = .{ .x=1.0, .y=1.0 },
    bg_col: Vec4 = .{},
    tint_col: Vec4 = .{ .x=1.0, .y=1.0, .z=1.0, .w=1.0 },
};
pub fn imageButton(str_id: [:0]const u8, user_texture_ref: TextureRef, args: ImageButton) bool {
    return cimgui.igImageButton(str_id, user_texture_ref, args.size, args.uv0, args.uv1, args.bg_col, args.tint_col);
}
//--------------------------------------------------------------------------------------------------
/// `pub fn bullet() void`
pub const bullet = cimgui.igBullet;
//--------------------------------------------------------------------------------------------------
pub fn radioButton(label: [:0]const u8, args: struct {
    active: bool,
}) bool {
    return cimgui.igRadioButton_Bool(label, args.active);
}
//--------------------------------------------------------------------------------------------------
pub fn radioButtonStatePtr(label: [:0]const u8, args: struct {
    v: *i32,
    v_button: i32,
}) bool {
    return cimgui.igRadioButton_IntPtr(label, args.v, args.v_button);
}
//--------------------------------------------------------------------------------------------------
pub fn checkbox(label: [:0]const u8, args: struct {
    v: *bool,
}) bool {
    return cimgui.igCheckbox(label, args.v);
}
//--------------------------------------------------------------------------------------------------
pub fn checkboxBits(label: [:0]const u8, args: struct {
    bits: *u32,
    bits_value: u32,
}) bool {
    return cimgui.igCheckboxFlags_UintPtr(label, args.bits, args.bits_value);
}
//--------------------------------------------------------------------------------------------------
const ProgressBar = struct {
    fraction: f32,
    size: Vec2 = .{ .x = -f32_min },
    overlay: ?[:0]const u8 = null,
};
pub fn progressBar(args: ProgressBar) void {
    cimgui.igProgressBar(args.fraction, args.size, if (args.overlay) |o| o else null);
}
//--------------------------------------------------------------------------------------------------
pub const textLink = cimgui.igTextLink;

pub const textLinkOpenURL = cimgui.igTextLinkOpenURL;
//--------------------------------------------------------------------------------------------------
const PlotArgs = struct {
    v: [*]f32,
    v_count: c_int,
    v_offset: c_int = 0,
    overlay: ?[:0]const u8 = null,
    scale_min: f32 = f32_max,
    scale_max: f32 = f32_max,
    graph_size: Vec2 = .{},
    stride: c_int = @sizeOf(f32),
};
pub fn plotLines(label: [*:0]const u8, args: PlotArgs) void {
    cimgui.igPlotLines_FloatPtr(
        label,
        args.v,
        args.v_count,
        args.v_offset,
        if (args.overlay) |o| o else null,
        args.scale_min,
        args.scale_max,
        args.graph_size,
        args.stride,
    );
}

pub fn plotHistogram(label: [*:0]const u8, args: PlotArgs) void {
    cimgui.igPlotHistogram_FloatPtr(
        label,
        args.v,
        args.v_count,
        args.v_offset,
        if (args.overlay) |o| o else null,
        args.scale_min,
        args.scale_max,
        args.graph_size,
        args.stride,
    );
}

//--------------------------------------------------------------------------------------------------
//
// Widgets: Combo Box
//
//--------------------------------------------------------------------------------------------------
pub fn combo(label: [:0]const u8, args: struct {
    current_item: *i32,
    items_separated_by_zeros: [:0]const u8,
    popup_max_height_in_items: i32 = -1,
}) bool {
    return cimgui.igCombo_Str(
        label,
        args.current_item,
        args.items_separated_by_zeros,
        args.popup_max_height_in_items,
    );
}
/// creates a combo box directly from a pointer to an enum value using zig's
/// comptime mechanics to infer the items for the list at compile time
pub fn comboFromEnum(
    label: [:0]const u8,
    /// must be a pointer to an enum value (var my_enum: *FoodKinds = .Banana)
    /// that is backed by some kind of integer that can safely cast into an
    /// i32 (the underlying imgui restriction)
    current_item: anytype,
) bool {
    const EnumType = @TypeOf(current_item.*);
    const enum_type_info = getTypeInfo: {
        switch (@typeInfo(EnumType)) {
            .optional => |optional_type_info| switch (@typeInfo(optional_type_info.child)) {
                .@"enum" => |enum_type_info| break :getTypeInfo enum_type_info,
                else => {},
            },
            .@"enum" => |enum_type_info| break :getTypeInfo enum_type_info,
            else => {},
        }
        @compileError("Error: current_item must be a pointer-to-an-enum, not a " ++ @TypeOf(EnumType));
    };

    const FieldNameIndex = std.meta.Tuple(&.{ []const u8, i32 });
    comptime var item_names: [:0]const u8 = "";
    comptime var field_name_to_index_list: [enum_type_info.fields.len]FieldNameIndex = undefined;
    comptime var index_to_enum: [enum_type_info.fields.len]EnumType = undefined;

    comptime {
        for (enum_type_info.fields, 0..) |f, i| {
            item_names = item_names ++ f.name ++ "\x00";
            const e: EnumType = @enumFromInt(f.value);
            field_name_to_index_list[i] = .{ f.name, @intCast(i) };
            index_to_enum[i] = e;
        }
    }

    const field_name_to_index = std.StaticStringMap(i32).initComptime(&field_name_to_index_list);

    var item: i32 =
        switch (@typeInfo(EnumType)) {
            .optional => if (current_item.*) |tag| field_name_to_index.get(@tagName(tag)) orelse -1 else -1,
            .@"enum" => field_name_to_index.get(@tagName(current_item.*)) orelse -1,
            else => unreachable,
        };

    const result = combo(label, .{
        .items_separated_by_zeros = item_names,
        .current_item = &item,
    });

    if (item > -1) {
        current_item.* = index_to_enum[@intCast(item)];
    }

    return result;
}
// extern fn zguiCombo(
//     label: [*:0]const u8,
//     current_item: *c_int,
//     items_separated_by_zeros: [*:0]const u8,
//     popup_max_height_in_items: c_int,
// ) bool;
//--------------------------------------------------------------------------------------------------
pub const ComboFlags = packed struct(c_int) {
    popup_align_left: bool = false,
    height_small: bool = false,
    height_regular: bool = false,
    height_large: bool = false,
    height_largest: bool = false,
    no_arrow_button: bool = false,
    no_preview: bool = false,
    width_fit_preview: bool = false,
    _padding: u24 = 0,
};
//--------------------------------------------------------------------------------------------------
const BeginCombo = struct {
    preview_value: [*:0]const u8,
    flags: ComboFlags = .{},
};
pub fn beginCombo(label: [:0]const u8, args: BeginCombo) bool {
    return cimgui.igBeginCombo(label, args.preview_value, @bitCast(args.flags));
}
//--------------------------------------------------------------------------------------------------
/// `pub fn endCombo() void`
pub const endCombo = cimgui.igEndCombo;
//--------------------------------------------------------------------------------------------------
//
// Widgets: Drag Sliders
//
//--------------------------------------------------------------------------------------------------
fn DragFloatGen(comptime T: type) type {
    return struct {
        v: *T,
        speed: f32 = 1.0,
        min: f32 = 0.0,
        max: f32 = 0.0,
        cfmt: [:0]const u8 = "%.3f",
        flags: SliderFlags = .{},
    };
}
//--------------------------------------------------------------------------------------------------
const DragFloat = DragFloatGen(f32);
pub fn dragFloat(label: [:0]const u8, args: DragFloat) bool {
    return cimgui.igDragFloat(
        label,
        args.v,
        args.speed,
        args.min,
        args.max,
        args.cfmt,
        @bitCast(args.flags),
    );
}
//--------------------------------------------------------------------------------------------------
const DragFloat2 = DragFloatGen(Vec2);
pub fn dragFloat2(label: [:0]const u8, args: DragFloat2) bool {
    return cimgui.igDragFloat2(label, @ptrCast(args.v), args.speed, args.min, args.max, args.cfmt, @bitCast(args.flags));
}
//--------------------------------------------------------------------------------------------------
const DragFloat3 = DragFloatGen([3]f32);
pub fn dragFloat3(label: [:0]const u8, args: DragFloat3) bool {
    return cimgui.igDragFloat3(label, @ptrCast(args.v), args.speed, args.min, args.max, args.cfmt, @bitCast(args.flags));
}
//--------------------------------------------------------------------------------------------------
const DragFloat4 = DragFloatGen(Vec4);
pub fn dragFloat4(label: [:0]const u8, args: DragFloat4) bool {
    return cimgui.igDragFloat4(label, @ptrCast(args.v), args.speed, args.min, args.max, args.cfmt, @bitCast(args.flags));
}
//--------------------------------------------------------------------------------------------------
const DragFloatRange2 = struct {
    current_min: *f32,
    current_max: *f32,
    speed: f32 = 1.0,
    min: f32 = 0.0,
    max: f32 = 0.0,
    cfmt: [:0]const u8 = "%.3f",
    cfmt_max: ?[:0]const u8 = null,
    flags: SliderFlags = .{},
};
pub fn dragFloatRange2(label: [:0]const u8, args: DragFloatRange2) bool {
    return cimgui.igDragFloatRange2(
        label,
        args.current_min,
        args.current_max,
        args.speed,
        args.min,
        args.max,
        args.cfmt,
        if (args.cfmt_max) |fm| fm else null,
        @bitCast(args.flags),
    );
}
//--------------------------------------------------------------------------------------------------
fn DragIntGen(comptime T: type) type {
    return struct {
        v: *T,
        speed: f32 = 1.0,
        min: i32 = 0.0,
        max: i32 = 0.0,
        cfmt: [:0]const u8 = "%d",
        flags: SliderFlags = .{},
    };
}
//--------------------------------------------------------------------------------------------------
const DragInt = DragIntGen(i32);
pub fn dragInt(label: [:0]const u8, args: DragInt) bool {
    return cimgui.igDragInt(label, args.v, args.speed, args.min, args.max, args.cfmt, @bitCast(args.flags));
}
//--------------------------------------------------------------------------------------------------
const DragInt2 = DragIntGen([2]i32);
pub fn dragInt2(label: [:0]const u8, args: DragInt2) bool {
    return cimgui.igDragInt2(label, args.v, args.speed, args.min, args.max, args.cfmt, @bitCast(args.flags));
}
//--------------------------------------------------------------------------------------------------
const DragInt3 = DragIntGen([3]i32);
pub fn dragInt3(label: [:0]const u8, args: DragInt3) bool {
    return cimgui.igDragInt3(label, args.v, args.speed, args.min, args.max, args.cfmt, @bitCast(args.flags));
}
//--------------------------------------------------------------------------------------------------
const DragInt4 = DragIntGen([4]i32);
pub fn dragInt4(label: [:0]const u8, args: DragInt4) bool {
    return cimgui.igDragInt4(label, args.v, args.speed, args.min, args.max, args.cfmt, @bitCast(args.flags));
}
//--------------------------------------------------------------------------------------------------
const DragIntRange2 = struct {
    current_min: *i32,
    current_max: *i32,
    speed: f32 = 1.0,
    min: i32 = 0.0,
    max: i32 = 0.0,
    cfmt: [:0]const u8 = "%d",
    cfmt_max: ?[:0]const u8 = null,
    flags: SliderFlags = .{},
};
pub fn dragIntRange2(label: [:0]const u8, args: DragIntRange2) bool {
    return cimgui.igDragIntRange2(
        label,
        args.current_min,
        args.current_max,
        args.speed,
        args.min,
        args.max,
        args.cfmt,
        if (args.cfmt_max) |fm| fm else null,
        @bitCast(args.flags),
    );
}
//--------------------------------------------------------------------------------------------------
fn DragScalarGen(comptime T: type) type {
    return struct {
        v: *T,
        speed: f32 = 1.0,
        min: ?T = null,
        max: ?T = null,
        cfmt: ?[:0]const u8 = null,
        flags: SliderFlags = .{},
    };
}
pub fn dragScalar(label: [:0]const u8, comptime T: type, args: DragScalarGen(T)) bool {
    return cimgui.igDragScalar(
        label,
        typeToDataTypeEnum(T),
        args.v,
        args.speed,
        if (args.min) |vm| &vm else null,
        if (args.max) |vm| &vm else null,
        if (args.cfmt) |fmt| fmt else null,
        @bitCast(args.flags),
    );
}
//--------------------------------------------------------------------------------------------------
fn DragScalarNGen(comptime T: type) type {
    const ScalarType = @typeInfo(T).array.child;
    return struct {
        v: *T,
        speed: f32 = 1.0,
        min: ?ScalarType = null,
        max: ?ScalarType = null,
        cfmt: ?[:0]const u8 = null,
        flags: SliderFlags = .{},
    };
}
pub fn dragScalarN(label: [:0]const u8, comptime T: type, args: DragScalarNGen(T)) bool {
    const ScalarType = @typeInfo(T).array.child;
    const components = @typeInfo(T).array.len;
    return cimgui.igDragScalarN(
        label,
        typeToDataTypeEnum(ScalarType),
        args.v,
        components,
        args.speed,
        if (args.min) |vm| &vm else null,
        if (args.max) |vm| &vm else null,
        if (args.cfmt) |fmt| fmt else null,
        @bitCast(args.flags),
    );
}
//--------------------------------------------------------------------------------------------------
//
// Widgets: Regular Sliders
//
//--------------------------------------------------------------------------------------------------
fn SliderFloatGen(comptime T: type) type {
    return struct {
        v: *T,
        min: f32,
        max: f32,
        cfmt: [:0]const u8 = "%.3f",
        flags: SliderFlags = .{},
    };
}

pub fn sliderFloat(label: [:0]const u8, args: SliderFloatGen(f32)) bool {
    return cimgui.igSliderFloat(label, args.v, args.min, args.max, args.cfmt, @bitCast(args.flags));
}

pub fn sliderFloat2(label: [:0]const u8, args: SliderFloatGen(Vec2)) bool {
    return cimgui.igSliderFloat2(label, @ptrCast(args.v), args.min, args.max, args.cfmt, @bitCast(args.flags));
}

pub fn sliderFloat3(label: [:0]const u8, args: SliderFloatGen([3]f32)) bool {
    return cimgui.igSliderFloat3(label, args.v, args.min, args.max, args.cfmt, @bitCast(args.flags));
}

pub fn sliderFloat4(label: [:0]const u8, args: SliderFloatGen(Vec4)) bool {
    return cimgui.igSliderFloat4(label, @ptrCast(args.v), args.min, args.max, args.cfmt, @bitCast(args.flags));
}

//--------------------------------------------------------------------------------------------------
fn SliderIntGen(comptime T: type) type {
    return struct {
        v: *T,
        min: i32,
        max: i32,
        cfmt: [:0]const u8 = "%d",
        flags: SliderFlags = .{},
    };
}

pub fn sliderInt(label: [:0]const u8, args: SliderIntGen(i32)) bool {
    return cimgui.igSliderInt(label, args.v, args.min, args.max, args.cfmt, @bitCast(args.flags));
}

pub fn sliderInt2(label: [:0]const u8, args: SliderIntGen([2]i32)) bool {
    return cimgui.igSliderInt2(label, args.v, args.min, args.max, args.cfmt, @bitCast(args.flags));
}

pub fn sliderInt3(label: [:0]const u8, args: SliderIntGen([3]i32)) bool {
    return cimgui.igSliderInt3(label, args.v, args.min, args.max, args.cfmt, @bitCast(args.flags));
}

pub fn sliderInt4(label: [:0]const u8, args: SliderIntGen([4]i32)) bool {
    return cimgui.igSliderInt4(label, args.v, args.min, args.max, args.cfmt, @bitCast(args.flags));
}

//--------------------------------------------------------------------------------------------------
fn SliderScalarGen(comptime T: type) type {
    return struct {
        v: *T,
        min: T,
        max: T,
        cfmt: ?[:0]const u8 = null,
        flags: SliderFlags = .{},
    };
}
pub fn sliderScalar(label: [:0]const u8, comptime T: type, args: SliderScalarGen(T)) bool {
    return cimgui.igSliderScalar(
        label,
        typeToDataTypeEnum(T),
        args.v,
        &args.min,
        &args.max,
        if (args.cfmt) |fmt| fmt else null,
        @bitCast(args.flags),
    );
}

//--------------------------------------------------------------------------------------------------
fn SliderScalarNGen(comptime T: type) type {
    const ScalarType = @typeInfo(T).array.child;
    return struct {
        v: *T,
        min: ScalarType,
        max: ScalarType,
        cfmt: ?[:0]const u8 = null,
        flags: SliderFlags = .{},
    };
}
pub fn sliderScalarN(label: [:0]const u8, comptime T: type, args: SliderScalarNGen(T)) bool {
    const ScalarType = @typeInfo(T).array.child;
    const components = @typeInfo(T).array.len;
    return cimgui.igSliderScalarN(
        label,
        typeToDataTypeEnum(ScalarType),
        args.v,
        components,
        &args.min,
        &args.max,
        if (args.cfmt) |fmt| fmt else null,
        @bitCast(args.flags),
    );
}
//--------------------------------------------------------------------------------------------------
pub fn vsliderFloat(label: [:0]const u8, args: struct {
    size: Vec2 = .{},
    v: *f32,
    min: f32,
    max: f32,
    cfmt: [:0]const u8 = "%.3f",
    flags: SliderFlags = .{},
}) bool {
    return cimgui.igVSliderFloat(
        label,
        args.size,
        args.v,
        args.min,
        args.max,
        args.cfmt,
        @bitCast(args.flags),
    );
}
//--------------------------------------------------------------------------------------------------
pub fn vsliderInt(label: [:0]const u8, args: struct {
    size: Vec2 = .{},
    v: *i32,
    min: i32,
    max: i32,
    cfmt: [:0]const u8 = "%d",
    flags: SliderFlags = .{},
}) bool {
    return cimgui.igVSliderInt(label, args.size, args.v, args.min, args.max, args.cfmt, @bitCast(args.flags));
}
//--------------------------------------------------------------------------------------------------
fn VSliderScalarGen(comptime T: type) type {
    return struct {
        w: f32,
        h: f32,
        v: *T,
        min: T,
        max: T,
        cfmt: ?[:0]const u8 = null,
        flags: SliderFlags = .{},
    };
}
pub fn vsliderScalar(label: [:0]const u8, comptime T: type, args: VSliderScalarGen(T)) bool {
    return cimgui.igVSliderScalar(
        label,
        args.w,
        args.h,
        typeToDataTypeEnum(T),
        args.v,
        &args.min,
        &args.max,
        if (args.cfmt) |fmt| fmt else null,
        @bitCast(args.flags),
    );
}
const SliderAngle = struct {
    vrad: *f32,
    deg_min: f32 = -360.0,
    deg_max: f32 = 360.0,
    cfmt: [:0]const u8 = "%.0f deg",
    flags: SliderFlags = .{},
};
pub fn sliderAngle(label: [:0]const u8, args: SliderAngle) bool {
    return cimgui.igSliderAngle(
        label,
        args.vrad,
        args.deg_min,
        args.deg_max,
        args.cfmt,
        @bitCast(args.flags),
    );
}
//--------------------------------------------------------------------------------------------------
//
// Widgets: Input with Keyboard
//
//--------------------------------------------------------------------------------------------------
pub const InputTextFlags = packed struct(c_int) {
    chars_decimal: bool = false,
    chars_hexadecimal: bool = false,
    chars_scientific: bool = false,
    chars_uppercase: bool = false,
    chars_no_blank: bool = false,
    allow_tab_input: bool = false,
    enter_returns_true: bool = false,
    escape_clears_all: bool = false,
    ctrl_enter_for_new_line: bool = false,
    read_only: bool = false,
    password: bool = false,
    always_overwrite: bool = false,
    auto_select_all: bool = false,
    parse_empty_ref_val: bool = false,
    display_empty_ref_val: bool = false,
    no_horizontal_scroll: bool = false,
    no_undo_redo: bool = false,
    elide_left: bool = false,
    callback_completion: bool = false,
    callback_history: bool = false,
    callback_always: bool = false,
    callback_char_filter: bool = false,
    callback_resize: bool = false,
    callback_edit: bool = false,
    _padding: u8 = 0,
};
//--------------------------------------------------------------------------------------------------
pub const InputTextCallbackData = extern struct {
    data: *cimgui.ImGuiInputTextCallbackData,

    pub fn init() InputTextCallbackData{
        return .{.data = cimgui.ImGuiInputTextCallbackData_ImGuiInputTextCallbackData() };
    }

    pub fn deleteChars(self: InputTextCallbackData, pos: i32, bytes_count: i32) void{
        cimgui.ImGuiInputTextCallbackData_DeleteChars(self.data, pos, bytes_count);
    }

    pub fn insertChars(self: *InputTextCallbackData, pos: i32, txt: []const u8) void {
        cimgui.ImGuiInputTextCallbackData_InsertChars(self.data, pos, txt.ptr, txt.ptr + txt.len);
    }

    pub fn selectAll(self: *InputTextCallbackData) void {
        self.data.SelectionStart = 0;
        self.data.SelectionEnd = self.data.BufTextLen;
    }

    pub fn clearSelection(self: *InputTextCallbackData) void {
        self.data.SelectionStart = self.data.BufTextLen;
        self.data.SelectionEnd = self.data.BufTextLen;
    }

    pub fn hasSelection(self: InputTextCallbackData) bool {
        return self.data.SelectionStart != self.data.SelectionEnd;
    }
};

pub const InputTextCallback = cimgui.ImGuiInputTextCallback;
//--------------------------------------------------------------------------------------------------
pub fn inputText(label: [:0]const u8, args: struct {
    buf: [:0]u8,
    flags: InputTextFlags = .{},
    callback: ?InputTextCallback = null,
    user_data: ?*anyopaque = null,
}) bool {
    return cimgui.igInputText(
        label,
        args.buf.ptr,
        args.buf.len + 1, // + 1 for sentinel
        @bitCast(args.flags),
        if (args.callback) |cb| cb else null,
        args.user_data,
    );
}
//--------------------------------------------------------------------------------------------------
pub fn inputTextMultiline(label: [:0]const u8, args: struct {
    buf: [:0]u8,
    size: Vec2 = .{},
    flags: InputTextFlags = .{},
    callback: ?InputTextCallback = null,
    user_data: ?*anyopaque = null,
}) bool {
    return cimgui.igInputTextMultiline(
        label,
        args.buf.ptr,
        args.buf.len + 1, // + 1 for sentinel
        args.size,
        @bitCast(args.flags),
        if (args.callback) |cb| cb else null,
        args.user_data,
    );
}

//--------------------------------------------------------------------------------------------------
pub fn inputTextWithHint(label: [:0]const u8, args: struct {
    hint: [:0]const u8,
    buf: [:0]u8,
    flags: InputTextFlags = .{},
    callback: ?InputTextCallback = null,
    user_data: ?*anyopaque = null,
}) bool {
    return cimgui.igInputTextWithHint(
        label,
        args.hint,
        args.buf.ptr,
        args.buf.len + 1, // + 1 for sentinel
        @bitCast(args.flags),
        if (args.callback) |cb| cb else null,
        args.user_data,
    );
}

//--------------------------------------------------------------------------------------------------
pub fn inputFloat(label: [:0]const u8, args: struct {
    v: *f32,
    step: f32 = 0.0,
    step_fast: f32 = 0.0,
    cfmt: [:0]const u8 = "%.3f",
    flags: InputTextFlags = .{},
}) bool {
    return cimgui.igInputFloat(
        label,
        args.v,
        args.step,
        args.step_fast,
        args.cfmt,
        @bitCast(args.flags),
    );
}

//--------------------------------------------------------------------------------------------------
fn InputFloatGen(comptime T: type) type {
    return struct {
        v: *T,
        cfmt: [:0]const u8 = "%.3f",
        flags: InputTextFlags = .{},
    };
}
pub fn inputFloat2(label: [:0]const u8, args: InputFloatGen(Vec2)) bool {
    return cimgui.igInputFloat2(label, @ptrCast(args.v), args.cfmt, @bitCast(args.flags));
}

pub fn inputFloat3(label: [:0]const u8, args: InputFloatGen([3]f32)) bool {
    return cimgui.igInputFloat3(label, args.v, args.cfmt, @bitCast(args.flags));
}

pub fn inputFloat4(label: [:0]const u8, args: InputFloatGen(Vec4)) bool {
    return cimgui.igInputFloat4(label, @ptrCast(args.v), args.cfmt, @bitCast(args.flags));
}

//--------------------------------------------------------------------------------------------------
pub fn inputInt(label: [:0]const u8, args: struct {
    v: *i32,
    step: i32 = 1,
    step_fast: i32 = 100,
    flags: InputTextFlags = .{},
}) bool {
    return cimgui.igInputInt(label, args.v, args.step, args.step_fast, @bitCast(args.flags));
}

//--------------------------------------------------------------------------------------------------
fn InputIntGen(comptime T: type) type {
    return struct {
        v: *T,
        flags: InputTextFlags = .{},
    };
}
pub fn inputInt2(label: [:0]const u8, args: InputIntGen([2]i32)) bool {
    return cimgui.igInputInt2(label, args.v, @bitCast(args.flags));
}

pub fn inputInt3(label: [:0]const u8, args: InputIntGen([3]i32)) bool {
    return cimgui.igInputInt3(label, args.v, @bitCast(args.flags));
}

pub fn inputInt4(label: [:0]const u8, args: InputIntGen([4]i32)) bool {
    return cimgui.igInputInt4(label, args.v, @bitCast(args.flags));
}

//--------------------------------------------------------------------------------------------------
const InputDouble = struct {
    v: *f64,
    step: f64 = 0.0,
    step_fast: f64 = 0.0,
    cfmt: [:0]const u8 = "%.6f",
    flags: InputTextFlags = .{},
};
pub fn inputDouble(label: [:0]const u8, args: InputDouble) bool {
    return cimgui.igInputDouble(label, args.v, args.step, args.step_fast, args.cfmt, @bitCast(args.flags));
}
//--------------------------------------------------------------------------------------------------
fn InputScalarGen(comptime T: type) type {
    return struct {
        v: *T,
        step: ?T = null,
        step_fast: ?T = null,
        cfmt: ?[:0]const u8 = null,
        flags: InputTextFlags = .{},
    };
}
pub fn inputScalar(label: [:0]const u8, comptime T: type, args: InputScalarGen(T)) bool {
    return cimgui.igInputScalar(
        label,
        typeToDataTypeEnum(T),
        args.v,
        if (args.step) |s| &s else null,
        if (args.step_fast) |sf| &sf else null,
        if (args.cfmt) |fmt| fmt else null,
        args.flags,
    );
}
//--------------------------------------------------------------------------------------------------
fn InputScalarNGen(comptime T: type) type {
    const ScalarType = @typeInfo(T).array.child;
    return struct {
        v: *T,
        step: ?ScalarType = null,
        step_fast: ?ScalarType = null,
        cfmt: ?[:0]const u8 = null,
        flags: InputTextFlags = .{},
    };
}
pub fn inputScalarN(label: [:0]const u8, comptime T: type, args: InputScalarNGen(T)) bool {
    const ScalarType = @typeInfo(T).array.child;
    const components = @typeInfo(T).array.len;
    return cimgui.igInputScalarN(
        label,
        typeToDataTypeEnum(ScalarType),
        args.v,
        components,
        if (args.step) |s| &s else null,
        if (args.step_fast) |sf| &sf else null,
        if (args.cfmt) |fmt| fmt else null,
        args.flags,
    );
}
//--------------------------------------------------------------------------------------------------
//
// Widgets: Color Editor/Picker
//
//--------------------------------------------------------------------------------------------------
pub const ColorEditFlags = packed struct(c_int) {
    _reserved0: bool = false,
    no_alpha: bool = false,
    no_picker: bool = false,
    no_options: bool = false,
    no_small_preview: bool = false,
    no_inputs: bool = false,
    no_tooltip: bool = false,
    no_label: bool = false,
    no_side_preview: bool = false,
    no_drag_drop: bool = false,
    no_border: bool = false,

    _reserved1: bool = false,
    _reserved2: bool = false,
    _reserved3: bool = false,
    _reserved4: bool = false,
    _reserved5: bool = false,

    alpha_bar: bool = false,
    alpha_preview: bool = false,
    alpha_preview_half: bool = false,
    hdr: bool = false,
    display_rgb: bool = false,
    display_hsv: bool = false,
    display_hex: bool = false,
    uint8: bool = false,
    float: bool = false,
    picker_hue_bar: bool = false,
    picker_hue_wheel: bool = false,
    input_rgb: bool = false,
    input_hsv: bool = false,

    _padding: u3 = 0,

    pub const default_options = ColorEditFlags{
        .uint8 = true,
        .display_rgb = true,
        .input_rgb = true,
        .picker_hue_bar = true,
    };
};
//--------------------------------------------------------------------------------------------------
const ColorEdit3 = struct {
    col: *[3]f32,
    flags: ColorEditFlags = .{},
};
pub fn colorEdit3(label: [:0]const u8, args: ColorEdit3) bool {
    return cimgui.igColorEdit3(label, @ptrCast(args.col), @bitCast(args.flags));
}
//--------------------------------------------------------------------------------------------------
const ColorEdit4 = struct {
    col: *Vec4,
    flags: ColorEditFlags = .{},
};
pub fn colorEdit4(label: [:0]const u8, args: ColorEdit4) bool {
    return cimgui.igColorEdit4(label, @ptrCast(args.col), @bitCast(args.flags));
}
//--------------------------------------------------------------------------------------------------
const ColorPicker3 = struct {
    col: *[3]f32,
    flags: ColorEditFlags = .{},
};
pub fn colorPicker3(label: [:0]const u8, args: ColorPicker3) bool {
    return cimgui.igColorPicker3(label, args.col, @bitCast(args.flags));
}
//--------------------------------------------------------------------------------------------------
const ColorPicker4 = struct {
    col: *Vec4,
    flags: ColorEditFlags = .{},
    ref_col: ?[*]const f32 = null,
};
pub fn colorPicker4(label: [:0]const u8, args: ColorPicker4) bool {
    return cimgui.igColorPicker4(
        label,
        @ptrCast(args.col),
        @bitCast(args.flags),
        if (args.ref_col) |rc| rc else null,
    );
}

//--------------------------------------------------------------------------------------------------
const ColorButton = struct {
    col: Vec4,
    flags: ColorEditFlags = .{},
    size: Vec2 = .{},
};
pub fn colorButton(desc_id: [:0]const u8, args: ColorButton) bool {
    return cimgui.igColorButton(desc_id, args.col, @bitCast(args.flags), args.size);
}

//--------------------------------------------------------------------------------------------------
//
// Widgets: Trees
//
//--------------------------------------------------------------------------------------------------
pub const TreeNodeFlags = packed struct(c_int) {
    selected: bool = false,
    framed: bool = false,
    allow_overlap: bool = false,
    no_tree_push_on_open: bool = false,
    no_auto_open_on_log: bool = false,
    default_open: bool = false,
    open_on_double_click: bool = false,
    open_on_arrow: bool = false,
    leaf: bool = false,
    bullet: bool = false,
    frame_padding: bool = false,
    span_avail_width: bool = false,
    span_full_width: bool = false,
    span_label_width: bool = false,
    span_all_columns: bool = false,
    label_span_all_columns: bool = false,
    _padding0: u1 = 0,
    nav_left_jumps_to_parent: bool = false,
    draw_lines_none: bool = false,
    draw_lines_full: bool = false,
    draw_lines_to_nodes: bool = false,
    _padding1: u11 = 0,

    pub const collapsing_header = TreeNodeFlags{
        .framed = true,
        .no_tree_push_on_open = true,
        .no_auto_open_on_log = true,
    };
};
//--------------------------------------------------------------------------------------------------
pub fn treeNode(label: [:0]const u8) bool {
    return cimgui.igTreeNode_Str(label);
}
pub fn treeNodeFlags(label: [:0]const u8, flags: TreeNodeFlags) bool {
    return cimgui.igTreeNodeEx_Str(label, @bitCast(flags));
}
//--------------------------------------------------------------------------------------------------
pub fn treeNodeStrId(str_id: [:0]const u8, comptime fmt: []const u8, args: anytype) bool {
    return cimgui.igTreeNodeStrId(str_id, "%s", formatZ(fmt, args).ptr);
}
pub fn treeNodeStrIdFlags(
    str_id: [:0]const u8,
    flags: TreeNodeFlags,
    comptime fmt: []const u8,
    args: anytype,
) bool {
    return cimgui.igTreeNodeStrIdFlags(str_id, flags, "%s", formatZ(fmt, args).ptr);
}
//--------------------------------------------------------------------------------------------------
pub fn treeNodePtrId(ptr_id: *const anyopaque, comptime fmt: []const u8, args: anytype) bool {
    return cimgui.igTreeNodePtrId(ptr_id, "%s", formatZ(fmt, args).ptr);
}
pub fn treeNodePtrIdFlags(
    ptr_id: *const anyopaque,
    flags: TreeNodeFlags,
    comptime fmt: []const u8,
    args: anytype,
) bool {
    return cimgui.igTreeNodePtrIdFlags(ptr_id, flags, "%s", formatZ(fmt, args).ptr);
}
//--------------------------------------------------------------------------------------------------
pub fn treePushStrId(str_id: [:0]const u8) void {
    cimgui.igTreePush_Str(str_id);
}
pub fn treePushPtrId(ptr_id: *const anyopaque) void {
    cimgui.igTreePush_Ptr(ptr_id);
}
//--------------------------------------------------------------------------------------------------
/// `pub fn treePop() void`
pub const treePop = cimgui.igTreePop;
//--------------------------------------------------------------------------------------------------
pub const getTreeNodeToLabelSpacing = cimgui.igGetTreeNodeToLabelSpacing;
//--------------------------------------------------------------------------------------------------
const CollapsingHeaderStatePtr = struct {
    pvisible: *bool,
    flags: TreeNodeFlags = .{},
};
pub fn collapsingHeader(label: [:0]const u8, flags: TreeNodeFlags) bool {
    return cimgui.igCollapsingHeader_TreeNodeFlags(label, @bitCast(flags));
}
pub fn collapsingHeaderStatePtr(label: [:0]const u8, args: CollapsingHeaderStatePtr) bool {
    return cimgui.igCollapsingHeader_BoolPtr(label, args.pvisible, @bitCast(args.flags));
}
//--------------------------------------------------------------------------------------------------
const SetNextItemOpen = struct {
    is_open: bool,
    cond: Condition = .none,
};
pub fn setNextItemOpen(args: SetNextItemOpen) void {
    cimgui.igSetNextItemOpen(args.is_open, @intFromEnum(args.cond));
}
//--------------------------------------------------------------------------------------------------
//
// Selectables
//
//--------------------------------------------------------------------------------------------------
pub const SelectableFlags = packed struct(c_int) {
    no_auto_close_popups: bool = false,
    span_all_columns: bool = false,
    allow_double_click: bool = false,
    disabled: bool = false,
    allow_overlap: bool = false,
    highlight: bool = false,
    _padding: u26 = 0,
};
//--------------------------------------------------------------------------------------------------
const Selectable = struct {
    selected: bool = false,
    flags: SelectableFlags = .{},
    size: Vec2 = .{},
};
pub fn selectable(label: [:0]const u8, args: Selectable) bool {
    return cimgui.igSelectable_Bool(label, args.selected, @bitCast(args.flags), args.size);
}
//--------------------------------------------------------------------------------------------------
const SelectableStatePtr = struct {
    pselected: *bool,
    flags: SelectableFlags = .{},
    size: Vec2 = .{},
};
pub fn selectableStatePtr(label: [:0]const u8, args: SelectableStatePtr) bool {
    return cimgui.igSelectable_BoolPtr(label, args.pselected, @bitCast(args.flags), args.size);
}
//--------------------------------------------------------------------------------------------------
//
// Widgets: List Boxes
//
//--------------------------------------------------------------------------------------------------
pub const beginListBox = cimgui.igBeginListBox;
/// `pub fn endListBox() void`
pub const endListBox = cimgui.igEndListBox;
pub const ListBox = struct {
    current_item: *i32,
    items: []const [*:0]const u8,
    height_in_items: i32 = -1,
};
pub fn listBox(label: [*:0]const u8, args: ListBox) bool {
    return cimgui.igListBox_Str_arr(label, args.current_item, args.items.ptr, @intCast(args.items.len), args.height_in_items);
}
//--------------------------------------------------------------------------------------------------
//
// Widgets: Tables
//
//--------------------------------------------------------------------------------------------------
pub const TableBorderFlags = packed struct(u4) {
    inner_h: bool = false,
    outer_h: bool = false,
    inner_v: bool = false,
    outer_v: bool = false,

    pub const h = TableBorderFlags{
        .inner_h = true,
        .outer_h = true,
    }; // Draw horizontal borders.
    pub const v = TableBorderFlags{
        .inner_v = true,
        .outer_v = true,
    }; // Draw vertical borders.
    pub const inner = TableBorderFlags{
        .inner_v = true,
        .inner_h = true,
    }; // Draw inner borders.
    pub const outer = TableBorderFlags{
        .outer_v = true,
        .outer_h = true,
    }; // Draw outer borders.
    pub const all = TableBorderFlags{
        .inner_v = true,
        .inner_h = true,
        .outer_v = true,
        .outer_h = true,
    }; // Draw all borders.
};
pub const TableFlags = packed struct(c_int) {
    resizable: bool = false,
    reorderable: bool = false,
    hideable: bool = false,
    sortable: bool = false,
    no_saved_settings: bool = false,
    context_menu_in_body: bool = false,
    row_bg: bool = false,
    borders: TableBorderFlags = .{},
    no_borders_in_body: bool = false,
    no_borders_in_body_until_resize: bool = false,

    // Sizing Policy
    sizing: enum(u3) {
        none = 0,
        fixed_fit = 1,
        fixed_same = 2,
        stretch_prop = 3,
        stretch_same = 4,
    } = .none,

    // Sizing Extra Options
    no_host_extend_x: bool = false,
    no_host_extend_y: bool = false,
    no_keep_columns_visible: bool = false,
    precise_widths: bool = false,

    // Clipping
    no_clip: bool = false,

    // Padding
    pad_outer_x: bool = false,
    no_pad_outer_x: bool = false,
    no_pad_inner_x: bool = false,

    // Scrolling
    scroll_x: bool = false,
    scroll_y: bool = false,

    // Sorting
    sort_multi: bool = false,
    sort_tristate: bool = false,

    // Miscellaneous
    highlight_hovered_column: bool = false,

    _padding: u3 = 0,
};

pub const TableRowFlags = packed struct(c_int) {
    headers: bool = false,

    _padding: u31 = 0,
};

pub const TableColumnFlags = packed struct(c_int) {
    // Input configuration flags
    disabled: bool = false,
    default_hide: bool = false,
    default_sort: bool = false,
    width_stretch: bool = false,
    width_fixed: bool = false,
    no_resize: bool = false,
    no_reorder: bool = false,
    no_hide: bool = false,
    no_clip: bool = false,
    no_sort: bool = false,
    no_sort_ascending: bool = false,
    no_sort_descending: bool = false,
    no_header_label: bool = false,
    no_header_width: bool = false,
    prefer_sort_ascending: bool = false,
    prefer_sort_descending: bool = false,
    indent_enable: bool = false,
    indent_disable: bool = false,

    _padding0: u6 = 0,

    // Output status flags, read-only via TableGetColumnFlags()
    is_enabled: bool = false,
    is_visible: bool = false,
    is_sorted: bool = false,
    is_hovered: bool = false,

    _padding1: u4 = 0,
};

pub const TableColumnSortSpecs = extern struct {
    user_id: Ident,
    index: i16,
    sort_order: i16,
    sort_direction: enum(u8) {
        none = 0,
        ascending = 1, // Ascending = 0->9, A->Z etc.
        descending = 2, // Descending = 9->0, Z->A etc.
    },
};

pub const TableSortSpecs = *extern struct {
    specs: [*]TableColumnSortSpecs,
    count: c_int,
    dirty: bool,
};

pub const TableBgTarget = enum(c_int) {
    none = 0,
    row_bg0 = 1,
    row_bg1 = 2,
    cell_bg = 3,
};

pub fn beginTable(name: [:0]const u8, args: struct {
    column: i32,
    flags: TableFlags = .{},
    outer_size: Vec2 = .{},
    inner_width: f32 = 0,
}) bool {
    return cimgui.igBeginTable(name, args.column, @bitCast(args.flags), args.outer_size, args.inner_width);
}

pub fn endTable() void {
    cimgui.igEndTable();
}

pub const TableNextRow = struct {
    row_flags: TableRowFlags = .{},
    min_row_height: f32 = 0,
};
pub fn tableNextRow(args: TableNextRow) void {
    cimgui.igTableNextRow(@bitCast(args.row_flags), args.min_row_height);
}

pub const tableNextColumn = cimgui.igTableNextColumn;

pub const tableSetColumnIndex = cimgui.igTableSetColumnIndex;

pub const TableSetupColumn = struct {
    flags: TableColumnFlags = .{},
    init_width_or_height: f32 = 0,
    user_id: Ident = 0,
};
pub fn tableSetupColumn(label: [:0]const u8, args: TableSetupColumn) void {
    cimgui.igTableSetupColumn(label, @bitCast(args.flags), args.init_width_or_height, args.user_id);
}

pub const tableSetupScrollFreeze = cimgui.igTableSetupScrollFreeze;

pub const tableHeadersRow = cimgui.igTableHeadersRow;

pub fn tableHeader(label: [:0]const u8) void {
    cimgui.igTableHeader(label);
}

pub const tableGetSortSpecs = cimgui.igTableGetSortSpecs;

pub const tableGetColumnCount = cimgui.igTableGetColumnCount;

pub const tableGetColumnIndex = cimgui.igTableGetColumnIndex;

pub const tableGetRowIndex = cimgui.igTableGetRowIndex;

pub const TableGetColumnName = struct {
    column_n: i32 = -1,
};
pub fn tableGetColumnName(args: TableGetColumnName) [*:0]const u8 {
    return cimgui.igTableGetColumnName_Int(args.column_n);
}

pub const TableGetColumnFlags = struct {
    column_n: i32 = -1,
};
pub fn tableGetColumnFlags(args: TableGetColumnFlags) TableColumnFlags {
    return @bitCast(cimgui.igTableGetColumnFlags(args.column_n));
}

pub const tableSetColumnEnabled = cimgui.igTableSetColumnEnabled;

pub const tableGetHoveredColumn = cimgui.igTableGetHoveredColumn;

pub fn tableSetBgColor(args: struct {
    target: TableBgTarget,
    color: u32,
    column_n: i32 = -1,
}) void {
    cimgui.igTableSetBgColor(@intFromEnum(args.target), args.color, args.column_n);
}

pub const Columns = struct {
    count: i32 = 1,
    id: ?[*:0]const u8 = null,
    borders: bool = true,
};
pub fn columns(args: Columns) void {
    cimgui.igColumns(args.count, args.id, args.borders);
}

pub const nextColumn = cimgui.igNextColumn;

pub const getColumnIndex = cimgui.igGetColumnIndex;

pub const getColumnWidth = cimgui.igGetColumnWidth;

pub const setColumnWidth = cimgui.igSetColumnWidth;

pub const getColumnOffset = cimgui.igGetColumnOffset;

pub const setColumnOffset = cimgui.igSetColumnOffset;

pub const getColumnsCount = cimgui.igGetColumnsCount;

//--------------------------------------------------------------------------------------------------
//
// Item/Widgets Utilities and Query Functions
//
//--------------------------------------------------------------------------------------------------
pub fn isItemHovered(flags: HoveredFlags) bool {
    return cimgui.igIsItemHovered(@bitCast(flags));
}
/// `pub fn isItemActive() bool`
pub const isItemActive = cimgui.igIsItemActive;
/// `pub fn isItemFocused() bool`
pub const isItemFocused = cimgui.igIsItemFocused;
pub const MouseButton = enum(i32) {
    left = 0,
    right = 1,
    middle = 2,
};

/// `pub fn isMouseDown(mouse_button: MouseButton) bool`
pub const isMouseDown = cimgui.igIsMouseDown_Nil;
/// `pub fn isMouseClicked(mouse_button: MouseButton, repeat: bool) bool`
pub const isMouseClicked = cimgui.igIsMouseClicked_Bool;
/// `pub fn isMouseReleased(mouse_button: MouseButton) bool`
pub const isMouseReleased = cimgui.igIsMouseReleased_Nil;
/// `pub fn isMouseDoubleClicked(mouse_button: MouseButton) bool`
pub const isMouseDoubleClicked = cimgui.igIsMouseDoubleClicked_Nil;
/// `pub fn getMouseClickedCount(mouse_button: MouseButton) bool`
pub const getMouseClickedCount = cimgui.igGetMouseClickedCount;
pub const isAnyMouseDown = cimgui.igIsAnyMouseDown;
/// `pub fn isMouseDragging(mouse_button: MouseButton, lock_threshold: f32) bool`
pub const isMouseDragging = cimgui.igIsMouseDragging;
/// `pub fn isItemClicked(mouse_button: MouseButton) bool`
pub const isItemClicked = cimgui.igIsItemClicked;
/// `pub fn isItemVisible() bool`
pub const isItemVisible = cimgui.igIsItemVisible;
/// `pub fn isItemEdited() bool`
pub const isItemEdited = cimgui.igIsItemEdited;
/// `pub fn isItemActivated() bool`
pub const isItemActivated = cimgui.igIsItemActivated;
/// `pub fn isItemDeactivated bool`
pub const isItemDeactivated = cimgui.igIsItemDeactivated;
/// `pub fn isItemDeactivatedAfterEdit() bool`
pub const isItemDeactivatedAfterEdit = cimgui.igIsItemDeactivatedAfterEdit;
/// `pub fn isItemToggledOpen() bool`
pub const isItemToggledOpen = cimgui.igIsItemToggledOpen;
/// `pub fn isAnyItemHovered() bool`
pub const isAnyItemHovered = cimgui.igIsAnyItemHovered;
/// `pub fn isAnyItemActive() bool`
pub const isAnyItemActive = cimgui.igIsAnyItemActive;
/// `pub fn isAnyItemFocused() bool`
pub const isAnyItemFocused = cimgui.igIsAnyItemFocused;

pub const isRectVisible = cimgui.igIsRectVisible_Vec2;
//--------------------------------------------------------------------------------------------------
//
// Color Utilities
//
//--------------------------------------------------------------------------------------------------
pub fn colorConvertU32ToFloat4(in: u32) Vec4 {
    var rgba: Vec4 = undefined;
    cimgui.igColorConvertU32ToFloat4(&rgba, in);
    return rgba;
}

pub fn colorConvertU32ToFloat3(in: u32) [3]f32 {
    var rgba: Vec4 = undefined;
    cimgui.igColorConvertU32ToFloat4(&rgba, in);
    return .{ rgba.x, rgba.y, rgba.z };
}

pub fn colorConvertFloat4ToU32(in: Vec4) u32 {
    return cimgui.igColorConvertFloat4ToU32(in);
}

pub fn colorConvertFloat3ToU32(in: [3]f32) u32 {
    return colorConvertFloat4ToU32(.{ .x=in[0], .y=in[1], .z=in[2], .w=1 });
}

pub fn colorConvertRgbToHsv(r: f32, g: f32, b: f32) [3]f32 {
    var hsv: [3]f32 = undefined;
    cimgui.igColorConvertRGBtoHSV(r, g, b, &hsv[0], &hsv[1], &hsv[2]);
    return hsv;
}

pub fn colorConvertHsvToRgb(h: f32, s: f32, v: f32) [3]f32 {
    var rgb: [3]f32 = undefined;
    cimgui.igColorConvertHSVtoRGB(h, s, v, &rgb[0], &rgb[1], &rgb[2]);
    return rgb;
}

//--------------------------------------------------------------------------------------------------
//
// Inputs Utilities: Keyboard
//
//--------------------------------------------------------------------------------------------------
pub fn isKeyDown(key: Key) bool {
    return cimgui.igIsKeyDown_Nil(@intFromEnum(key));
}
pub fn isKeyPressed(key: Key, repeat: bool) bool {
    return cimgui.igIsKeyPressed_Bool(@intFromEnum(key), repeat);
}
pub fn isKeyReleased(key: Key) bool {
    return cimgui.igIsKeyReleased_Nil(@intFromEnum(key));
}
pub fn setNextFrameWantCaptureKeyboard(want_capture_keyboard: bool) void {
    cimgui.igSetNextFrameWantCaptureKeyboard(want_capture_keyboard);
}
pub const getKeyPressedAmount = cimgui.igGetKeyPressedAmount;

pub const setItemKeyOwner = cimgui.igSetItemKeyOwner_Nil;

//--------------------------------------------------------------------------------------------------
//
// Helpers
//
//--------------------------------------------------------------------------------------------------
var temp_buffer: ?std.ArrayList(u8) = null;

pub fn format(comptime fmt: []const u8, args: anytype) []const u8 {
    const len = std.fmt.count(fmt, args);
    if (len > temp_buffer.?.items.len) temp_buffer.?.resize(mem_allocator.?, @intCast(len + 64)) catch unreachable;
    return std.fmt.bufPrint(temp_buffer.?.items, fmt, args) catch unreachable;
}
pub fn formatZ(comptime fmt: []const u8, args: anytype) [:0]const u8 {
    const len = std.fmt.count(fmt ++ "\x00", args);
    if (len > temp_buffer.?.items.len) temp_buffer.?.resize(mem_allocator.?, @intCast(len + 64)) catch unreachable;
    return std.fmt.bufPrintZ(temp_buffer.?.items, fmt, args) catch unreachable;
}
//--------------------------------------------------------------------------------------------------
pub fn typeToDataTypeEnum(comptime T: type) DataType {
    return switch (T) {
        i8 => .I8,
        u8 => .U8,
        i16 => .I16,
        u16 => .U16,
        i32 => .I32,
        u32 => .U32,
        i64 => .I64,
        u64 => .U64,
        f32 => .F32,
        f64 => .F64,
        usize => switch (@sizeOf(usize)) {
            1 => .U8,
            2 => .U16,
            4 => .U32,
            8 => .U64,
            else => @compileError("Unsupported usize length"),
        },
        else => @compileError("Only fundamental scalar types allowed: " ++ @typeName(T)),
    };
}
//--------------------------------------------------------------------------------------------------
//
// Menus
//
//--------------------------------------------------------------------------------------------------
/// `pub fn beginMenuBar() bool`
pub const beginMenuBar = cimgui.igBeginMenuBar;
/// `pub fn endMenuBar() void`
pub const endMenuBar = cimgui.igEndMenuBar;
/// `pub fn beginMainMenuBar() bool`
pub const beginMainMenuBar = cimgui.igBeginMainMenuBar;
/// `pub fn endMainMenuBar() void`
pub const endMainMenuBar = cimgui.igEndMainMenuBar;

pub fn beginMenu(label: [:0]const u8, enabled: bool) bool {
    return cimgui.igBeginMenu(label, enabled);
}
/// `pub fn endMenu() void`
pub const endMenu = cimgui.igEndMenu;

const MenuItem = struct {
    shortcut: ?[:0]const u8 = null,
    selected: bool = false,
    enabled: bool = true,
};
pub fn menuItem(label: [:0]const u8, args: MenuItem) bool {
    return cimgui.igMenuItem_Bool(label, if (args.shortcut) |s| s.ptr else null, args.selected, args.enabled);
}

const MenuItemPtr = struct {
    shortcut: ?[:0]const u8 = null,
    selected: *bool,
    enabled: bool = true,
};
pub fn menuItemPtr(label: [:0]const u8, args: MenuItemPtr) bool {
    return cimgui.igMenuItem_BoolPtr(label, if (args.shortcut) |s| s.ptr else null, args.selected, args.enabled);
}

//--------------------------------------------------------------------------------------------------
//
// Popups
//
//--------------------------------------------------------------------------------------------------
/// `pub fn beginTooltip() bool`
pub const beginTooltip = cimgui.igBeginTooltip;
/// `pub fn endTooltip() void`
pub const endTooltip = cimgui.igEndTooltip;

/// `pub fn beginPopupContextWindow() bool`
pub const beginPopupContextWindow = cimgui.igBeginPopupContextWindow;
/// `pub fn beginPopupContextItem() bool`
pub const beginPopupContextItem = cimgui.igBeginPopupContextItem;
pub const PopupFlags = packed struct(c_int) {
    mouse_button_left: bool = false,
    mouse_button_right: bool = false,
    mouse_button_middle: bool = false,

    _reserved0: bool = false,
    _reserved1: bool = false,

    no_reopen: bool = false,
    _reserved2: bool = false,
    no_open_over_existing_popup: bool = false,
    no_open_over_items: bool = false,
    any_popup_id: bool = false,
    any_popup_level: bool = false,
    _padding: u21 = 0,

    pub const any_popup = PopupFlags{ .any_popup_id = true, .any_popup_level = true };
};
pub fn beginPopupModal(name: [:0]const u8, args: Begin) bool {
    return cimgui.igBeginPopupModal(name, args.popen, @bitCast(args.flags));
}
pub fn openPopup(str_id: [:0]const u8, flags: PopupFlags) void {
    cimgui.igOpenPopup_Str(str_id, @bitCast(flags));
}
/// `pub fn beginPopup(str_id: [:0]const u8, flags: WindowFlags) bool`
pub const beginPopup = cimgui.igBeginPopup;
/// `pub fn endPopup() void`
pub const endPopup = cimgui.igEndPopup;
/// `pub fn closeCurrentPopup() void`
pub const closeCurrentPopup = cimgui.igCloseCurrentPopup;
/// `pub fn isPopupOpen(str_id: [:0]const u8, flags: PopupFlags) bool`
pub const isPopupOpen = cimgui.igIsPopupOpen_Str;

//--------------------------------------------------------------------------------------------------
//
// Tabs
//
//--------------------------------------------------------------------------------------------------
pub const TabBarFlags = packed struct(c_int) {
    reorderable: bool = false,
    auto_select_new_tabs: bool = false,
    tab_list_popup_button: bool = false,
    no_close_with_middle_mouse_button: bool = false,
    no_tab_list_scrolling_buttons: bool = false,
    no_tooltip: bool = false,
    draw_selected_overline: bool = false,
    fitting_policy_resize_down: bool = false,
    fitting_policy_scroll: bool = false,
    _padding: u23 = 0,
};
pub const TabItemFlags = packed struct(c_int) {
    unsaved_document: bool = false,
    set_selected: bool = false,
    no_close_with_middle_mouse_button: bool = false,
    no_push_id: bool = false,
    no_tooltip: bool = false,
    no_reorder: bool = false,
    leading: bool = false,
    trailing: bool = false,
    no_assumed_closure: bool = false,
    _padding: u23 = 0,
};
pub fn beginTabBar(label: [:0]const u8, flags: TabBarFlags) bool {
    return cimgui.igBeginTabBar(label, @bitCast(flags));
}
const BeginTabItem = struct {
    p_open: ?*bool = null,
    flags: TabItemFlags = .{},
};
pub fn beginTabItem(label: [:0]const u8, args: BeginTabItem) bool {
    return cimgui.igBeginTabItem(label, args.p_open, @bitCast(args.flags));
}
/// `void endTabItem() void`
pub const endTabItem = cimgui.igEndTabItem;
/// `void endTabBar() void`
pub const endTabBar = cimgui.igEndTabBar;
pub fn setTabItemClosed(tab_or_docked_window_label: [:0]const u8) void {
    cimgui.igSetTabItemClosed(tab_or_docked_window_label);
}


pub const tabItemButton = cimgui.igTabItemButton;

//--------------------------------------------------------------------------------------------------
//
// Viewport
//
//--------------------------------------------------------------------------------------------------
pub const Viewport = struct {
    data: *cimgui.ImGuiViewport,

    pub fn getId(self: Viewport) Ident {
        return self.data.ID; 
    }

    pub fn getPos(self: Viewport) Vec2 {
        return self.data.Pos;
    }

    pub fn getSize(self: Viewport) Vec2 {
        return self.data.Size;
    }

    pub fn getWorkPos(self: Viewport) Vec2 {
        return self.data.Pos;
    }

    pub fn getWorkSize(self: Viewport) Vec2 {
        return self.data.WorkSize;
    }

    pub fn getCenter(self: Viewport) Vec2 {
        var center: Vec2 = undefined;
        cimgui.ImGuiViewport_GetCenter(&center, self.data);
        return center;
    }

    pub fn getWorkCenter(self: Viewport) Vec2 {
        var center: Vec2 = undefined;
        cimgui.ImGuiViewport_GetWorkCenter(&center, self.data);
        return center;
    }
};
pub const getMainViewport = cimgui.igGetMainViewport;

pub const updatePlatformWindows = cimgui.igUpdatePlatformWindows;

pub const renderPlatformWindowsDefault = cimgui.igRenderPlatformWindowsDefault;
//--------------------------------------------------------------------------------------------------
//
// Mouse Input
//
//--------------------------------------------------------------------------------------------------
pub const MouseDragDelta = struct {
    lock_threshold: f32 = -1.0,
};
pub fn getMouseDragDelta(drag_button: MouseButton, args: MouseDragDelta) Vec2 {
    var delta: Vec2 = undefined;
    cimgui.igGetMouseDragDelta(&delta, @intCast(@intFromEnum(drag_button)), args.lock_threshold);
    return delta;
}
pub const resetMouseDragDelta = cimgui.igResetMouseDragDelta;
//--------------------------------------------------------------------------------------------------
//
// Drag and Drop
//
//--------------------------------------------------------------------------------------------------
pub const DragDropFlags = packed struct(c_int) {
    source_no_preview_tooltip: bool = false,
    source_no_disable_hover: bool = false,
    source_no_hold_open_to_others: bool = false,
    source_allow_null_id: bool = false,
    source_extern: bool = false,
    payload_auto_expire: bool = false,
    payload_no_cross_context: bool = false,
    payload_no_cross_process: bool = false,

    _padding0: u2 = 0,

    accept_before_delivery: bool = false,
    accept_no_draw_default_rect: bool = false,
    accept_no_preview_tooltip: bool = false,

    _padding1: u19 = 0,

    pub const accept_peek_only = @This(){ .accept_before_delivery = true, .accept_no_draw_default_rect = true };
};

pub const Payload = extern struct {
    base: *cimgui.ImGuiPayload,


    pub fn init() Payload{
        return .{ .base = cimgui.ImGuiPayload_ImGuiPayload() };
    }

    pub fn clear(self: *Payload) void{
        cimgui.ImGuiPayload_Clear(self.base);
    }  

    pub fn isDataType(self: *Payload, @"type": [*:0]const u8) bool{
        return cimgui.ImGuiPayload_IsDataType(self.base, @"type");
    }

    pub fn isPreview(self: *Payload) bool{
        return cimgui.ImGuiPayload_IsPreview(self.base);
    }

    pub fn isDelivery(self: *Payload) bool{
        return cimgui.ImGuiPayload_IsDelivery(self.base);
    }

};

pub fn beginDragDropSource(flags: DragDropFlags) bool {
    return cimgui.igBeginDragDropSource(@bitCast(flags));
}

/// Note: `payload_type` can be at most 32 characters long
pub fn setDragDropPayload(payload_type: [*:0]const u8, data: []const u8, cond: Condition) bool {
    return cimgui.igSetDragDropPayload(payload_type, @alignCast(@ptrCast(data.ptr)), data.len, @intFromEnum(cond));
}
pub fn endDragDropSource() void {
    cimgui.igEndDragDropSource();
}
pub fn beginDragDropTarget() bool {
    return cimgui.igBeginDragDropTarget();
}

/// Note: `payload_type` can be at most 32 characters long
pub const acceptDragDropPayload = cimgui.igAcceptDragDropPayload;
pub const endDragDropTarget = cimgui.igEndDragDropTarget;
pub const getDragDropPayload = cimgui.igGetDragDropPayload;

//--------------------------------------------------------------------------------------------------
//
// DrawFlags
//
//--------------------------------------------------------------------------------------------------
pub const DrawFlags = packed struct(c_int) {
    closed: bool = false,
    _padding0: u3 = 0,
    round_corners_top_left: bool = false,
    round_corners_top_right: bool = false,
    round_corners_bottom_left: bool = false,
    round_corners_bottom_right: bool = false,
    round_corners_none: bool = false,
    _padding1: u23 = 0,

    pub const round_corners_top = DrawFlags{
        .round_corners_top_left = true,
        .round_corners_top_right = true,
    };

    pub const round_corners_bottom = DrawFlags{
        .round_corners_bottom_left = true,
        .round_corners_bottom_right = true,
    };

    pub const round_corners_left = DrawFlags{
        .round_corners_top_left = true,
        .round_corners_bottom_left = true,
    };

    pub const round_corners_right = DrawFlags{
        .round_corners_top_right = true,
        .round_corners_bottom_right = true,
    };

    pub const round_corners_all = DrawFlags{
        .round_corners_top_left = true,
        .round_corners_top_right = true,
        .round_corners_bottom_left = true,
        .round_corners_bottom_right = true,
    };
};

pub const DrawCmd = cimgui.ImDrawCmd;
pub const DrawCallback = cimgui.ImDrawCallback;

pub const getWindowDrawList = cimgui.igGetWindowDrawList;
pub const getBackgroundDrawList = cimgui.igGetBackgroundDrawList;
pub const getForegroundDrawList = cimgui.igGetForegroundDrawList_WindowPtr;

pub const getWindowDpiScale = cimgui.igGetWindowDpiScale;

pub const DrawList = struct {
    data: *cimgui.ImDrawList,

    pub const SharedData = cimgui.ImDrawListSharedData;

    pub fn init(shared_data: *SharedData) DrawList{
        return .{.data = cimgui.ImDrawList_ImDrawList(shared_data)};
    }

    pub fn deinit(self: *DrawList) void{
        cimgui.ImDrawList_destroy(self.data);
    }

    pub fn reset(self: DrawList) void {
        cimgui.ImDrawList__ResetForNewFrame(self.data);
    }

    pub fn clearMemory(self: DrawList) void {
        cimgui.ImDrawList__ClearFreeMemory(self.data);
    }

    //----------------------------------------------------------------------------------------------
    pub fn getVertexBufferLength(self: DrawList) i32 {
        return self.data.VtxBuffer.Size;
    }

    pub fn getVertexBufferData(self: DrawList) *DrawVert{
        return self.data.VtxBuffer.Data;
    }

    // pub fn getVertexBuffer(self: DrawList) []DrawVert {
    //     const len: usize = @intCast(self.getVertexBufferLength());
    //     return self.getVertexBufferData()[0..len];
    // }

    pub fn getIndexBufferLength(self: DrawList) i32 {
        return self.data.IdxBuffer.Size;
    }

    pub fn getIndexBufferData(self: DrawList) *DrawIdx{
        return self.data.IdxBuffer.Data;
    }
    // pub fn getIndexBuffer(self: DrawList) []DrawIdx {
    //     const len: usize = @intCast(self.getIndexBufferLength());
    //     return self.getIndexBufferData()[0..len];
    // }

    // pub fn getCurrentIndex(self: DrawList) u32 {
    //     return zguiDrawList_GetCurrentIndex(self);
    // }

    pub fn getCmdBufferLength(self: DrawList) i32 {
        return self.data.CmdBuffer.Size;
    }

    pub fn getCmdBufferData(self: DrawList) *DrawCmd{
        return self.data.CmdBuffer.Data;
    }

    // pub fn getCmdBuffer(self: DrawList) []DrawCmd {
    //     const len: usize = @intCast(self.getCmdBufferLength());
    //     return self.getCmdBufferData()[0..len];
    // }

    pub const DrawListFlags = packed struct(c_int) {
        anti_aliased_lines: bool = false,
        anti_aliased_lines_use_tex: bool = false,
        anti_aliased_fill: bool = false,
        allow_vtx_offset: bool = false,

        _padding: u28 = 0,
    };

    pub fn setDrawListFlags(self: *DrawList, flags: DrawListFlags) void{
        self.data.Flags = @bitCast(flags);
    }

    pub fn getDrawListFlags(self: DrawList) DrawListFlags{
        return @bitCast(self.data.Flags);
    }

    //----------------------------------------------------------------------------------------------
    const ClipRect = struct {
        pmin: Vec2,
        pmax: Vec2,
        intersect_with_current: bool = false,
    };
    pub fn pushClipRect(self: DrawList, args: ClipRect) void {
        cimgui.ImDrawList_PushClipRect(self.data, args.pmin, args.pmax, args.intersect_with_current);
    }
    //----------------------------------------------------------------------------------------------
    pub fn pushClipRectFullScreen(self: DrawList) void{
        cimgui.ImDrawList_PushClipRectFullScreen(self.data);
    }

    pub fn popClipRect(self: DrawList) void{
        cimgui.ImDrawList_PopClipRect(self.data);
    }
    //----------------------------------------------------------------------------------------------
    pub fn pushTexture(self: DrawList, tex: TextureRef) void{
        cimgui.ImDrawList_PushTexture(self.data, tex);
    }

    pub fn popTexture(self: DrawList) void{
        cimgui.ImDrawList_PopTexture(self.data);
    }
    //----------------------------------------------------------------------------------------------
    pub fn getClipRectMin(self: DrawList) Vec2 {
        var v: Vec2 = undefined;
        cimgui.ImDrawList_GetClipRectMin(&v, self.data);
        return v;
    }

    pub fn getClipRectMax(self: DrawList) Vec2 {
        var v: Vec2 = undefined;
        cimgui.ImDrawList_GetClipRectMax(&v, self.data);
        return v;
    }
    //----------------------------------------------------------------------------------------------
    pub fn addLine(self: DrawList, p1: Vec2, p2: Vec2, col: u32, thickness: f32) void {
        cimgui.ImDrawList_AddLine(self.data, p1, p2, col, thickness);
    }
    //----------------------------------------------------------------------------------------------
    pub fn addRect(self: DrawList, args: struct {
        pmin: Vec2,
        pmax: Vec2,
        col: u32,
        rounding: f32 = 0.0,
        flags: DrawFlags = .{},
        thickness: f32 = 1.0,
    }) void {
        cimgui.ImDrawList_AddRect(
            self.data,
            args.pmin, args.pmax,
            args.col, args.rounding,
            @bitCast(args.flags), args.thickness);
    }
    //----------------------------------------------------------------------------------------------
    pub fn addRectFilled(self: DrawList, args: struct {
        pmin: Vec2,
        pmax: Vec2,
        col: u32,
        rounding: f32 = 0.0,
        flags: DrawFlags = .{},
    }) void {
        cimgui.ImDrawList_AddRectFilled(
            self.data,
            args.pmin, args.pmax,
            args.col, args.rounding,
            @bitCast(args.flags)
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn addRectFilledMultiColor(self: DrawList, args: struct {
        pmin: Vec2,
        pmax: Vec2,
        col_upr_left: u32,
        col_upr_right: u32,
        col_bot_right: u32,
        col_bot_left: u32,
    }) void {
        cimgui.ImDrawList_AddRectFilledMultiColor(
            self.data,
            args.pmin, args.pmax,
            args.col_upr_left, args.col_upr_right,
            args.col_bot_right, args.col_bot_left,
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn addQuad(self: DrawList, args: struct {
        p1: Vec2, p2: Vec2, p3: Vec2, p4: Vec2,
        col: u32, thickness: f32 = 1.0,
    }) void {
        cimgui.ImDrawList_AddQuad(
            self.data,
            args.p1, args.p2, args.p3, args.p4,
            args.col, args.thickness,
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn addQuadFilled(self: DrawList, args: struct {
        p1: Vec2, p2: Vec2, p3: Vec2, p4: Vec2,
        col: u32,
    }) void {
        cimgui.ImDrawList_AddQuadFilled(
            self.data,
            args.p1, args.p2, args.p3, args.p4,
            args.col
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn addTriangle(self: DrawList, args: struct {
        p1: Vec2, p2: Vec2, p3: Vec2,
        col: u32, thickness: f32 = 1.0,
    }) void {
        cimgui.ImDrawList_AddTriangle(
            self.data,
            args.p1, args.p2, args.p3,
            args.col, args.thickness
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn addTriangleFilled(self: DrawList, args: struct {
        p1: Vec2,
        p2: Vec2,
        p3: Vec2,
        col: u32,
    }) void {
        cimgui.ImDrawList_AddTriangleFilled(
            self.data,
            args.p1, args.p2, args.p3,
            args.col
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn addCircle(self: DrawList, args: struct {
        p: Vec2,
        r: f32,
        col: u32,
        num_segments: i32 = 0,
        thickness: f32 = 1.0,
    }) void {
        cimgui.ImDrawList_AddCircle(
            self.data,
            args.p,
            args.r,
            args.col,
            args.num_segments,
            args.thickness,
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn addCircleFilled(self: DrawList, args: struct {
        p: Vec2,
        r: f32,
        col: u32,
        num_segments: u16 = 0,
    }) void {
        cimgui.ImDrawList_AddCircleFilled(self.data, args.p, args.r, args.col, args.num_segments);
    }
    //----------------------------------------------------------------------------------------------
    pub fn addEllipse(self: DrawList, args: struct {
        p: Vec2,
        r: Vec2,
        col: u32,
        rot: f32 = 0,
        num_segments: i32 = 0,
        thickness: f32 = 1.0,
    }) void {
        cimgui.ImDrawList_AddEllipse(
            self.data,
            args.p,
            args.r,
            args.col,
            args.rot,
            args.num_segments,
            args.thickness,
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn addEllipseFilled(self: DrawList, args: struct {
        p: Vec2,
        r: Vec2,
        col: u32,
        rot: f32 = 0,
        num_segments: u16 = 0,
    }) void {
        cimgui.ImDrawList_AddEllipseFilled(
            self.data,
            args.p,
            args.r,
            args.col,
            args.rot,
            args.num_segments,
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn addNgon(self: DrawList, args: struct {
        p: Vec2,
        r: f32,
        col: u32,
        num_segments: u32,
        thickness: f32 = 1.0,
    }) void {
        cimgui.ImDrawList_AddNgon(
            self.data,
            args.p,
            args.r,
            args.col,
            @intCast(args.num_segments),
            args.thickness,
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn addNgonFilled(self: DrawList, args: struct {
        p: Vec2,
        r: f32,
        col: u32,
        num_segments: u32,
    }) void {
        cimgui.ImDrawList_AddNgonFilled(self.data, args.p, args.r, args.col, @intCast(args.num_segments));
    }
    //----------------------------------------------------------------------------------------------
    pub fn addText(draw_list: DrawList, pos: Vec2, col: u32, comptime fmt: []const u8, args: anytype) void {
        const txt = format(fmt, args);
        draw_list.addTextUnformatted(pos, col, txt);
    }
    pub fn addTextUnformatted(self: DrawList, pos: Vec2, col: u32, txt: []const u8) void {
        cimgui.ImDrawList_AddText_Vec2(self.data, pos, col, txt.ptr, txt.ptr + txt.len);
    }
    const AddTextArgs = struct {
        font: ?Font,
        font_size: f32,
        wrap_width: f32 = 0,
        cpu_fine_clip_rect: ?[*]const Vec4 = null,
    };
    pub fn addTextExtended(
        self: DrawList,
        pos: Vec2,
        col: u32,
        comptime fmt: []const u8,
        args: anytype,
        add_text_args: AddTextArgs,
    ) void {
        const txt = format(fmt, args);
        self.addTextExtendedUnformatted(pos, col, txt, add_text_args);
    }
    pub fn addTextExtendedUnformatted(
        self: DrawList,
        pos: Vec2,
        col: u32,
        txt: []const u8,
        add_text_args: AddTextArgs,
    ) void {
        cimgui.ImDrawList_AddText_FontPtr(
            self.data,
            add_text_args.font,
            add_text_args.font_size,
            pos,
            col,
            txt.ptr,
            txt.ptr + txt.len,
            add_text_args.wrap_width,
            add_text_args.cpu_fine_clip_rect,
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn addPolyline(self: DrawList, points: []const Vec2, args: struct {
        col: u32,
        flags: DrawFlags = .{},
        thickness: f32 = 1.0,
    }) void {
        cimgui.ImDrawList_AddPolyline(
            self.data,
            points.ptr,
            @intCast(points.len),
            args.col,
            @bitCast(args.flags),
            args.thickness,
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn addConvexPolyFilled(
        self: DrawList,
        points: []const Vec2,
        col: u32,
    ) void {
        cimgui.ImDrawList_AddConvexPolyFilled(
            self.data,
            points.ptr,
            @intCast(points.len),
            col,
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn addConcavePolyFilled(
        self: DrawList,
        points: []const Vec2,
        col: u32,
    ) void {
        cimgui.ImDrawList_AddConcavePolyFilled(
            self.data,
            points.ptr,
            @intCast(points.len),
            col,
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn addBezierCubic(self: DrawList, args: struct {
        p1: Vec2, p2: Vec2, p3: Vec2, p4: Vec2,
        col: u32, thickness: f32 = 1.0,
        num_segments: u32 = 0,
    }) void {
        cimgui.ImDrawList_AddBezierCubic(
            self.data,
            args.p1, args.p2, args.p3, args.p4,
            args.col, args.thickness,
            @intCast(args.num_segments),
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn addBezierQuadratic(self: DrawList, args: struct {
        p1: Vec2, p2: Vec2, p3: Vec2,
        col: u32, thickness: f32 = 1.0,
        num_segments: u32 = 0,
    }) void {
        cimgui.ImDrawList_AddBezierQuadratic(
            self.data,
            args.p1, args.p2, args.p3,
            args.col, args.thickness,
            @intCast(args.num_segments),
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn addImage(self: DrawList, user_texture_ref: TextureRef, args: struct {
        pmin: Vec2, pmax: Vec2,
        uvmin: Vec2 = .{ },
        uvmax: Vec2 = .{ .x = 1, .y = 1},
        col: u32 = 0xff_ff_ff_ff,
    }) void {
        cimgui.ImDrawList_AddImage(
            self.data,
            user_texture_ref,
            args.pmin, args.pmax,
            args.uvmin,
            args.uvmax,
            args.col,
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn addImageQuad(self: DrawList, user_texture_ref: TextureRef, args: struct {
        p1: Vec2, p2: Vec2, p3: Vec2, p4: Vec2,
        uv1: Vec2 = .{ .x = 0, .y = 0 },
        uv2: Vec2 = .{ .x = 1, .y = 0 },
        uv3: Vec2 = .{ .x = 1, .y = 1 },
        uv4: Vec2 = .{ .x = 0, .y = 1 },
        col: u32 = 0xff_ff_ff_ff,
    }) void {
        cimgui.ImDrawList_AddImageQuad(
            self.data,
            user_texture_ref,
            args.p1, args.p2, args.p3, args.p4,
            args.uv1, args.uv2, args.uv3, args.uv4,
            args.col,
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn addImageRounded(self: DrawList, user_texture_ref: TextureRef, args: struct {
        pmin: Vec2, pmax: Vec2,
        uvmin: Vec2 = .{ .x = 0, .y = 0 },
        uvmax: Vec2 = .{ .x = 1, .y = 1 },
        col: u32 = 0xff_ff_ff_ff,
        rounding: f32 = 4.0,
        flags: DrawFlags = .{},
    }) void {
        cimgui.ImDrawList_AddImageRounded(
            self.data,
            user_texture_ref,
            args.pmin, args.pmax,
            args.uvmin, args.uvmax,
            args.col, args.rounding,
            @bitCast(args.flags),
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn pathClear(self: DrawList) void{
        cimgui.ImDrawList_PathClear(self.data);
    }
    //----------------------------------------------------------------------------------------------
    pub fn pathLineTo(self: DrawList, pos: Vec2) void {
        cimgui.ImDrawList_PathLineTo(self.data, pos);
    }
    //----------------------------------------------------------------------------------------------
    pub fn pathLineToMergeDuplicate(self: DrawList, pos: Vec2) void {
        cimgui.ImDrawList_PathLineToMergeDuplicate(self.data, pos);
    }
    //----------------------------------------------------------------------------------------------
    pub fn pathFillConvex(self: DrawList, col: u32) void {
        cimgui.ImDrawList_PathFillConvex(self.data, col);
    }
    //----------------------------------------------------------------------------------------------
    pub fn pathFillConcave(self: DrawList, col: u32) void {
        cimgui.ImDrawList_PathFillConcave(self.data, col);
    }
    //----------------------------------------------------------------------------------------------
    pub fn pathStroke(self: DrawList, args: struct {
        col: u32,
        flags: DrawFlags = .{},
        thickness: f32 = 1.0,
    }) void {
        cimgui.ImDrawList_PathStroke(self.data, args.col, @bitCast(args.flags), args.thickness);
    }
    //----------------------------------------------------------------------------------------------
    pub fn pathArcTo(self: DrawList, args: struct {
        p: Vec2, r: f32,
        amin: f32, amax: f32,
        num_segments: u16 = 0,
    }) void {
        cimgui.ImDrawList_PathArcTo(
            self.data,
            args.p, args.r,
            args.amin, args.amax,
            args.num_segments,
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn pathArcToFast(self: DrawList, args: struct {
        p: Vec2,
        r: f32,
        amin_of_12: u16,
        amax_of_12: u16,
    }) void {
        cimgui.ImDrawList_PathArcToFast(self.data, args.p, args.r, args.amin_of_12, args.amax_of_12);
    }
    //----------------------------------------------------------------------------------------------
    pub fn pathEllipticalArcTo(self: DrawList, args: struct {
        p: Vec2, r: Vec2, rot: f32,
        amin: f32, amax: f32,
        num_segments: u16 = 0,
    }) void {
        cimgui.ImDrawList_PathEllipticalArcTo(
            self.data,
            args.p, args.r, args.rot,
            args.amin, args.amax,
            args.num_segments,
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn pathBezierCubicCurveTo(self: DrawList, args: struct {
        p2: Vec2, p3: Vec2, p4: Vec2,
        num_segments: u16 = 0,
    }) void {
        cimgui.ImDrawList_PathBezierCubicCurveTo(
            self.data,
            args.p2, args.p3, args.p4,
            args.num_segments,
        );
    }
    //----------------------------------------------------------------------------------------------
    pub fn pathBezierQuadraticCurveTo(self: DrawList, args: struct {
        p2: Vec2, p3: Vec2,
        num_segments: u16 = 0,
    }) void {
        cimgui.ImDrawList_PathBezierQuadraticCurveTo(self.data, args.p2, args.p3, args.num_segments);
    }
    //----------------------------------------------------------------------------------------------
    const PathRect = struct {
        bmin: Vec2, bmax: Vec2,
        rounding: f32 = 0.0,
        flags: DrawFlags = .{},
    };
    pub fn pathRect(self: DrawList, args: PathRect) void {
        cimgui.ImDrawList_PathRect(self.data, args.bmin, args.bmax, args.rounding, @bitCast(args.flags));
    }
    //----------------------------------------------------------------------------------------------
    pub fn primReserve (self: DrawList, idx_count: i32, vtx_count: i32) void {
        cimgui.ImDrawList_PrimReserve(self.data, idx_count, vtx_count);
    }

    pub fn primUnreserve (self: DrawList, idx_count: i32, vtx_count: i32) void {
        cimgui.ImDrawList_PrimUnreserve(self.data, idx_count, vtx_count);
    }

    pub fn primRect(
        self: DrawList,
        a: Vec2, b: Vec2,
        col: u32,
    ) void {
        cimgui.ImDrawList_PrimRect(self.data, a, b, col);
    }

    pub fn primRectUV(
        self: DrawList,
        a: Vec2, b: Vec2,
        uv_a: Vec2, uv_b: Vec2,
        col: u32,
    ) void {
        cimgui.ImDrawList_PrimRectUV(self.data, a, b, uv_a, uv_b, col);
    }

    pub fn primQuadUV(
        self: DrawList,
        a: Vec2, b: Vec2, c: Vec2, d: Vec2,
        uv_a: Vec2, uv_b: Vec2, uv_c: Vec2, uv_d: Vec2,
        col: u32,
    ) void {
        cimgui.ImDrawList_PrimQuadUV(self.data, a, b, c, d, uv_a, uv_b, uv_c, uv_d, col);
    }

    pub fn primWriteVtx(
        self: DrawList,
        pos: Vec2,
        uv: Vec2,
        col: u32,
    ) void {
        cimgui.ImDrawList_PrimWriteVtx(self.data, pos, uv, col);
    }

    pub fn primWriteIdx(self: DrawList, idx: u16) void{
        cimgui.ImDrawList_PrimWriteIdx(self.data, idx);
    }

    //----------------------------------------------------------------------------------------------

    pub fn addCallback(self: DrawList, callback: DrawCallback, callback_data: ?*anyopaque) void {
        cimgui.ImDrawList_AddCallback(self.data, @ptrCast(callback), callback_data, 0);
    }
    pub fn addResetRenderStateCallback(self: DrawList) void {
        self.addCallback(@ptrCast(cimgui.ImDrawCallback_ResetRenderState), null);

    }
};

fn Vector(comptime T: type) type {
    return extern struct {
        len: c_int,
        capacity: c_int,
        items: [*]T,
    };
}

test { 
    std.testing.refAllDecls(@This());
}

test {
    const testing = std.testing;

    if (@import("zgui_options").with_gizmo) _ = gizmo;

    init(testing.allocator);
    defer deinit();

    io.setIniFilename(null);
    io.setBackendFlags(.{
        .renderer_has_textures = true,
    });
    io.setDisplaySize(1, 1);

    newFrame();

    try testing.expect(begin("testing", .{}));
    defer end();

    const Testing = enum {
        one,
        two,
        three,
    };
    var value = Testing.one;
    _ = comboFromEnum("comboFromEnum", &value);
}
