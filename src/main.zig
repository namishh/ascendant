const rl = @import("raylib");
const std = @import("std");
const PlayingCard = @import("playingcard.zig").PlayingCard;

pub fn main() anyerror!void {
    const screenWidth = 1000;
    const screenHeight = 650;
    rl.initWindow(screenWidth, screenHeight, "Ascendant");
    defer rl.closeWindow();

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

    try PlayingCard.initResources();
    defer PlayingCard.deinitResources();

    // Create a sample playing card
    const card = PlayingCard.init("A", "spades", 450, 250);
    const card2 = PlayingCard.init("10", "diamonds", 300, 250);
    const card3 = PlayingCard.init("5", "clubs", 150, 250);
    const card4 = PlayingCard.init("k", "hearts", 600, 250);
    const card5 = PlayingCard.init("q", "spades", 750, 250);

    rl.setTargetFPS(60);
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

        // Draw the card
        card.draw();
        card2.draw();
        card3.draw();
        card4.draw();
        card5.draw();

        rl.drawFPS(910, 10);
    }
}
