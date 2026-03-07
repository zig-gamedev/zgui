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
    sdl2,
    sdl2_renderer,
    sdl3,
    sdl3_opengl3,
    sdl3_vulkan,
    sdl3_renderer,
    sdl3_gpu,
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
        .with_knobs = b.option(
            bool,
            "with_knobs",
            "Build with bundled Imgui-Knobs",
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
        .disable_obsolete = b.option(
            bool,
            "disable_obsolete",
            "Disable obsolete imgui functions",
        ) orelse true,
        .vulkan_include = b.option(
            []const u8,
            "vulkan_include",
            "Path to Vulkan Headers",
        ),
    };

    const options_step = b.addOptions();
    inline for (std.meta.fields(@TypeOf(options))) |field| {
        options_step.addOption(field.type, field.name, @field(options, field.name));
    }

    const options_module = options_step.createModule();

    _ = b.addModule("root", .{
        .root_source_file = b.path("src/gui.zig"),
        .imports = &.{
            .{ .name = "zgui_options", .module = options_module },
        },
    });

    const cflags = &.{
        "-fno-sanitize=undefined",
        "-Wno-elaborated-enum-base",
        "-Wno-error=date-time",
        if (options.use_32bit_draw_idx) "-DImDrawIdx=unsigned int" else "",
    };

    const objcflags = &.{
        "-Wno-deprecated",
        "-Wno-pedantic",
        "-Wno-availability",
    };

    const imgui_mod = b.addModule("imgui", .{
        .target = target,
        .optimize = optimize,
    });

    const imgui = b.addLibrary(.{
        .name = "imgui",
        .linkage = if (options.shared) .dynamic else .static,
        .root_module = imgui_mod,
    });

    if (options.disable_obsolete) {
        imgui_mod.addCMacro("IMGUI_DISABLE_OBSOLETE_FUNCTIONS", "");
    }

    const imgui_impl_api_default = "extern \"C\"";
    var imgui_impl_api: []const u8 = imgui_impl_api_default;
    if (options.shared) {
        if (target.result.os.tag == .windows) {
            imgui_mod.addCMacro("IMGUI_API", "__declspec(dllexport)");
            imgui_mod.addCMacro("IMPLOT_API", "__declspec(dllexport)");
            imgui_mod.addCMacro("ZGUI_API", "__declspec(dllexport)");
            imgui_impl_api = "extern \"C\" __declspec(dllexport)";
        }

        if (target.result.os.tag == .macos) {
            imgui.linker_allow_shlib_undefined = true;
        }
    }

    imgui_mod.addCMacro("IMGUI_IMPL_API", imgui_impl_api);

    b.installArtifact(imgui);

    imgui_mod.addIncludePath(b.path("libs"));
    imgui_mod.addIncludePath(b.path("libs/imgui"));

    imgui_mod.link_libc = true;
    if (target.result.abi != .msvc)
        imgui_mod.link_libcpp = true;

    imgui_mod.addCSourceFile(.{
        .file = b.path("src/zgui.cpp"),
        .flags = cflags,
    });

    imgui_mod.addCSourceFiles(.{
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
            imgui_mod.linkLibrary(freetype.artifact("freetype"));
        }
        imgui_mod.addCSourceFile(.{
            .file = b.path("libs/imgui/misc/freetype/imgui_freetype.cpp"),
            .flags = cflags,
        });
        imgui_mod.addCMacro("IMGUI_ENABLE_FREETYPE", "1");
    }

    if (options.use_wchar32) {
        imgui_mod.addCMacro("IMGUI_USE_WCHAR32", "1");
    }

    if (options.with_implot) {
        imgui_mod.addIncludePath(b.path("libs/implot"));

        imgui_mod.addCSourceFile(.{
            .file = b.path("src/zplot.cpp"),
            .flags = cflags,
        });

        imgui_mod.addCSourceFiles(.{
            .files = &.{
                "libs/implot/implot_demo.cpp",
                "libs/implot/implot.cpp",
                "libs/implot/implot_items.cpp",
            },
            .flags = cflags,
        });
    }

    if (options.with_gizmo) {
        imgui_mod.addIncludePath(b.path("libs/imguizmo/"));

        imgui_mod.addCSourceFile(.{
            .file = b.path("src/zgizmo.cpp"),
            .flags = cflags,
        });

        imgui_mod.addCSourceFiles(.{
            .files = &.{
                "libs/imguizmo/ImGuizmo.cpp",
            },
            .flags = cflags,
        });
    }

    if (options.with_knobs) {
        imgui_mod.addIncludePath(b.path("libs/imgui_knobs/"));

        imgui_mod.addCSourceFile(.{
            .file = b.path("src/zknobs.cpp"),
            .flags = cflags,
        });

        imgui_mod.addCSourceFiles(.{
            .files = &.{
                "libs/imgui_knobs/imgui-knobs.cpp",
            },
            .flags = cflags,
        });
    }

    if (options.with_node_editor) {
        imgui_mod.addCSourceFile(.{
            .file = b.path("src/znode_editor.cpp"),
            .flags = cflags,
        });

        imgui_mod.addCSourceFile(.{ .file = b.path("libs/node_editor/crude_json.cpp"), .flags = cflags });
        imgui_mod.addCSourceFile(.{ .file = b.path("libs/node_editor/imgui_canvas.cpp"), .flags = cflags });
        imgui_mod.addCSourceFile(.{ .file = b.path("libs/node_editor/imgui_node_editor_api.cpp"), .flags = cflags });
        imgui_mod.addCSourceFile(.{ .file = b.path("libs/node_editor/imgui_node_editor.cpp"), .flags = cflags });
    }

    if (options.with_te) {
        imgui_mod.addCSourceFile(.{
            .file = b.path("src/zte.cpp"),
            .flags = cflags,
        });

        imgui_mod.addCMacro("IMGUI_ENABLE_TEST_ENGINE", "");
        imgui_mod.addCMacro("IMGUI_TEST_ENGINE_ENABLE_COROUTINE_STDTHREAD_IMPL", "1");

        imgui_mod.addIncludePath(b.path("libs/imgui_test_engine/"));

        imgui_mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_capture_tool.cpp"), .flags = cflags });
        imgui_mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_context.cpp"), .flags = cflags });
        imgui_mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_coroutine.cpp"), .flags = cflags });
        imgui_mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_engine.cpp"), .flags = cflags });
        imgui_mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_exporters.cpp"), .flags = cflags });
        imgui_mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_perftool.cpp"), .flags = cflags });
        imgui_mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_ui.cpp"), .flags = cflags });
        imgui_mod.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_utils.cpp"), .flags = cflags });
    }

    switch (options.backend) {
        .glfw_wgpu => {
            if (b.lazyDependency("zglfw", .{})) |zglfw| {
                imgui_mod.addIncludePath(zglfw.path("libs/glfw/include"));
            }
            if (b.lazyDependency("zgpu", .{})) |zgpu| {
                if (target.result.os.tag != .emscripten) {
                    imgui_mod.addIncludePath(zgpu.path("libs/dawn/include"));
                }
            }
            imgui_mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_glfw.cpp",
                    "libs/imgui/backends/imgui_impl_wgpu.cpp",
                },
                .flags = cflags,
            });
        },
        .glfw_opengl3 => {
            if (b.lazyDependency("zglfw", .{})) |zglfw| {
                imgui_mod.addIncludePath(zglfw.path("libs/glfw/include"));
            }
            imgui_mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_glfw.cpp",
                    "libs/imgui/backends/imgui_impl_opengl3.cpp",
                },
                .flags = &(cflags.* ++ .{"-DIMGUI_IMPL_OPENGL_LOADER_CUSTOM"}),
            });
        },
        .glfw_dx12 => {
            if (b.lazyDependency("zglfw", .{})) |zglfw| {
                imgui_mod.addIncludePath(zglfw.path("libs/glfw/include"));
            }
            imgui_mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_glfw.cpp",
                    "libs/imgui/backends/imgui_impl_dx12.cpp",
                },
                .flags = cflags,
            });
            imgui_mod.linkSystemLibrary("d3dcompiler_47", .{});
        },
        .win32_dx12 => {
            imgui_mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_win32.cpp",
                    "libs/imgui/backends/imgui_impl_dx12.cpp",
                },
                .flags = cflags,
            });
            imgui_mod.linkSystemLibrary("d3dcompiler_47", .{});
            imgui_mod.linkSystemLibrary("dwmapi", .{});
            switch (target.result.abi) {
                .msvc => imgui_mod.linkSystemLibrary("Gdi32", .{}),
                .gnu => imgui_mod.linkSystemLibrary("gdi32", .{}),
                else => {},
            }
        },
        .glfw_vulkan => {
            if (b.lazyDependency("zglfw", .{})) |zglfw| {
                imgui_mod.addIncludePath(zglfw.path("libs/glfw/include"));
            }
            const sdk_env = std.process.getEnvVarOwned(b.allocator, "VULKAN_SDK") catch |err| switch (err) {
                error.EnvironmentVariableNotFound => null,
                else => {
                    std.debug.print("Failed to get VULKAN_SDK: {s}\n", .{@errorName(err)});
                    @panic("Unexpected error reading environment variable");
                },
            };

            if (options.vulkan_include) |path| {
                imgui_mod.addSystemIncludePath(.{ .cwd_relative = path });
            } else if (sdk_env) |sdk| {
                const vulkan_include = b.pathJoin(&.{ sdk, "include" });
                imgui_mod.addSystemIncludePath(.{ .cwd_relative = vulkan_include });
            } else {
                std.debug.print(
                    \\Error: Vulkan headers not found for glfw_vulkan backend.
                    \\Please either:
                    \\  1. Set the VULKAN_SDK environment variable.
                    \\  2. Pass the path: -Dvulkan_include="C:/path/to/vulkan/include"
                , .{});
                @panic("Vulkan SDK not found");
            }

            imgui_mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_glfw.cpp",
                    "libs/imgui/backends/imgui_impl_vulkan.cpp",
                },
                .flags = &(cflags.* ++ .{ "-DVK_NO_PROTOTYPES", "-DZGUI_DEGAMMA" }),
            });
        },
        .glfw => {
            if (b.lazyDependency("zglfw", .{})) |zglfw| {
                imgui_mod.addIncludePath(zglfw.path("libs/glfw/include"));
            }
            imgui_mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_glfw.cpp",
                },
                .flags = cflags,
            });
        },
        .sdl2_opengl3 => {
            if (b.lazyDependency("zsdl", .{})) |zsdl| {
                imgui_mod.addIncludePath(zsdl.path("libs/sdl2/include"));
            }
            imgui_mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_opengl3_loader.h",
                    "libs/imgui/backends/imgui_impl_sdl2.cpp",
                    "libs/imgui/backends/imgui_impl_opengl3.cpp",
                },
                .flags = &(cflags.* ++ .{"-DIMGUI_IMPL_OPENGL_LOADER_IMGL3W"}),
            });
        },
        .osx_metal => {
            imgui_mod.linkFramework("Foundation", .{});
            imgui_mod.linkFramework("Metal", .{});
            imgui_mod.linkFramework("Cocoa", .{});
            imgui_mod.linkFramework("QuartzCore", .{});
            imgui_mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_osx.mm",
                    "libs/imgui/backends/imgui_impl_metal.mm",
                },
                .flags = objcflags,
            });
        },
        .sdl2 => {
            if (b.lazyDependency("zsdl", .{})) |zsdl| {
                imgui_mod.addIncludePath(zsdl.path("libs/sdl2/include"));
            }
            imgui_mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_sdl2.cpp",
                },
                .flags = cflags,
            });
        },
        .sdl2_renderer => {
            if (b.lazyDependency("zsdl", .{})) |zsdl| {
                imgui_mod.addIncludePath(zsdl.path("libs/sdl2/include"));
            }
            imgui_mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_sdl2.cpp",
                    "libs/imgui/backends/imgui_impl_sdlrenderer2.cpp",
                },
                .flags = cflags,
            });
        },
        .sdl3_gpu => {
            if (b.lazyDependency("zsdl", .{})) |zsdl| {
                imgui_mod.addIncludePath(zsdl.path("libs/sdl3/include"));
            }
            imgui_mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_sdl3.cpp",
                    "libs/imgui/backends/imgui_impl_sdlgpu3.cpp",
                },
                .flags = cflags,
            });
        },
        .sdl3_renderer => {
            if (b.lazyDependency("zsdl", .{})) |zsdl| {
                imgui_mod.addIncludePath(zsdl.path("libs/sdl3/include"));
            }
            imgui_mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_sdl3.cpp",
                    "libs/imgui/backends/imgui_impl_sdlrenderer3.cpp",
                },
                .flags = cflags,
            });
        },
        .sdl3_opengl3 => {
            if (b.lazyDependency("zsdl", .{})) |zsdl| {
                imgui_mod.addIncludePath(zsdl.path("libs/sdl3/include/SDL3"));
            }
            imgui_mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_sdl3.cpp",
                    "libs/imgui/backends/imgui_impl_opengl3.cpp",
                },
                .flags = &(cflags.* ++ .{"-DIMGUI_IMPL_OPENGL_LOADER_IMGL3W"}),
            });
        },
        .sdl3_vulkan => {
            if (b.lazyDependency("zsdl", .{})) |zsdl| {
                imgui_mod.addIncludePath(zsdl.path("libs/sdl3/include"));
            }
            const sdk_env = std.process.getEnvVarOwned(b.allocator, "VULKAN_SDK") catch |err| switch (err) {
                error.EnvironmentVariableNotFound => null,
                else => {
                    std.debug.print("Failed to get VULKAN_SDK: {s}\n", .{@errorName(err)});
                    @panic("Unexpected error reading environment variable");
                },
            };

            if (options.vulkan_include) |path| {
                imgui_mod.addSystemIncludePath(.{ .cwd_relative = path });
            } else if (sdk_env) |sdk| {
                const vulkan_include = b.pathJoin(&.{ sdk, "include" });
                imgui_mod.addSystemIncludePath(.{ .cwd_relative = vulkan_include });
            } else {
                std.debug.print(
                    \\Error: Vulkan headers not found for sdl3_vulkan backend.
                    \\Please either:
                    \\  1. Set the VULKAN_SDK environment variable.
                    \\  2. Pass the path: -Dvulkan_include="C:/path/to/vulkan/include"
                , .{});
                @panic("Vulkan SDK not found");
            }

            imgui_mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_sdl3.cpp",
                    "libs/imgui/backends/imgui_impl_vulkan.cpp",
                },
                .flags = &(cflags.* ++ .{"-DVK_NO_PROTOTYPES"}),
            });
        },
        .sdl3 => {
            if (b.lazyDependency("zsdl", .{})) |zsdl| {
                imgui_mod.addIncludePath(zsdl.path("libs/sdl3/include"));
            }
            imgui_mod.addCSourceFiles(.{
                .files = &.{
                    "libs/imgui/backends/imgui_impl_sdl3.cpp",
                },
                .flags = cflags,
            });
        },
        .no_backend => {},
    }

    if (target.result.os.tag == .macos) {
        if (b.lazyDependency("system_sdk", .{})) |system_sdk| {
            imgui_mod.addSystemIncludePath(system_sdk.path("macos12/usr/include"));
            imgui_mod.addFrameworkPath(system_sdk.path("macos12/System/Library/Frameworks"));
        }
    } else if (target.result.os.tag == .linux) {
        if (b.lazyDependency("system_sdk", .{})) |system_sdk| {
            imgui_mod.addSystemIncludePath(system_sdk.path("linux/include"));
        }
    }

    const test_step = b.step("test", "Run zgui tests");

    const tests = b.addTest(.{
        .name = "zgui-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gui.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(tests);

    tests.root_module.addImport("zgui_options", options_module);
    tests.root_module.linkLibrary(imgui);

    test_step.dependOn(&b.addRunArtifact(tests).step);
}
