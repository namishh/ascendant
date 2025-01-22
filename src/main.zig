const rl = @import("raylib");
const std = @import("std");
const PlayingCard = @import("playingcard.zig").PlayingCard;
const Deck = @import("deck.zig").Deck;
const Hand = @import("hand.zig").Hand;

const GameState = struct {
    deck: Deck,
    hand: Hand,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !GameState {
        var deck = try Deck.init(allocator);
        deck.shuffle();

        var hand = Hand.init(allocator);
        try hand.drawRandomHand(&deck);

        return GameState{
            .deck = deck,
            .hand = hand,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *GameState) void {
        self.deck.deinit();
        self.hand.deinit();
    }

    pub fn update(self: *GameState) !void {
        self.hand.update();

        if (rl.isKeyPressed(.space)) {
            try self.hand.drawRandomHand(&self.deck);
        }
    }

    pub fn draw(self: *GameState) void {
        self.deck.draw();
        self.hand.draw();
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const screenWidth = 1280;
    const screenHeight = 720;
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

    rl.setShaderValue(shdrZigzag, timeLoc, &time, .float);
    rl.setShaderValue(shdrZigzag, screenSizeLoc, &screenSize, .vec2);

    try PlayingCard.initResources();
    defer PlayingCard.deinitResources();

    // Initialize game state
    var game_state = try GameState.init(allocator);
    defer game_state.deinit();

    rl.setTargetFPS(144);

    while (!rl.windowShouldClose()) {
        time += rl.getFrameTime();
        rl.setShaderValue(shdrZigzag, timeLoc, &time, .float);
        try game_state.update();

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.ray_white);

        {
            rl.beginShaderMode(shdrZigzag);
            defer rl.endShaderMode();
            rl.drawRectangle(0, 0, screenWidth, screenHeight, rl.Color.white);
        }

        game_state.draw();

        rl.drawFPS(1190, 10);
    }
}
