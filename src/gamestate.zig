const PlayingCard = @import("playingcard.zig").PlayingCard;
const rl = @import("raylib");
const std = @import("std");
const CardOverlay = @import("cardoverlay.zig").CardOverlay;
const Cutscene = @import("cutscenes.zig").Cutscene;
const CutsceneManager = @import("cutscenes.zig").CutsceneManager;
const ToastManager = @import("toasts.zig").ToastManager;
const Deck = @import("deck.zig").Deck;
const PowerCards = @import("powercards.zig").PowerCards;
const Hand = @import("hand.zig").Hand;
const Background = @import("background.zig").Background;
const CRTShader = @import("crtshader.zig").CRTShader;

pub const GameState = struct {
    deck: Deck,
    hand: Hand,
    power_cards: PowerCards,
    cardoverlay: CardOverlay,
    toastmanager: ToastManager,
    background: Background,
    cutscenemanager: CutsceneManager,
    crtshader: CRTShader,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !GameState {
        try PlayingCard.initResources();
        var deck = try Deck.init(allocator);
        deck.shuffle();

        var hand = Hand.init(allocator);
        try hand.drawRandomHand(&deck);

        var power_cards = try PowerCards.init(allocator);
        try power_cards.loadResources();

        const cardoverlay = CardOverlay.init();
        const toastmanager = try ToastManager.init(allocator);
        var cutscenemanager = try CutsceneManager.init(allocator);
        try cutscenemanager.preloadResources();

        const background = try Background.init(rl.getScreenWidth(), rl.getScreenHeight());
        const crtshader = try CRTShader.init(rl.getScreenWidth(), rl.getScreenHeight());

        return GameState{
            .deck = deck,
            .background = background,
            .hand = hand,
            .power_cards = power_cards,
            .toastmanager = toastmanager,
            .allocator = allocator,
            .cutscenemanager = cutscenemanager,
            .cardoverlay = cardoverlay,
            .crtshader = crtshader,
        };
    }

    pub fn deinit(self: *GameState) void {
        self.deck.deinit();
        self.hand.deinit();
        self.power_cards.deinit();
        self.cardoverlay.deinit();
        self.cutscenemanager.deinit();
        self.toastmanager.deinit();
        self.background.deinit();
        self.crtshader.deinit();
        PlayingCard.deinitResources();
    }

    pub fn update(self: *GameState) !void {
        const frame_time = rl.getFrameTime();
        try self.background.update(frame_time);
        self.hand.update();
        self.cardoverlay.update(self.hand.cards.items[self.hand.current_card_index]);
        self.crtshader.update(frame_time);

        if (rl.isKeyPressed(.up)) {
            const new_speed = self.crtshader.current_speed + 0.1;
            self.crtshader.setSpeed(new_speed);
        }
        if (rl.isKeyPressed(.down)) {
            const new_speed = @abs(@max(0.05, self.crtshader.current_speed - 0.1));
            self.crtshader.setSpeed(new_speed);
        }

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
                "assets/kaitlyn.jpg", // image path
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
            const cutscene = try self.cutscenemanager.createCutscene("assets/kaitlyn.jpg", "Kaitlyn", "Welcome to Ascendant! I am Kaitlyn, your helper and guide throughout this mission.", rl.Color.sky_blue);
            try cutscenes.append(cutscene);

            const cutscene1 = try self.cutscenemanager.createCutscene("assets/kaitlyn.jpg", "Kaitlyn", "The rules of this game are very simple. Fire beats Ice, Water Beats Fire and Ice beats Water. If the clans are same, the higher number wins. With each win you will get different powerups.", rl.Color.sky_blue);
            try cutscenes.append(cutscene1);

            const cutscene2 = try self.cutscenemanager.createCutscene("assets/kaitlyn.jpg", "Kaitlyn", "There are two ways to win the game. Either win three times with the same number with each clan. Or win three times with different number of any one clan.", rl.Color.sky_blue);
            try cutscenes.append(cutscene2);

            const cutscene3 = try self.cutscenemanager.createCutscene("assets/kaitlyn.jpg", "Kaitlyn", "Press space to continue...", rl.Color.sky_blue);
            try cutscenes.append(cutscene3);
            self.cutscenemanager.sequence(cutscenes);
        }

        if (rl.isKeyPressed(.q)) {
            try self.power_cards.addCard(&self.deck);
        }

        if (rl.isKeyPressed(.r)) {
            self.power_cards.reset();
        }

        if (rl.isKeyPressed(.one)) _ = self.power_cards.activateCard(0);
        if (rl.isKeyPressed(.two)) _ = self.power_cards.activateCard(1);

        self.toastmanager.update();
        self.cutscenemanager.update();
    }

    pub fn draw(self: *GameState) !void {
        self.crtshader.beginRender();

        self.background.draw(rl.getScreenWidth(), rl.getScreenHeight());
        self.deck.draw();
        self.hand.draw();
        self.cardoverlay.draw();
        self.toastmanager.draw();
        self.power_cards.draw();
        try self.cutscenemanager.draw();

        rl.endTextureMode();
    }

    pub fn drawFinal(self: *GameState) void {
        self.crtshader.drawFinal();
    }
};
