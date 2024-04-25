// raylib-zig (c) Nikolas Wipper 2020-2024

const std = @import("std");
const rl = @This();
const emcc = @import("emcc.zig");

const Program = struct {
    name: []const u8,
    path: []const u8,
    desc: []const u8,
};

pub fn link(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    target: std.zig.CrossTarget,
    optimize: std.builtin.Mode,
) void {
    const lib = getRaylib(b, target, optimize);

    const target_os = exe.rootModuleTarget().os.tag;
    switch (target_os) {
        .windows => {
            exe.linkSystemLibrary("winmm");
            exe.linkSystemLibrary("gdi32");
            exe.linkSystemLibrary("opengl32");
        },
        .macos => {
            exe.linkFramework("OpenGL");
            exe.linkFramework("Cocoa");
            exe.linkFramework("IOKit");
            exe.linkFramework("CoreAudio");
            exe.linkFramework("CoreVideo");
        },
        .freebsd, .openbsd, .netbsd, .dragonfly => {
            exe.linkSystemLibrary("GL");
            exe.linkSystemLibrary("rt");
            exe.linkSystemLibrary("dl");
            exe.linkSystemLibrary("m");
            exe.linkSystemLibrary("X11");
            exe.linkSystemLibrary("Xrandr");
            exe.linkSystemLibrary("Xinerama");
            exe.linkSystemLibrary("Xi");
            exe.linkSystemLibrary("Xxf86vm");
            exe.linkSystemLibrary("Xcursor");
        },
        .emscripten, .wasi => {
            // When using emscripten, the libries don't need to be linked
            // because emscripten is going to do that later.
        },
        else => { // Linux and possibly others.
            exe.linkSystemLibrary("GL");
            exe.linkSystemLibrary("rt");
            exe.linkSystemLibrary("dl");
            exe.linkSystemLibrary("m");
            exe.linkSystemLibrary("X11");
        },
    }

    exe.linkLibrary(lib);
}

var _raylib_lib_cache: ?*std.Build.Step.Compile = null;
pub fn getRaylib(
    b: *std.Build,
    target: std.zig.CrossTarget,
    optimize: std.builtin.Mode,
) *std.Build.Step.Compile {
    if (_raylib_lib_cache) |lib| return lib else {
        const raylib = b.dependency("raylib", .{
            .target = target,
            .optimize = optimize,
        });

        const lib = raylib.artifact("raylib");
        b.installArtifact(lib);
        _raylib_lib_cache = lib;
        return lib;
    }
}

// TODO: Make these not comptime.
pub fn getModule(b: *std.Build, comptime rl_path: []const u8) *std.Build.Module {
    if (b.modules.contains("raylib")) {
        return b.modules.get("raylib").?;
    }
    return b.addModule("raylib", .{ .root_source_file = .{ .path = rl_path ++ "/lib/raylib.zig" } });
}

fn getModuleInternal(b: *std.Build) *std.Build.Module {
    if (b.modules.contains("raylib")) {
        return b.modules.get("raylib").?;
    }
    return b.addModule("raylib", .{ .root_source_file = .{ .path = "lib/raylib.zig" } });
}

pub const math = struct {
    pub fn getModule(b: *std.Build, comptime rl_path: []const u8) *std.Build.Module {
        const raylib = rl.getModule(b, rl_path);
        const module = b.addModule("raylib-math", .{
            .root_source_file = .{ .path = rl_path ++ "/lib/raymath.zig" },
        });
        module.addImport("raylib-zig", raylib);
        return module;
    }

    fn getModuleInternal(b: *std.Build) *std.Build.Module {
        const raylib = rl.getModuleInternal(b);
        const module = b.addModule("raylib-math", .{
            .root_source_file = .{ .path = "lib/raymath.zig" },
        });
        module.addImport("raylib-zig", raylib);
        return module;
    }
};

pub const gl = struct {
    pub fn getModule(b: *std.Build, comptime rl_path: []const u8) *std.Build.Module {
        const raylib = rl.getModule(b, rl_path);
        const module = b.addModule("rlgl", .{
            .root_source_file = .{ .path = rl_path ++ "/lib/rlgl.zig" },
        });
        module.addImport("raylib-zig", raylib);
        return module;
    }

    fn getModuleInternal(b: *std.Build) *std.Build.Module {
        const raylib = rl.getModuleInternal(b);
        const module = b.addModule("rlgl", .{
            .root_source_file = .{ .path = "lib/rlgl.zig" },
        });
        module.addImport("raylib-zig", raylib);
        return module;
    }
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const examples = [_]Program{
        .{
            .name = "basic_screen_manager",
            .path = "examples/core/basic_screen_manager.zig",
            .desc = "Illustrates simple screen manager based on a state machine",
        },
        .{
            .name = "basic_window",
            .path = "examples/core/basic_window.zig",
            .desc = "Creates a basic window with text",
        },
        .{
            .name = "input_keys",
            .path = "examples/core/input_keys.zig",
            .desc = "Simple keyboard input",
        },
        .{
            .name = "input_mouse",
            .path = "examples/core/input_mouse.zig",
            .desc = "Simple mouse input",
        },
        .{
            .name = "input_mouse_wheel",
            .path = "examples/core/input_mouse_wheel.zig",
            .desc = "Mouse wheel input",
        },
        .{
            .name = "input_multitouch",
            .path = "examples/core/input_multitouch.zig",
            .desc = "Multitouch input",
        },
        .{
            .name = "2d_camera",
            .path = "examples/core/2d_camera.zig",
            .desc = "Shows the functionality of a 2D camera",
        },
        .{
            .name = "3d_camera_first_person",
            .path = "examples/core/3d_camera_first_person.zig",
            .desc = "Simple first person demo",
        },
        .{
            .name = "window_flags",
            .path = "examples/core/window_flags.zig",
            .desc = "Demonstrates various flags used during and after window creation",
        },
        .{
            .name = "texture_outline",
            .path = "examples/shaders/texture_outline.zig",
            .desc = "Uses a shader to create an outline around a sprite",
        },
        .{
            .name = "logo_raylib",
            .path = "examples/shapes/logo_raylib.zig",
            .desc = "Renders the raylib-zig logo",
        },
        .{
            .name = "sprite_anim",
            .path = "examples/textures/sprite_anim.zig",
            .desc = "Animate a sprite",
        },
        // .{
        //     .name = "models_loading",
        //     .path = "examples/models/models_loading.zig",
        //     .desc = "Loads a model and renders it",
        // },
        // .{
        //     .name = "shaders_basic_lighting",
        //     .path = "examples/shaders/shaders_basic_lighting.zig",
        //     .desc = "Loads a model and renders it",
        // },
    };

    const examples_step = b.step("examples", "Builds all the examples");

    const raylib = rl.getModuleInternal(b);
    const raylib_math = rl.math.getModuleInternal(b);
    const rlgl = rl.gl.getModuleInternal(b);

    const raylib_test = b.addTest(.{
        .root_source_file = .{ .path = "lib/raylib.zig" },
        .target = target,
        .optimize = optimize,
    });

    const raylib_math_test = b.addTest(.{
        .root_source_file = .{ .path = "lib/raymath.zig" },
        .target = target,
        .optimize = optimize,
    });
    raylib_math_test.root_module.addImport("raylib-zig", raylib);

    const rlgl_test = b.addTest(.{
        .root_source_file = .{ .path = "lib/rlgl.zig" },
        .target = target,
        .optimize = optimize,
    });
    rlgl_test.root_module.addImport("raylib-zig", raylib);

    const test_step = b.step("test", "Check for library compilation errors");
    test_step.dependOn(&raylib_test.step);
    test_step.dependOn(&raylib_math_test.step);
    test_step.dependOn(&rlgl_test.step);

    for (examples) |ex| {
        if (target.result.os.tag == .emscripten) {
            // const exe_lib = emcc.compileForEmscripten(b, ex.name, ex.path, target, optimize);
            // exe_lib.addModule("raylib", raylib);
            // exe_lib.addModule("raylib-math", raylib_math);
            // exe_lib.addModule("rlgl", rlgl);
            // const raylib_lib = getRaylib(b, target, optimize);
            //
            // // Note that raylib itself isn't actually added to the exe_lib
            // // output file, so it also needs to be linked with emscripten.
            // exe_lib.linkLibrary(raylib_lib);
            // const link_step = try emcc.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{ exe_lib, raylib_lib });
            // link_step.addArg("--embed-file");
            // link_step.addArg("resources/");
            //
            // const run_step = try emcc.emscriptenRunStep(b);
            // run_step.step.dependOn(&link_step.step);
            // const run_option = b.step(ex.name, ex.desc);
            // run_option.dependOn(&run_step.step);
        } else {
            const exe = b.addExecutable(.{
                .name = ex.name,
                .root_source_file = .{ .path = ex.path },
                .optimize = optimize,
                .target = target,
            });
            rl.link(b, exe, target.query, optimize);
            exe.root_module.addImport("raylib", raylib);
            exe.root_module.addImport("raylib-math", raylib_math);
            exe.root_module.addImport("rlgl", rlgl);
            const run_cmd = b.addRunArtifact(exe);
            const run_step = b.step(ex.name, ex.desc);
            run_step.dependOn(&run_cmd.step);
            examples_step.dependOn(&exe.step);
        }
    }
}
