const rl = @import("raylib");
const std = @import("std");
const PlayingCard = @import("playingcard.zig").PlayingCard;
const CardOverlay = @import("cardoverlay.zig").CardOverlay;
const ToastManager = @import("toasts.zig").ToastManager;
const Deck = @import("deck.zig").Deck;
const Hand = @import("hand.zig").Hand;

const GameState = struct {
    deck: Deck,
    hand: Hand,
    cardoverlay: CardOverlay,
    toastmanager: ToastManager,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !GameState {
        var deck = try Deck.init(allocator);
        deck.shuffle();

        var hand = Hand.init(allocator);
        try hand.drawRandomHand(&deck);

        const cardoverlay = CardOverlay.init();

        const toastmanager = ToastManager.init(allocator);

        return GameState{
            .deck = deck,
            .hand = hand,
            .toastmanager = toastmanager,
            .allocator = allocator,
            .cardoverlay = cardoverlay,
        };
    }

    pub fn deinit(self: *GameState) void {
        self.deck.deinit();
        self.hand.deinit();
        self.cardoverlay.deinit();
        self.toastmanager.deinit();
    }

    pub fn update(self: *GameState) !void {
        self.hand.update();
        self.cardoverlay.update(self.hand.cards.items[self.hand.current_card_index]);

        if (rl.isKeyPressed(.space)) {
            try self.deck.reset();
            try self.hand.drawRandomHand(&self.deck);
            try self.toastmanager.show(
                null, // image path
                "Achievement!", // title
                "rare", // priority (can be null)
                "You did it!", // message
            );
        }

        self.toastmanager.update();
    }

    pub fn draw(self: *GameState) void {
        self.deck.draw();
        self.hand.draw();
        self.cardoverlay.draw();
        self.toastmanager.draw();
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const screenWidth = 1920;
    const screenHeight = 1080;
    rl.initWindow(screenWidth, screenHeight, "Ascendant");
    rl.toggleBorderlessWindowed();
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

        rl.drawFPS(10, 10);
    }
}
