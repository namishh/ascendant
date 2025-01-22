const rl = @import("raylib");
const std = @import("std");
const PlayingCard = @import("playingcard.zig").PlayingCard;
const Deck = @import("deck.zig").Deck;

pub const Hand = struct {
    cards: std.ArrayList(PlayingCard),
    spacing: i32 = 50,
    hover_lift: f32 = -30.0,

    pub fn init(allocator: std.mem.Allocator) Hand {
        return Hand{
            .cards = std.ArrayList(PlayingCard).init(allocator),
        };
    }

    pub fn deinit(self: *Hand) void {
        self.cards.deinit();
    }

    pub fn drawRandomHand(self: *Hand, deck: *Deck) !void {
        self.cards.clearRetainingCapacity();
        const num_cards: i32 = 10;
        const window_width = rl.getScreenWidth();
        const window_height = rl.getScreenHeight();
        const card_width = 100;
        const total_width = (num_cards - 1) * self.spacing + card_width;
        const start_x = @divTrunc(window_width - total_width, 2);
        const base_y = window_height - 200; // Moved closer to bottom

        var i: usize = 0;
        while (i < num_cards) : (i += 1) {
            if (deck.drawCard()) |card| {
                var new_card = card;
                const progress = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(num_cards - 1));
                const angle = -15.0 + progress * 30.0;
                const x = start_x + @as(i32, @intCast(i)) * self.spacing;
                const relative_x = @as(f32, @floatFromInt(x - (start_x + @divTrunc(total_width, 2))));
                const y = base_y + @as(i32, @intFromFloat((relative_x * relative_x) / (5000.0)));
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
            card.update();
        }
    }

    pub fn draw(self: Hand) void {
        // Draw cards from back to front for proper layering
        var i: usize = 0;
        while (i < self.cards.items.len) : (i += 1) {
            self.cards.items[i].draw();
        }
    }
};
