const PlayingCard = @import("playingcard.zig").PlayingCard;
const rl = @import("raylib");
const std = @import("std");
const Deck = @import("deck.zig").Deck;

pub const Hand = struct {
    cards: std.ArrayList(PlayingCard),
    current_card_index: usize = 0,
    spacing: i32 = 70,
    hover_lift: f32 = -20.0,

    pub fn init(allocator: std.mem.Allocator) Hand {
        return Hand{
            .cards = std.ArrayList(PlayingCard).init(allocator),
        };
    }

    pub fn deinit(self: *Hand) void {
        self.cards.deinit();
    }

    pub fn drawRandomHand(self: *Hand, deck: *Deck, player: bool) !void {
        if (!player) {
            self.hover_lift = 20.0;
        }
        self.cards.clearRetainingCapacity();
        self.current_card_index = 0;
        const num_cards = @as(i32, @intCast(5));

        const window_width = rl.getScreenWidth();
        const window_height = rl.getScreenHeight();
        const card_width = 100;
        const total_width = (num_cards - 1) * self.spacing + card_width;
        const start_x = @divTrunc(window_width - total_width, 2);
        var base_y = window_height - 200;
        if (!player) {
            base_y = 40;
        }
        var i: usize = 0;
        while (i < num_cards) : (i += 1) {
            if (try deck.drawCard()) |card| {
                var new_card = card;
                const progress = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(num_cards - 1));
                const angle = -15.0 + progress * 30.0;
                const x = start_x + @as(i32, @intCast(i)) * self.spacing;
                const relative_x = @as(f32, @floatFromInt(x - (start_x + @divTrunc(total_width, 2))));
                var y = base_y + @as(i32, @intFromFloat((relative_x * relative_x) / 5000.0));
                if (!player) {
                    y += base_y - @as(i32, @intFromFloat((relative_x * relative_x) / 5000.0));
                    new_card.flip_progress = 1.0;
                }
                new_card.x = x;
                new_card.y = y;
                new_card.base_y = y;
                new_card.rotation = angle;
                new_card.hover_offset = self.hover_lift;
                try self.cards.append(new_card);
            } else break;
        }
    }

    pub fn update(self: *Hand) void {
        for (self.cards.items) |*card| {
            card.is_hovered = false;
        }

        if (self.cards.items.len > 0) {
            self.cards.items[self.current_card_index].is_hovered = true;
        }

        if (rl.isKeyPressed(.a)) {
            self.cyclePrevCard();
        }
        if (rl.isKeyPressed(.d)) {
            self.cycleNextCard();
        }

        for (self.cards.items) |*card| {
            card.is_current = (self.cards.items.len > 0 and card == &self.cards.items[self.current_card_index]);
            card.update();
        }
    }

    fn cyclePrevCard(self: *Hand) void {
        if (self.cards.items.len == 0) return;
        self.current_card_index = if (self.current_card_index == 0)
            self.cards.items.len - 1
        else
            self.current_card_index - 1;
    }

    fn cycleNextCard(self: *Hand) void {
        if (self.cards.items.len == 0) return;
        self.current_card_index = (self.current_card_index + 1) % self.cards.items.len;
    }

    pub fn draw(self: Hand) void {
        for (self.cards.items) |card| {
            if (!card.is_current) {
                card.draw();
            }
        }
        if (self.cards.items.len > 0) {
            self.cards.items[self.current_card_index].draw();
        }
    }

    pub fn removeCurrentCard(self: *Hand) ?PlayingCard {
        if (self.cards.items.len == 0) return null;

        const index = self.current_card_index;
        const card = self.cards.orderedRemove(index);
        const new_len = self.cards.items.len;

        if (new_len > 0) {
            if (index < new_len) {
                self.current_card_index = index;
            } else {
                self.current_card_index = new_len - 1;
            }
        } else {
            self.current_card_index = 0;
        }
        return card;
    }

    pub fn addCard(self: *Hand, card: PlayingCard) !void {
        var new_card = card;
        new_card.hover_offset = self.hover_lift;
        try self.cards.append(new_card);
    }

    pub fn updatePositions(self: *Hand, player: bool) void {
        const num_cards = @as(i32, @intCast(self.cards.items.len));
        if (num_cards == 0) return;

        const window_width = rl.getScreenWidth();
        const window_height = rl.getScreenHeight();
        const card_width = 100;
        const total_width = (num_cards - 1) * self.spacing + card_width;
        const start_x = @divTrunc(window_width - total_width, 2);
        var base_y = window_height - 200;
        if (!player) {
            base_y = 30;
        }
        for (self.cards.items, 0..) |*card, i| {
            const progress = if (num_cards > 1) @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(num_cards - 1)) else 0.5;
            const angle = -15.0 + progress * 30.0;
            const x = start_x + @as(i32, @intCast(i)) * self.spacing;
            const relative_x = @as(f32, @floatFromInt(x - (start_x + @divTrunc(total_width, 2))));
            var y = base_y + @as(i32, @intFromFloat((relative_x * relative_x) / 5000.0));
            if (!player) {
                y += base_y - @as(i32, @intFromFloat((relative_x * relative_x) / 5000.0));
                card.flip_progress = 1.0;
            }
            card.x = x;
            card.y = y;
            card.hover_offset = self.hover_lift;
            card.base_y = y;
            card.rotation = angle;
        }
    }
};
