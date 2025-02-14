const rl = @import("raylib");
const std = @import("std");
const PlayingCard = @import("playingcard.zig").PlayingCard;
const Deck = @import("deck.zig").Deck;

pub const PowerCards = struct {
    cards: std.ArrayList(PlayingCard),
    x: i32,
    y: i32,
    slot_width: i32 = 95,
    max_cards: i32 = 4,
    card_back_texture: ?rl.Texture2D = null,

    pub fn init(allocator: std.mem.Allocator) !PowerCards {
        return PowerCards{
            .cards = std.ArrayList(PlayingCard).init(allocator),
            .x = 25,
            .y = @divTrunc(rl.getScreenHeight(), 1) - 130,
        };
    }

    pub fn deinit(self: *PowerCards) void {
        if (self.card_back_texture) |texture| {
            rl.unloadTexture(texture);
        }
        self.cards.deinit();
    }

    pub fn loadResources(self: *PowerCards) !void {
        if (self.card_back_texture == null) {
            self.card_back_texture = try rl.loadTexture("assets/power-card.jpg");
        }
    }

    pub fn addCard(self: *PowerCards, deck: *Deck) !void {
        if (self.cards.items.len >= self.max_cards) return;

        if (try deck.drawPowerCard()) |card| {
            var new_card = card;
            new_card.x = self.x + @as(i32, @intCast(self.cards.items.len)) * self.slot_width;
            new_card.y = self.y;
            new_card.height = 108;
            new_card.width = 81;

            try self.cards.append(new_card);
        }
    }

    pub fn activateCard(self: *PowerCards, index: usize) bool {
        if (index >= self.cards.items.len) return false;
        _ = self.cards.orderedRemove(index);
        self.updateCardPositions();
        return true;
    }

    pub fn reset(self: *PowerCards) void {
        self.cards.clearRetainingCapacity();
    }

    fn updateCardPositions(self: *PowerCards) void {
        for (self.cards.items, 0..) |*card, i| {
            card.x = self.x + @as(i32, @intCast(i)) * self.slot_width;
            card.y = self.y;
        }
    }

    pub fn draw(self: PowerCards) void {
        for (0..@as(usize, @intCast(self.max_cards))) |i| {
            const x = self.x + @as(i32, @intCast(i)) * self.slot_width;
            rl.drawRectangleLines(x - 2, self.y - 2, 85, 112, rl.Color.gray);
        }

        for (self.cards.items) |card| {
            card.draw();
        }
    }
};
