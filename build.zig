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
        if (options.use_32bit_draw_idx) "-DIMGUI_USE_32BIT_DRAW_INDEX" else "",
    };

    const objcflags = &.{
        "-Wno-deprecated",
        "-Wno-pedantic",
        "-Wno-availability",
    };

    const imgui_dep = b.dependency("imgui", .{
        .target = target,
        .optimize = optimize,
    });

    const imgui_mod =  b.addModule("imgui", .{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });

    const imgui = b.addLibrary(.{
        .name = "imgui",
        .root_module = imgui_mod,
    });

    imgui.addCSourceFiles(.{
        .root = imgui_dep.path(""),
        .files = &.{
            "imgui.cpp",
            "imgui_widgets.cpp",
            "imgui_tables.cpp",
            "imgui_draw.cpp",
            "imgui_demo.cpp",
            //TODO <tonitch>: add the backend from option
        },
        .flags = cflags,
    });
    imgui.installHeadersDirectory(imgui_dep.path(""), "imgui", .{});

   const cimgui_dep = b.dependency("cimgui", .{
        .target = target,
        .optimize = optimize,
    });

    const cimgui_mod = b.addModule("cimgui", .{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });

    const cimgui = b.addLibrary(.{
        .name = "cimgui",
        .root_module = cimgui_mod,
    });

    cimgui.linkLibrary(imgui);
    cimgui.addCSourceFile(.{
        .file = cimgui_dep.path("cimgui.cpp"),
    });
    cimgui.installHeadersDirectory(cimgui_dep.path(""), "", .{});

    // b.installArtifact(cimgui);

    if (options.with_freetype) {
        if (b.lazyDependency("freetype", .{})) |freetype| {
            imgui.linkLibrary(freetype.artifact("freetype"));
        }
        imgui.addCSourceFile(.{
            .file = imgui_dep.path("misc/freetype/imgui_freetype.cpp"),
            .flags = cflags,
        });
        imgui.root_module.addCMacro("IMGUI_ENABLE_FREETYPE", "1");
    }

    if (options.use_wchar32) {
        imgui.root_module.addCMacro("IMGUI_USE_WCHAR32", "1");
    }

    if (options.with_implot) {
        imgui.addIncludePath(b.path("libs/implot"));

        imgui.addCSourceFile(.{
            .file = b.path("src/zplot.cpp"),
            .flags = cflags,
        });

        imgui.addCSourceFiles(.{
            .files = &.{
                "libs/implot/implot_demo.cpp",
                "libs/implot/implot.cpp",
                "libs/implot/implot_items.cpp",
            },
            .flags = cflags,
        });
    }

    if (options.with_gizmo) {
        imgui.addIncludePath(b.path("libs/imguizmo/"));

        imgui.addCSourceFile(.{
            .file = b.path("src/zgizmo.cpp"),
            .flags = cflags,
        });

        imgui.addCSourceFiles(.{
            .files = &.{
                "libs/imguizmo/ImGuizmo.cpp",
            },
            .flags = cflags,
        });
    }

    if (options.with_node_editor) {
        imgui.addCSourceFile(.{
            .file = b.path("src/znode_editor.cpp"),
            .flags = cflags,
        });

        imgui.addCSourceFile(.{ .file = b.path("libs/node_editor/crude_json.cpp"), .flags = cflags });
        imgui.addCSourceFile(.{ .file = b.path("libs/node_editor/imgui_canvas.cpp"), .flags = cflags });
        imgui.addCSourceFile(.{ .file = b.path("libs/node_editor/imgui_node_editor_api.cpp"), .flags = cflags });
        imgui.addCSourceFile(.{ .file = b.path("libs/node_editor/imgui_node_editor.cpp"), .flags = cflags });
    }

    if (options.with_te) {
        imgui.addCSourceFile(.{
            .file = b.path("src/zte.cpp"),
            .flags = cflags,
        });

        imgui.root_module.addCMacro("IMGUI_ENABLE_TEST_ENGINE", "");
        imgui.root_module.addCMacro("IMGUI_TEST_ENGINE_ENABLE_COROUTINE_STDTHREAD_IMPL", "1");

        imgui.addIncludePath(b.path("libs/imgui_test_engine/"));

        imgui.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_capture_tool.cpp"), .flags = cflags });
        imgui.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_context.cpp"), .flags = cflags });
        imgui.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_coroutine.cpp"), .flags = cflags });
        imgui.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_engine.cpp"), .flags = cflags });
        imgui.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_exporters.cpp"), .flags = cflags });
        imgui.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_perftool.cpp"), .flags = cflags });
        imgui.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_ui.cpp"), .flags = cflags });
        imgui.addCSourceFile(.{ .file = b.path("libs/imgui_test_engine/imgui_te_utils.cpp"), .flags = cflags });
    }

    const emscripten = target.result.os.tag == .emscripten;

    imgui.addIncludePath(imgui_dep.path("")); //For backend to find imgui.h
    switch (options.backend) {
        .glfw_wgpu => {
            if (emscripten) {
                imgui.addSystemIncludePath(.{
                    .cwd_relative = b.pathJoin(&.{ b.sysroot.?, "include" }),
                });
            } else {
                if (b.lazyDependency("zglfw", .{})) |zglfw| {
                    imgui.addIncludePath(zglfw.path("libs/glfw/include"));
                }
                if (b.lazyDependency("zgpu", .{})) |zgpu| {
                    imgui.addIncludePath(zgpu.path("libs/dawn/include"));
                }
            }
            imgui.addCSourceFiles(.{
                .root = imgui_dep.path(""),
                .files = &.{
                    "backends/imgui_impl_glfw.cpp",
                    "backends/imgui_impl_wgpu.cpp",
                },
                .flags = cflags,
            });
        },
        .glfw_opengl3 => {
            if (b.lazyDependency("zglfw", .{})) |zglfw| {
                imgui.addIncludePath(zglfw.path("libs/glfw/include"));
            }
            imgui.addCSourceFiles(.{
                .root = imgui_dep.path(""),
                .files = &.{
                    "backends/imgui_impl_glfw.cpp",
                    "backends/imgui_impl_opengl3.cpp",
                },
                .flags = &(cflags.* ++ .{"-DIMGUI_IMPL_OPENGL_LOADER_CUSTOM"}),
            });
        },
        .glfw_dx12 => {
            if (b.lazyDependency("zglfw", .{})) |zglfw| {
                imgui.addIncludePath(zglfw.path("libs/glfw/include"));
            }
            imgui.addCSourceFiles(.{
                .root = imgui_dep.path(""),
                .files = &.{
                    "backends/imgui_impl_glfw.cpp",
                    "backends/imgui_impl_dx12.cpp",
                },
                .flags = cflags,
            });
            imgui.linkSystemLibrary("d3dcompiler_47");
        },
        .win32_dx12 => {
            imgui.addCSourceFiles(.{
                .root = imgui_dep.path(""),
                .files = &.{
                    "backends/imgui_impl_win32.cpp",
                    "backends/imgui_impl_dx12.cpp",
                },
                .flags = cflags,
            });
            imgui.linkSystemLibrary("d3dcompiler_47");
            imgui.linkSystemLibrary("dwmapi");
            switch (target.result.abi) {
                .msvc => imgui.linkSystemLibrary("Gdi32"),
                .gnu => imgui.linkSystemLibrary("gdi32"),
                else => {},
            }
        },
        .glfw_vulkan => {
            if (b.lazyDependency("zglfw", .{})) |zglfw| {
                imgui.addIncludePath(zglfw.path("libs/glfw/include"));
            }

            imgui.addCSourceFiles(.{
                .root = imgui_dep.path(""),
                .files = &.{
                    "backends/imgui_impl_glfw.cpp",
                    "backends/imgui_impl_vulkan.cpp",
                },
                .flags = &(cflags.* ++ .{ "-DVK_NO_PROTOTYPES", "-DZGUI_DEGAMMA" }),
            });
        },
        .glfw => {
            if (b.lazyDependency("zglfw", .{})) |zglfw| {
                imgui.addIncludePath(zglfw.path("libs/glfw/include"));
            }
            imgui.addCSourceFiles(.{
                .root = imgui_dep.path(""),
                .files = &.{
                    "backends/imgui_impl_glfw.cpp",
                },
                .flags = cflags,
            });
        },
        .sdl2_opengl3 => {
            if (b.lazyDependency("zsdl", .{})) |zsdl| {
                imgui.addIncludePath(zsdl.path("libs/sdl2/include"));
            }
            imgui.addCSourceFiles(.{
                .root = imgui_dep.path(""),
                .files = &.{
                    "backends/imgui_impl_opengl3_loader.h",
                    "backends/imgui_impl_sdl2.cpp",
                    "backends/imgui_impl_opengl3.cpp",
                },
                .flags = &(cflags.* ++ .{"-DIMGUI_IMPL_OPENGL_LOADER_IMGL3W"}),
            });
        },
        .osx_metal => {
            imgui.linkFramework("Foundation");
            imgui.linkFramework("Metal");
            imgui.linkFramework("Cocoa");
            imgui.linkFramework("QuartzCore");
            imgui.addCSourceFiles(.{
                .root = imgui_dep.path(""),
                .files = &.{
                    "backends/imgui_impl_osx.mm",
                    "backends/imgui_impl_metal.mm",
                },
                .flags = objcflags,
            });
        },
        .sdl2 => {
            if (b.lazyDependency("zsdl", .{})) |zsdl| {
                imgui.addIncludePath(zsdl.path("libs/sdl2/include"));
            }
            imgui.addCSourceFiles(.{
                .root = imgui_dep.path(""),
                .files = &.{
                    "backends/imgui_impl_sdl2.cpp",
                },
                .flags = cflags,
            });
        },
        .sdl2_renderer => {
            if (b.lazyDependency("zsdl", .{})) |zsdl| {
                imgui.addIncludePath(zsdl.path("libs/sdl2/include"));
            }
            imgui.addCSourceFiles(.{
                .root = imgui_dep.path(""),
                .files = &.{
                    "backends/imgui_impl_sdl2.cpp",
                    "backends/imgui_impl_sdlrenderer2.cpp",
                },
                .flags = cflags,
            });
        },
        .sdl3_gpu => {
            if (b.lazyDependency("zsdl", .{})) |zsdl| {
                imgui.addIncludePath(zsdl.path("libs/sdl3/include"));
            }
            imgui.addCSourceFiles(.{
                .root = imgui_dep.path(""),
                .files = &.{
                    "backends/imgui_impl_sdl3.cpp",
                    "backends/imgui_impl_sdlgpu3.cpp",
                },
                .flags = cflags,
            });
        },
        .sdl3_renderer => {
            if (b.lazyDependency("zsdl", .{})) |zsdl| {
                imgui.addIncludePath(zsdl.path("libs/sdl3/include"));
            }
            imgui.addCSourceFiles(.{
                .root = imgui_dep.path(""),
                .files = &.{
                    "backends/imgui_impl_sdl3.cpp",
                    "backends/imgui_impl_sdlrenderer3.cpp",
                },
                .flags = cflags,
            });
        },
        .sdl3_opengl3 => {
            if (b.lazyDependency("zsdl", .{})) |zsdl| {
                imgui.addIncludePath(zsdl.path("libs/sdl3/include/SDL3"));
            }
            imgui.addCSourceFiles(.{
                .root = imgui_dep.path(""),
                .files = &.{
                    "backends/imgui_impl_sdl3.cpp",
                    "backends/imgui_impl_opengl3.cpp",
                },
                .flags = &(cflags.* ++ .{"-DIMGUI_IMPL_OPENGL_LOADER_IMGL3W"}),
            });
        },
        .sdl3 => {
            if (b.lazyDependency("zsdl", .{})) |zsdl| {
                imgui.addIncludePath(zsdl.path("libs/sdl3/include"));
            }
            imgui.addCSourceFiles(.{
                .root = imgui_dep.path(""),
                .files = &.{
                    "backends/imgui_impl_sdl3.cpp",
                },
                .flags = cflags,
            });
        },
        .no_backend => {},
    }

    if (target.result.os.tag == .macos) {
        if (b.lazyDependency("system_sdk", .{})) |system_sdk| {
            imgui.addSystemIncludePath(system_sdk.path("macos12/usr/include"));
            imgui.addFrameworkPath(system_sdk.path("macos12/System/Library/Frameworks"));
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
    tests.linkLibrary(cimgui);
    tests.addIncludePath(cimgui_dep.path(""));

    test_step.dependOn(&b.addRunArtifact(tests).step);
}
