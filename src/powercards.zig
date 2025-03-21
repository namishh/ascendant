const rl = @import("raylib");
const std = @import("std");
const PlayingCard = @import("playingcard.zig").PlayingCard;
const Deck = @import("deck.zig").Deck;

pub const PowerCards = struct {
    cards: std.ArrayList(PlayingCard),
    x: i32,
    y: i32,
    slot_width: i32 = 85,
    max_cards: i32 = 2,
    card_back_texture: ?rl.Texture2D = null,

    pub fn init(allocator: std.mem.Allocator) !PowerCards {
        return PowerCards{
            .cards = std.ArrayList(PlayingCard).init(allocator),
            .x = 60,
            .y = @divTrunc(rl.getScreenHeight(), 1) - 150,
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
            new_card.target_x = @floatFromInt(self.x + @as(i32, @intCast(self.cards.items.len)) * self.slot_width);
            new_card.target_y = @floatFromInt(self.y);
            new_card.x = new_card.target_x;
            new_card.y = new_card.target_y;
            new_card.height = 92;
            new_card.width = 69;
            new_card.is_power_card = true;
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
            card.target_x = @floatFromInt(self.x + @as(i32, @intCast(i)) * self.slot_width);
            card.target_y = @floatFromInt(self.y);
            card.x = card.target_x;
            card.y = card.target_y;
        }
    }

    pub fn draw(self: PowerCards) void {
        for (0..@as(usize, @intCast(self.max_cards))) |i| {
            const x = self.x + @as(i32, @intCast(i)) * self.slot_width;
            rl.drawRectangleLines(x - 2, self.y - 2, 73, 96, rl.Color.gray);
        }

        for (self.cards.items) |card| {
            card.draw();
        }
    }
};
