const rl = @import("raylib");
const std = @import("std");

pub fn main() anyerror!void {
    const screenWidth = 1000;
    const screenHeight = 650;

    rl.initWindow(screenWidth, screenHeight, "Ascendant");
    defer rl.closeWindow(); // Close window and OpenGL context

    const vsPath = "src/shaders/lines.vs";
    const fsPath = "src/shaders/lines.fs";

    const shdrZigzag: rl.Shader = try rl.loadShader(vsPath, fsPath);
    defer rl.unloadShader(shdrZigzag);

    var time: f32 = 0.0;
    const screenSize = rl.Vector2.init(
        @as(f32, @floatFromInt(screenWidth)),
        @as(f32, @floatFromInt(screenHeight)),
    );

    const timeLoc = rl.getShaderLocation(shdrZigzag, "time");
    const screenSizeLoc = rl.getShaderLocation(shdrZigzag, "resolution");

    rl.setShaderValue(
        shdrZigzag,
        timeLoc,
        &time,
        .float,
    );
    rl.setShaderValue(
        shdrZigzag,
        screenSizeLoc,
        &screenSize,
        .vec2,
    );

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    while (!rl.windowShouldClose()) {
        time += rl.getFrameTime();
        rl.setShaderValue(
            shdrZigzag,
            timeLoc,
            &time,
            .float,
        );

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.ray_white);

        {
            rl.beginShaderMode(shdrZigzag);
            defer rl.endShaderMode();

            rl.drawRectangle(0, 0, screenWidth, screenHeight, rl.Color.white);
        }

        rl.drawFPS(910, 10);
    }
}
