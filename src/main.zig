const rl = @import("raylib");
const std = @import("std");
const PlayingCard = @import("playingcard.zig").PlayingCard;
const CardOverlay = @import("cardoverlay.zig").CardOverlay;
const Cutscene = @import("cutscenes.zig").Cutscene;
const CutsceneManager = @import("cutscenes.zig").CutsceneManager;
const ToastManager = @import("toasts.zig").ToastManager;
const Deck = @import("deck.zig").Deck;
const Hand = @import("hand.zig").Hand;

const GameState = struct {
    deck: Deck,
    hand: Hand,
    cardoverlay: CardOverlay,
    toastmanager: ToastManager,
    cutscenemanager: CutsceneManager,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !GameState {
        var deck = try Deck.init(allocator);
        deck.shuffle();

        var hand = Hand.init(allocator);
        try hand.drawRandomHand(&deck);

        const cardoverlay = CardOverlay.init();

        const toastmanager = try ToastManager.init(allocator);

        var cutscenemanager = try CutsceneManager.init(allocator);
        try cutscenemanager.preloadResources();

        return GameState{
            .deck = deck,
            .hand = hand,
            .toastmanager = toastmanager,
            .allocator = allocator,
            .cutscenemanager = cutscenemanager,
            .cardoverlay = cardoverlay,
        };
    }

    pub fn deinit(self: *GameState) void {
        self.deck.deinit();
        self.hand.deinit();
        self.cardoverlay.deinit();
        self.cutscenemanager.deinit();
        self.toastmanager.deinit();
    }

    pub fn update(self: *GameState) !void {
        self.hand.update();
        self.cardoverlay.update(self.hand.cards.items[self.hand.current_card_index]);

        if (rl.isKeyPressed(.space)) {
            if (!self.cutscenemanager.is_playing) {
                try self.deck.reset();
                try self.hand.drawRandomHand(&self.deck);
            }
        }

        if (rl.isKeyPressed(.left_shift)) {
            try self.toastmanager.show(
                null, // image path
                "Achievement!", // title
                "rare", // priority (can be null)
                "SOME REALLY LONG TEXT! THIS SHOULD IDEALLY BE WRAPPED PLEASE BE WRAPPED I BEG TO YOU", // message
            );
        }

        if (rl.isKeyPressed(.left_alt)) {
            try self.toastmanager.show(
                "assets/ice.png", // image path
                "Uh oh!",
                "error", // priority (can be null)
                "You did a small little fucky wucky, dumb idiot!", // message
            );
        }

        if (rl.isKeyPressed(.left_control)) {
            try self.toastmanager.show(
                "assets/water.png", // image path
                "normal title",
                "normal", // priority (can be null)
                "well you are fine just continue with the game", // message
            );
        }

        if (rl.isKeyPressed(.m)) {
            var cutscenes = std.ArrayList(Cutscene).init(self.allocator);
            const cutscene = try self.cutscenemanager.createCutscene("assets/valkyrie.png", "Kaitlyn", "Welcome to ascendant! I am Commander, your helper and guide throughout this mission", rl.Color.dark_blue);
            try cutscenes.append(cutscene);

            const cutscene2 = try self.cutscenemanager.createCutscene("assets/valkyrie.png", "Katlyn", "Press space to continue...", rl.Color.dark_blue);
            try cutscenes.append(cutscene2);
            self.cutscenemanager.sequence(cutscenes);
        }

        self.toastmanager.update();
        self.cutscenemanager.update();
    }

    pub fn draw(self: *GameState) !void {
        self.deck.draw();
        self.hand.draw();
        self.cardoverlay.draw();
        self.toastmanager.draw();
        try self.cutscenemanager.draw();
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const screenWidth = 1900;
    const screenHeight = 960;
    const flags = rl.ConfigFlags{ .msaa_4x_hint = true };
    rl.setConfigFlags(flags);

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

        try game_state.draw();

        rl.drawFPS(10, 10);
    }
}
