const rl = @import("raylib");
const std = @import("std");
const PlayingCard = @import("playingcard.zig").PlayingCard;

pub const Deck = struct {
    cards: std.ArrayList(PlayingCard),
    power_cards: std.ArrayList(PlayingCard),
    used_cards: std.ArrayList(PlayingCard),
    used_power_cards: std.ArrayList(PlayingCard),
    x: i32,
    y: i32,

    pub fn init(allocator: std.mem.Allocator) !Deck {
        var cards = std.ArrayList(PlayingCard).init(allocator);
        var power_cards = std.ArrayList(PlayingCard).init(allocator);
        const used_cards = std.ArrayList(PlayingCard).init(allocator);
        const used_power_cards = std.ArrayList(PlayingCard).init(allocator);

        const suits = [_][]const u8{ "fire", "water", "ice" };

        const normal_values = [_][]const u8{ "2", "3", "4", "5", "6", "7", "8", "9", "10" };
        for (suits) |suit| {
            for (normal_values) |value| {
                try cards.append(PlayingCard.init(value, suit, 300, 150));
            }
        }

        const power_values = [_][]const u8{ "j", "q", "k", "a" };
        for (suits) |suit| {
            for (power_values) |value| {
                try power_cards.append(PlayingCard.init(value, suit, 300, 150));
            }
        }

        try power_cards.append(PlayingCard.init("J", "1", 300, 150));
        try power_cards.append(PlayingCard.init("J", "2", 300, 150));

        return Deck{
            .cards = cards,
            .power_cards = power_cards,
            .used_cards = used_cards,
            .used_power_cards = used_power_cards,
            .x = @divTrunc(rl.getScreenWidth(), 4) - 50,
            .y = @divTrunc(rl.getScreenHeight(), 2) - 100,
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

        const card = self.cards.pop();
        try self.used_cards.append(card);
        return card;
    }

    pub fn drawPowerCard(self: *Deck) !?PlayingCard {
        if (self.power_cards.items.len == 0 and self.used_power_cards.items.len > 0) {
            try self.reset();
            if (self.power_cards.items.len == 0) return null;
        }
        if (self.power_cards.items.len == 0) return null;

        const card = self.power_cards.pop();
        try self.used_power_cards.append(card);
        return card;
    }

    pub fn reset(self: *Deck) !void {
        while (self.used_cards.items.len > 0) {
            var card = self.used_cards.pop();
            card.x = self.x;
            card.y = self.y;
            try self.cards.append(card);
        }

        while (self.used_power_cards.items.len > 0) {
            var card = self.used_power_cards.pop();
            card.x = self.x + 300;
            card.y = self.y;
            try self.power_cards.append(card);
        }

        self.shuffle();
    }

    pub fn draw(self: Deck) void {
        const visible_cards = 5;
        const offset: i32 = 2;

        var i: usize = 0;
        while (i < visible_cards) : (i += 1) {
            const card_y = self.y - @as(i32, @intCast(i)) + 10 * offset;
            var display_card = PlayingCard.init("", "", rl.getScreenWidth() - self.x, card_y - @as(i32, @intCast(i)) * 5);
            display_card.flip_progress = 1.0;
            display_card.draw();
        }

        i = 0;
        while (i < visible_cards) : (i += 1) {
            const card_y = self.y - @as(i32, @intCast(i)) + 10 * offset;
            var display_card = PlayingCard.init("", "", self.x, card_y - @as(i32, @intCast(i)) * 5);
            display_card.flip_progress = 1.0;
            display_card.is_power_card = true;
            display_card.draw();
        }
    }
};
