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

pub const Bot = struct {
    hand: Hand,
    recent_played_cards: std.ArrayList(PlayingCard),
    deck: *Deck,
    wins: u32 = 0,
    health: u32 = 300,

    pub fn init(allocator: std.mem.Allocator, deck: *Deck) !Bot {
        var hand = Hand.init(allocator);
        try hand.drawRandomHand(deck, false);

        const recent_played_cards = std.ArrayList(PlayingCard).init(allocator);

        return Bot{
            .hand = hand,
            .recent_played_cards = recent_played_cards,
            .deck = deck,
        };
    }

    pub fn draw(self: *Bot) void {
        self.hand.draw();
    }

    pub fn playMove(self: *Bot, new_card: ?PlayingCard) !PlayingCard {
        // just play the first card in the hand (for now) and add the new card to the hand
        const played_card = self.hand.cards.items[0];
        try self.recent_played_cards.append(played_card);
        if (new_card != null and self.hand.cards.items.len > 0) {
            _ = self.hand.cards.orderedRemove(self.hand.current_card_index);
        }

        if (new_card) |n| {
            try self.hand.cards.append(n);
        } else {
            try self.deck.reset();
            if (try self.deck.drawCard()) |card| {
                try self.hand.cards.append(card);
            } else {
                rl.traceLog(.err, "Failed to draw a new card from the deck - deck is completely empty", .{});
            }
        }

        self.hand.updatePositions(false);

        return played_card;
    }

    pub fn deinit(self: *Bot) void {
        self.recent_played_cards.deinit();
        self.hand.deinit();
    }
};

pub const Player = struct {
    recent_played_cards: std.ArrayList(PlayingCard),
    power_cards: PowerCards,
    deck: *Deck,
    hand: Hand,
    health: u32 = 100,
    wins: u32 = 0,

    pub fn init(allocator: std.mem.Allocator, deck: *Deck) !Player {
        var hand = Hand.init(allocator);
        try hand.drawRandomHand(deck, true);

        var power_cards = try PowerCards.init(allocator);
        try power_cards.loadResources();

        const recent_played_cards = std.ArrayList(PlayingCard).init(allocator);

        return Player{
            .deck = deck,
            .power_cards = power_cards,
            .recent_played_cards = recent_played_cards,
            .hand = hand,
        };
    }

    pub fn deinit(self: *Player) void {
        self.recent_played_cards.deinit();
        self.hand.deinit();
        self.power_cards.deinit();
    }

    pub fn draw(self: *Player) void {
        self.hand.draw();
        self.power_cards.draw();

        // draw player HUD

    }
    pub fn playMove(self: *Player, new_card: ?PlayingCard) !PlayingCard {
        const played_card = self.hand.cards.items[self.hand.current_card_index];
        try self.recent_played_cards.append(played_card);
        if (new_card != null and self.hand.cards.items.len > 0) {
            _ = self.hand.cards.orderedRemove(self.hand.current_card_index);
        }

        if (new_card) |n| {
            try self.hand.cards.append(n);
        } else {
            try self.deck.reset();
            if (try self.deck.drawCard()) |card| {
                try self.hand.cards.append(card);
            } else {
                rl.traceLog(.err, "Failed to draw a new card from the deck - deck is completely empty", .{});
            }
        }

        self.hand.updatePositions(true);

        if (self.hand.cards.items.len > 0) {
            self.hand.current_card_index = @min(self.hand.current_card_index, self.hand.cards.items.len - 1);
        } else {
            self.hand.current_card_index = 0;
        }

        return played_card;
    }

    pub fn update(self: *Player) void {
        self.hand.update();
    }
};

pub const GameState = struct {
    deck: Deck,
    bot: Bot,
    player: Player,
    player_played_card: ?PlayingCard = null,
    bot_played_card: ?PlayingCard = null,
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

        const player = try Player.init(allocator, &deck);
        const bot = try Bot.init(allocator, &deck);

        const cardoverlay = CardOverlay.init();
        const toastmanager = try ToastManager.init(allocator);
        var cutscenemanager = try CutsceneManager.init(allocator);
        try cutscenemanager.preloadResources();

        const background = try Background.init(rl.getScreenWidth(), rl.getScreenHeight());
        const crtshader = try CRTShader.init(rl.getScreenWidth(), rl.getScreenHeight());

        return GameState{
            .bot = bot,
            .deck = deck,
            .background = background,
            .player = player,
            .toastmanager = toastmanager,
            .allocator = allocator,
            .cutscenemanager = cutscenemanager,
            .cardoverlay = cardoverlay,
            .crtshader = crtshader,
        };
    }

    pub fn deinit(self: *GameState) void {
        self.player.deinit();
        self.bot.deinit();
        self.deck.deinit();
        self.cardoverlay.deinit();
        self.cutscenemanager.deinit();
        self.toastmanager.deinit();
        self.background.deinit();
        self.crtshader.deinit();
        PlayingCard.deinitResources();
    }

    pub fn resetForNextRound(self: *GameState) void {
        self.player_played_card = null;
        self.bot_played_card = null;
    }

    pub fn processCards(self: *GameState) void {
        const player_suit = self.player_played_card.?.suit;
        const player_value = self.player_played_card.?.value;
        const bot_suit = self.bot_played_card.?.suit;
        const bot_value = self.bot_played_card.?.value;

        // joker instawin
        if (player_value == 15) {
            self.bot.health -= 5;
        } else if (bot_value == 15) {
            self.player.health -= 5;
        }

        if (player_suit == .fire and bot_suit == .ice) {
            self.bot.health -= 5;
        } else if (player_suit == .ice and bot_suit == .fire) {
            self.player.health -= 5;
        } else if (player_suit == .water and bot_suit == .fire) {
            self.bot.health -= 5;
        } else if (player_suit == .fire and bot_suit == .water) {
            self.player.health -= 5;
        } else if (player_suit == .ice and bot_suit == .water) {
            self.bot.health -= 5;
        } else if (player_suit == .water and bot_suit == .ice) {
            self.player.health -= 5;
        } else if (player_suit == bot_suit) {
            if (player_value > bot_value) {
                self.bot.health -= 5;
            } else if (player_value < bot_value) {
                self.player.health -= 5;
            }
        }
    }

    pub fn update(self: *GameState) !void {
        const frame_time = rl.getFrameTime();
        try self.background.update(frame_time);
        self.player.update();
        self.cardoverlay.update(self.player.hand.cards.items[self.player.hand.current_card_index]);
        self.crtshader.update(frame_time);

        if (rl.isKeyPressed(.four)) {
            try self.deck.reset();
            try self.player.hand.drawRandomHand(&self.deck, true);
        }

        if (rl.isKeyPressed(.space)) {
            if (!self.cutscenemanager.is_playing) {
                const card = try self.deck.drawCard();
                const play = try self.player.playMove(card);

                const card_for_bot = try self.deck.drawCard();
                const bot_play = try self.bot.playMove(card_for_bot);

                self.player_played_card = play;
                self.bot_played_card = bot_play;

                self.processCards();
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
            try self.player.power_cards.addCard(&self.deck);
        }

        if (rl.isKeyPressed(.r)) {
            self.player.power_cards.reset();
        }

        if (rl.isKeyPressed(.one)) _ = self.player.power_cards.activateCard(0);
        if (rl.isKeyPressed(.two)) _ = self.player.power_cards.activateCard(1);

        self.toastmanager.update();
        self.cutscenemanager.update();
    }

    pub fn draw(self: *GameState) !void {
        self.crtshader.beginRender();

        self.background.draw(rl.getScreenWidth(), rl.getScreenHeight());
        self.deck.draw();
        self.player.draw();
        self.bot.draw();
        self.cardoverlay.draw();
        self.toastmanager.draw();
        try self.cutscenemanager.draw();

        if (self.player_played_card) |card| {
            var mutable_card = card;
            mutable_card.setX(@divTrunc(rl.getScreenWidth(), 2) - 100);
            mutable_card.setY(@divTrunc(rl.getScreenHeight(), 2) - 100);
            mutable_card.setRotation(0);
            mutable_card.draw();
        }

        if (self.bot_played_card) |card| {
            var mutable_card = card;
            mutable_card.flip_progress = 0.0;
            mutable_card.setX(@divTrunc(rl.getScreenWidth(), 2));
            mutable_card.setY(@divTrunc(rl.getScreenHeight(), 2) - 100);
            mutable_card.setRotation(0);
            mutable_card.draw();
        }

        // draw the player and bot health
        var ph_buffer: [100]u8 = undefined;
        var bh_buffer: [100]u8 = undefined;

        const ph_text = try std.fmt.bufPrintZ(&ph_buffer, "Player Health: {d}", .{self.player.health});
        const bh_text = try std.fmt.bufPrintZ(&bh_buffer, "Bot Health: {d}", .{self.bot.health});

        rl.drawText(ph_text.ptr, 10, 10, 20, rl.Color.white);
        rl.drawText(bh_text.ptr, 10, 40, 20, rl.Color.white);
        rl.endTextureMode();
    }

    pub fn drawFinal(self: *GameState) void {
        self.crtshader.drawFinal();
    }
};
