const rl = @import("raylib");
const std = @import("std");
const PlayingCard = @import("playingcard.zig").PlayingCard;
const GameState = @import("gamestate.zig").GameState;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const screenWidth = 1280;
    const screenHeight = 720;
    const flags = rl.ConfigFlags{ .msaa_4x_hint = true };
    rl.setConfigFlags(flags);

    rl.initWindow(screenWidth, screenHeight, "Ascendant");
    defer rl.closeWindow();

    // crt shader
    const crtShader = try rl.loadShader("src/shaders/crt.vs", "src/shaders/crt.fs");
    const crtTimeLoc = rl.getShaderLocation(crtShader, "time");
    defer rl.unloadShader(crtShader);

    const renderTexture: rl.RenderTexture2D = try rl.loadRenderTexture(screenWidth, screenHeight);
    defer rl.unloadRenderTexture(renderTexture);

    var game_state = try GameState.init(allocator);
    defer game_state.deinit();

    rl.setTargetFPS(144);

    while (!rl.windowShouldClose()) {
        try game_state.update();

        rl.setShaderValue(crtShader, crtTimeLoc, &game_state.background.time, .float);

        rl.beginTextureMode(renderTexture);
        {
            rl.clearBackground(rl.Color.ray_white);
            try game_state.draw();
        }
        rl.endTextureMode();

        rl.beginDrawing();
        {
            rl.clearBackground(rl.Color.black);

            rl.beginShaderMode(crtShader);
            rl.drawTextureRec(renderTexture.texture, rl.Rectangle{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(renderTexture.texture.width),
                .height = @floatFromInt(renderTexture.texture.height),
            }, rl.Vector2{ .x = 0, .y = 0 }, rl.Color.white);
            rl.endShaderMode();

            rl.drawFPS(10, 10);
        }
        rl.endDrawing();
    }
}
