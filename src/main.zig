const rl = @import("raylib");
const std = @import("std");
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

    var game_state = try GameState.init(allocator);
    defer game_state.deinit();

    rl.setTargetFPS(144);

    while (!rl.windowShouldClose()) {
        try game_state.update();

        rl.beginDrawing();
        {
            rl.clearBackground(rl.Color.black);
            game_state.drawFinal();
            try game_state.draw();
            rl.drawFPS(10, 10);
        }
        rl.endDrawing();
    }
}
