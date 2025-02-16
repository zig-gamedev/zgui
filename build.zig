const std = @import("std");

pub const Backend = enum {
    no_backend,
    glfw_wgpu,
    glfw_opengl3,
    glfw_vulkan,
    glfw_dx12,
    win32_dx12,
    glfw,
    sdl2_opengl3,
    osx_metal,
};

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const options = .{
        .backend = b.option(Backend, "backend", "Backend to build (default: no_backend)") orelse .no_backend,
        .shared = b.option(
            bool,
            "shared",
            "Bulid as a shared library",
        ) orelse false,
        .with_implot = b.option(
            bool,
            "with_implot",
            "Build with bundled implot source",
        ) orelse false,
        .with_gizmo = b.option(
            bool,
            "with_gizmo",
            "Build with bundled ImGuizmo tool",
        ) orelse false,
        .with_node_editor = b.option(
            bool,
            "with_node_editor",
            "Build with bundled ImGui node editor",
        ) orelse false,
        .with_te = b.option(
            bool,
            "with_te",
            "Build with bundled test engine support",
        ) orelse false,
        .with_freetype = b.option(
            bool,
            "with_freetype",
            "Build with system FreeType engine support",
        ) orelse false,
        .use_wchar32 = b.option(
            bool,
            "use_wchar32",
            "Extended unicode support",
        ) orelse false,
        .use_32bit_draw_idx = b.option(
            bool,
            "use_32bit_draw_idx",
            "Use 32-bit draw index",
        ) orelse false,
    };

    const options_step = b.addOptions();
    inline for (std.meta.fields(@TypeOf(options))) |field| {
        options_step.addOption(field.type, field.name, @field(options, field.name));
    }

    const options_module = options_step.createModule();

    const mod = b.addModule("root", .{
        .root_source_file = b.path("src/gui.zig"),
        .imports = &.{
            .{ .name = "zgui_options", .module = options_module },
        },
    });

    const cflags = &.{
        "-fno-sanitize=undefined",
        "-Wno-elaborated-enum-base",
        "-Wno-error=date-time",
        if (options.use_32bit_draw_idx) "-DIMGUI_USE_32BIT_DRAW_INDEX" else "",
    };

    const objcflags = &.{
        "-Wno-deprecated",
        "-Wno-pedantic",
        "-Wno-availability",
    };

    const imgui = if (options.shared) blk: {
        const lib = b.addSharedLibrary(.{
            .name = "imgui",
            .target = target,
            .optimize = optimize,
        });

        if (target.result.os.tag == .windows) {
            lib.root_module.addCMacro("IMGUI_API", "__declspec(dllexport)");
            lib.root_module.addCMacro("IMPLOT_API", "__declspec(dllexport)");
            lib.root_module.addCMacro("ZGUI_API", "__declspec(dllexport)");
        }

        if (target.result.os.tag == .macos) {
            lib.linker_allow_shlib_undefined = true;
        }

        break :blk lib;
    } else b.addStaticLibrary(.{
        .name = "imgui",
        .target = target,
        .optimize = optimize,
    });

    mod.linkLibrary(imgui);

    const emscripten = target.result.os.tag == .emscripten;
    if (emscripten) {
        mod.addCMacro("__EMSCRIPTEN__", "");
        // TODO: read from enviroment or `emcc --version`
        mod.addCMacro("__EMSCRIPTEN_major__", "3");
        mod.addCMacro("__EMSCRIPTEN_minor__", "1");
        mod.stack_protector = false;
        //mod.disable_stack_probing = true;
    }

    mod.addIncludePath(b.path("libs"));
    mod.addIncludePath(b.path("libs/imgui"));

    if (!emscripten) {
        mod.link_libc = true;
        if (target.result.abi != .msvc)
            mod.link_libcpp = true;
    }

    mod.addCSourceFile(.{
        .file = b.path("src/zgui.cpp"),
        .flags = cflags,
    });

    mod.addCSourceFiles(.{
        .files = &.{
            "libs/imgui/imgui.cpp",
            "libs/imgui/imgui_widgets.cpp",
            "libs/imgui/imgui_tables.cpp",
            "libs/imgui/imgui_draw.cpp",
            "libs/imgui/imgui_demo.cpp",
        },
        .flags = cflags,
    });

    if (options.with_freetype) {
        if (b.lazyDependency("freetype", .{})) |freetype| {
            mod.linkLibrary(freetype.artifact("freetype"));
        }
        mod.addCSourceFile(.{
            .file = b.path("libs/imgui/misc/freetype/imgui_freetype.cpp"),
            .flags = cflags,
        });
        mod.addCMacro("IMGUI_ENABLE_FREETYPE", "1");
    }

    if (options.use_wchar32) {
        mod.addCMacro("IMGUI_USE_WCHAR32", "1");
    }

    if (options.with_implot) {
        mod.addIncludePath(b.path("libs/implot"));

        mod.addCSourceFile(.{
            .file = b.path("src/zplot.cpp"),
            .flags = cflags,
        });

        mod.addCSourceFiles(.{
            .files = &.{
                "libs/implot/implot_demo.cpp",
                "libs/implot/implot.cpp",
                "libs/implot/implot_items.cpp",
            },
            .flags = cflags,
        });
    }

    if (options.with_gizmo) {
        mod.addIncludePath(b.path("libs/imguizmo/"));

        mod.addCSourceFile(.{
            .file = b.path("src/zgizmo.cpp"),
            .flags = cflags,
        });

        mod.addCSourceFiles(.{
            .files = &.{
                "libs/imguizmo/ImGuizmo.cpp",
            },
            .flags = cflags,
        });
    }

    if (options.with_node_editor) {
        mod.addCSourceFile(.{
            .file = b.path("src/znode_editor.cpp"),
            .flags = cflags,
        });

        mod.addCSourceFile(.{ .file = b.path("libs/node_editor/crude_json.cpp"), .flags = cflags });
        mod.addCSourceFile(.{ .file = b.path("libs/node_editor/imgui_canvas.cpp"), .flags = cflags });
        mod.addCSourceFile(.{ .file = b.path("libs/node_editor/imgui_node_editor_api.cpp"), .flags = cflags });
        mod.addCSourceFile(.{ .file = b.path("libs/node_editor/imgui_node_editor.cpp"), .flags = cflags });
    }

    if (options.with_te) {
        mod.addCSourceFile(.{
            .file = b.path("src/zte.cpp"),
            .flags = cflags,
        });

        mod.addCMacro("IMGUI_ENABLE_TEST_ENGINE", "");
        mod.addCMacro("IMGUI_TEST_ENGINE_ENABLE_COROUTINE_STDTHREAD_IMPL", "1");

        mod.addIncludePath(b.path("libs/imgui_test_engine/"));

        mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_capture_tool.cpp"), .flags = cflags });
        mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_context.cpp"), .flags = cflags });
        mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_coroutine.cpp"), .flags = cflags });
        mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_engine.cpp"), .flags = cflags });
        mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_exporters.cpp"), .flags = cflags });
        mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_perftool.cpp"), .flags = cflags });
        mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_ui.cpp"), .flags = cflags });
        mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_utils.cpp"), .flags = cflags });

        // TODO: Workaround because zig on win64 doesn have phtreads
        // TODO: Implement corutine in zig can solve this
        if (target.result.os.tag == .windows) {
            const src: []const []const u8 = &.{
                "libs/winpthreads/src/nanosleep.c",
                "libs/winpthreads/src/cond.c",
                "libs/winpthreads/src/barrier.c",
                "libs/winpthreads/src/misc.c",
                "libs/winpthreads/src/clock.c",
                "libs/winpthreads/src/libgcc/dll_math.c",
                "libs/winpthreads/src/spinlock.c",
                "libs/winpthreads/src/thread.c",
                "libs/winpthreads/src/mutex.c",
                "libs/winpthreads/src/sem.c",
                "libs/winpthreads/src/sched.c",
                "libs/winpthreads/src/ref.c",
                "libs/winpthreads/src/rwlock.c",
            };

            const winpthreads = b.addStaticLibrary(.{
                .name = "winpthreads",
                .optimize = optimize,
                .target = target,
            });
            winpthreads.want_lto = false;
            winpthreads.root_module.sanitize_c = false;
            if (optimize == .Debug or optimize == .ReleaseSafe)
                winpthreads.bundle_compiler_rt = true
            else
                winpthreads.root_module.strip = true;
            winpthreads.addCSourceFiles(.{ .files = src, .flags = &.{
                "-Wall",
                "-Wextra",
            } });
            winpthreads.root_module.addCMacro("__USE_MINGW_ANSI_STDIO", "1");
            winpthreads.addIncludePath(b.path("libs/winpthreads/include"));
            winpthreads.addIncludePath(b.path("libs/winpthreads/src"));
            winpthreads.linkLibC();
            mod.linkLibrary(winpthreads);
            mod.addSystemIncludePath(b.path("libs/winpthreads/include"));
        }
    }

    switch (options.backend) {
        .glfw_wgpu => {
            if (emscripten) {
                mod.addSystemIncludePath(.{
                    .cwd_relative = b.pathJoin(&.{ b.sysroot.?, "include" }),
                });
            } else {
                if (b.lazyDependency("zglfw", .{})) |zglfw| {
                    mod.addIncludePath(zglfw.path("libs/glfw/include"));
                }
                if (b.lazyDependency("zgpu", .{})) |zgpu| {
                    mod.addIncludePath(zgpu.path("libs/dawn/include"));
                }
            }
            mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_glfw.cpp",
                    "libs/imgui/backends/imgui_impl_wgpu.cpp",
                },
                .flags = cflags,
            });
        },
        .glfw_opengl3 => {
            if (b.lazyDependency("zglfw", .{})) |zglfw| {
                mod.addIncludePath(zglfw.path("libs/glfw/include"));
            }
            mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_glfw.cpp",
                    "libs/imgui/backends/imgui_impl_opengl3.cpp",
                },
                .flags = &(cflags.* ++ .{"-DIMGUI_IMPL_OPENGL_LOADER_CUSTOM"}),
            });
        },
        .glfw_dx12 => {
            if (b.lazyDependency("zglfw", .{})) |zglfw| {
                mod.addIncludePath(zglfw.path("libs/glfw/include"));
            }
            mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_glfw.cpp",
                    "libs/imgui/backends/imgui_impl_dx12.cpp",
                },
                .flags = cflags,
            });
            mod.linkSystemLibrary("d3dcompiler_47", .{});
        },
        .win32_dx12 => {
            mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_win32.cpp",
                    "libs/imgui/backends/imgui_impl_dx12.cpp",
                },
                .flags = cflags,
            });
            mod.linkSystemLibrary("d3dcompiler_47", .{});
            mod.linkSystemLibrary("dwmapi", .{});
            switch (target.result.abi) {
                .msvc => mod.linkSystemLibrary("Gdi32", .{}),
                .gnu => mod.linkSystemLibrary("gdi32", .{}),
                else => {},
            }
        },
        .glfw_vulkan => {
            if (b.lazyDependency("zglfw", .{})) |zglfw| {
                mod.addIncludePath(zglfw.path("libs/glfw/include"));
            }

            mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_glfw.cpp",
                    "libs/imgui/backends/imgui_impl_vulkan.cpp",
                },
                .flags = &(cflags.* ++ .{ "-DVK_NO_PROTOTYPES", "-DZGUI_DEGAMMA" }),
            });
        },
        .glfw => {
            if (b.lazyDependency("zglfw", .{})) |zglfw| {
                mod.addIncludePath(zglfw.path("libs/glfw/include"));
            }
            mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_glfw.cpp",
                },
                .flags = cflags,
            });
        },
        .sdl2_opengl3 => {
            if (b.lazyDependency("zsdl", .{})) |zsdl| {
                mod.addIncludePath(zsdl.path("libs/sdl2/include"));
            }
            mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_sdl2.cpp",
                    "libs/imgui/backends/imgui_impl_opengl3.cpp",
                },
                .flags = &(cflags.* ++ .{"-DIMGUI_IMPL_OPENGL_LOADER_CUSTOM"}),
            });
        },
        .osx_metal => {
            mod.linkFramework("Foundation");
            mod.linkFramework("Metal");
            mod.linkFramework("Cocoa");
            mod.linkFramework("QuartzCore");
            mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_osx.mm",
                    "libs/imgui/backends/imgui_impl_metal.mm",
                },
                .flags = objcflags,
            });
        },
        .no_backend => {},
    }

    if (target.result.os.tag == .macos) {
        if (b.lazyDependency("system_sdk", .{})) |system_sdk| {
            mod.addSystemIncludePath(system_sdk.path("macos12/usr/include"));
            mod.addFrameworkPath(system_sdk.path("macos12/System/Library/Frameworks"));
        }
    }

    const test_step = b.step("test", "Run zgui tests");

    const tests = b.addTest(.{
        .name = "zgui-tests",
        .root_source_file = b.path("src/gui.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(tests);

    tests.root_module.addImport("zgui_options", options_module);
    tests.linkLibrary(imgui);

    test_step.dependOn(&b.addRunArtifact(tests).step);
}
