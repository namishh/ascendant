const rl = @import("raylib");
const std = @import("std");
const PlayingCard = @import("playingcard.zig").PlayingCard;
const Deck = @import("deck.zig").Deck;

pub const Hand = struct {
    cards: std.ArrayList(PlayingCard),
    x: i32,
    y: i32,
    spacing: i32 = 110, // Space between cards

    pub fn init(allocator: std.mem.Allocator, x: i32, y: i32) Hand {
        return Hand{
            .cards = std.ArrayList(PlayingCard).init(allocator),
            .x = x,
            .y = y,
        };
    }

    pub fn deinit(self: *Hand) void {
        self.cards.deinit();
    }

    pub fn drawRandomHand(self: *Hand, deck: *Deck) !void {
        // Clear current hand
        self.cards.clearRetainingCapacity();

        // Draw 8 random cards
        var i: usize = 0;
        while (i < 8) : (i += 1) {
            if (deck.drawCard()) |card| {
                var new_card = card; // Create a mutable copy
                new_card.x = self.x + @as(i32, @intCast(i)) * self.spacing;
                new_card.y = self.y;
                try self.cards.append(new_card);
            } else {
                // If deck is empty, try to reset it
                try deck.reset();
                if (deck.drawCard()) |card| {
                    var new_card = card; // Create a mutable copy
                    new_card.x = self.x + @as(i32, @intCast(i)) * self.spacing;
                    new_card.y = self.y;
                    try self.cards.append(new_card);
                } else {
                    break; // Cannot draw more cards
                }
            }
        }
    }

    pub fn update(self: *Hand) void {
        for (self.cards.items) |*card| {
            card.update();
        }
    }

    pub fn draw(self: Hand) void {
        for (self.cards.items) |card| {
            card.draw();
        }
    }
};
