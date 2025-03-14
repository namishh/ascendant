const rl = @import("raylib");
const std = @import("std");
const PlayingCard = @import("playingcard.zig").PlayingCard;
const Suit = @import("playingcard.zig").Suit;

pub const Deck = struct {
    cards: std.ArrayList(PlayingCard),
    power_cards: std.ArrayList(PlayingCard),
    used_cards: std.ArrayList(PlayingCard),
    used_power_cards: std.ArrayList(PlayingCard),
    x: f32,
    y: f32,

    pub fn init(allocator: std.mem.Allocator) !Deck {
        var cards = std.ArrayList(PlayingCard).init(allocator);
        var power_cards = std.ArrayList(PlayingCard).init(allocator);

        const suits = [_]Suit{ .fire, .water, .ice };

        for (suits) |suit| {
            for (2..11) |value| {
                try cards.append(PlayingCard.init(@intCast(value), suit, 300.0, 150.0));
            }
        }

        for (suits) |suit| {
            try power_cards.append(PlayingCard.init(11, suit, 300.0, 150.0));
            try power_cards.append(PlayingCard.init(12, suit, 300.0, 150.0));
            try power_cards.append(PlayingCard.init(13, suit, 300.0, 150.0));
            try power_cards.append(PlayingCard.init(14, suit, 300.0, 150.0));
        }

        try power_cards.append(PlayingCard.init(15, .fire, 300.0, 150.0));
        try power_cards.append(PlayingCard.init(15, .water, 300.0, 150.0));

        return Deck{
            .cards = cards,
            .power_cards = power_cards,
            .used_cards = std.ArrayList(PlayingCard).init(allocator),
            .used_power_cards = std.ArrayList(PlayingCard).init(allocator),
            .x = @floatFromInt(@divTrunc(rl.getScreenWidth(), 4) - 50),
            .y = @floatFromInt(@divTrunc(rl.getScreenHeight(), 2) - 100),
        };
    }

    pub fn deinit(self: *Deck) void {
        self.cards.deinit();
        self.power_cards.deinit();
        self.used_cards.deinit();
        self.used_power_cards.deinit();
    }

    pub fn updateCardPositions(self: *Deck) void {
        for (self.cards.items) |*card| {
            card.x = self.x;
            card.y = self.y;
            card.target_x = self.x;
            card.target_y = self.y;
        }
    }

    pub fn shuffle(self: *Deck) void {
        var rng = std.rand.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        var rand = rng.random();

        var i: usize = self.cards.items.len;
        while (i > 1) {
            i -= 1;
            const j = rand.uintLessThan(usize, i + 1);
            const temp = self.cards.items[i];
            self.cards.items[i] = self.cards.items[j];
            self.cards.items[j] = temp;
        }

        i = self.power_cards.items.len;
        while (i > 1) {
            i -= 1;
            const j = rand.uintLessThan(usize, i + 1);
            const temp = self.power_cards.items[i];
            self.power_cards.items[i] = self.power_cards.items[j];
            self.power_cards.items[j] = temp;
        }

        self.updateCardPositions();
    }

    pub fn drawCard(self: *Deck) !?PlayingCard {
        if (self.cards.items.len == 0 and self.used_cards.items.len > 0) {
            try self.reset();
            if (self.cards.items.len == 0) return null;
        }
        if (self.cards.items.len == 0) return null;

        var card = self.cards.pop();
        card.x = @as(f32, @floatFromInt(rl.getScreenWidth())) - self.x;
        card.y = self.y; // e.g., 260
        try self.used_cards.append(card);
        return card;
    }

    pub fn drawPowerCard(self: *Deck) !?PlayingCard {
        if (self.power_cards.items.len == 0 and self.used_power_cards.items.len > 0) {
            try self.reset();
            if (self.power_cards.items.len == 0) return null;
        }
        if (self.power_cards.items.len == 0) return null;

        var card = self.power_cards.pop();
        card.x = self.x - 50.0; // Matches draw logic, e.g., 270 - 50 = 220
        card.y = self.y; // e.g., 260
        try self.used_power_cards.append(card);
        return card;
    }

    pub fn reset(self: *Deck) !void {
        while (self.used_cards.items.len > 0) {
            var card = self.used_cards.pop();
            card.x = self.x;
            card.y = self.y;
            card.target_x = self.x;
            card.target_y = self.y;
            try self.cards.append(card);
        }

        while (self.used_power_cards.items.len > 0) {
            var card = self.used_power_cards.pop();
            card.x = self.x + 300.0;
            card.y = self.y;
            card.target_x = self.x + 300.0;
            card.target_y = self.y;
            try self.power_cards.append(card);
        }

        self.shuffle();
    }

    pub fn draw(self: Deck) void {
        const visible_cards = 5;
        const offset: i32 = 2;

        var i: usize = 0;
        while (i < visible_cards and i < self.cards.items.len) : (i += 1) {
            const card_y = self.y - @as(f32, @floatFromInt(i)) + 10.0 * @as(f32, @floatFromInt(offset));
            var display_card = PlayingCard.init(self.cards.items[i].value, self.cards.items[i].suit, @as(f32, @floatFromInt(rl.getScreenWidth())) - self.x, card_y - @as(f32, @floatFromInt(i)) * 5.0);
            display_card.flip_progress = 1.0;
            display_card.draw();
        }

        i = 0;
        while (i < 2 and i < self.power_cards.items.len) : (i += 1) {
            const card_y = self.y - @as(f32, @floatFromInt(i)) + 5.0 * @as(f32, @floatFromInt(offset));
            var display_card = PlayingCard.init(self.power_cards.items[i].value, self.power_cards.items[i].suit, self.x - 50.0, card_y - @as(f32, @floatFromInt(i)) * 5.0);
            display_card.flip_progress = 1.0;
            display_card.height = 92;
            display_card.width = 69;
            display_card.is_power_card = true;
            display_card.draw();
        }
    }
};
