const rl = @import("raylib");
const std = @import("std");
const PlayingCard = @import("playingcard.zig").PlayingCard;
const Deck = @import("deck.zig").Deck;

pub fn inSlice(comptime T: type, haystack: std.ArrayList(T), needle: T) struct { found: bool, position: usize } {
    for (0..haystack.items.len) |index| {
        if (haystack.items[index] == needle) {
            return .{ .found = true, .position = index };
        }
    }
    return .{ .found = false, .position = haystack.items.len };
}

pub const Hand = struct {
    cards: std.ArrayList(PlayingCard),
    selected_cards: std.ArrayList(*PlayingCard),
    current_card_index: usize = 0,
    spacing: i32 = 50,
    hover_lift: f32 = -30.0,

    pub fn init(allocator: std.mem.Allocator) Hand {
        return Hand{
            .cards = std.ArrayList(PlayingCard).init(allocator),
            .selected_cards = std.ArrayList(*PlayingCard).init(allocator),
        };
    }

    pub fn deinit(self: *Hand) void {
        self.cards.deinit();
        self.selected_cards.deinit();
    }

    pub fn drawRandomHand(self: *Hand, deck: *Deck) !void {
        self.cards.clearRetainingCapacity();
        self.selected_cards.clearRetainingCapacity();
        self.current_card_index = 0;

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
            card.is_hovered = false;
        }

        for (self.selected_cards.items) |card| {
            card.is_hovered = true;
        }

        if (self.cards.items.len > 0) {
            self.cards.items[self.current_card_index].is_hovered = true;
        }

        for (self.selected_cards.items) |card| {
            card.y = card.base_y + @as(i32, @intFromFloat(self.hover_lift));
        }

        for (self.cards.items) |*card| {
            card.update();
        }

        if (rl.isKeyPressed(.a)) {
            self.cyclePrevCard();
        }
        if (rl.isKeyPressed(.d)) {
            self.cycleNextCard();
        }
        if (rl.isKeyPressed(.w)) {
            self.selectCardNormal();
        }
        if (rl.isKeyPressed(.s)) {
            self.selectCardHidden();
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

    fn selectCardNormal(self: *Hand) void {
        if (self.cards.items.len == 0) return;

        var card = &self.cards.items[self.current_card_index];

        const found = inSlice(*PlayingCard, self.selected_cards, card);

        if (!found.found) {
            card.flip_target = 0.0;
            card.is_hovered = true;
            self.selected_cards.append(card) catch return;
        } else if (found.position < self.selected_cards.items.len) {
            if (card.flip_target == 0 and card.is_hovered == true) {
                card.is_hovered = false;
                _ = self.selected_cards.orderedRemove(found.position);
            } else {
                card.flip_target = 1.0 - card.flip_target;
                card.is_hovered = true;
            }
        }
    }

    fn selectCardHidden(self: *Hand) void {
        if (self.cards.items.len == 0) return;

        var card = &self.cards.items[self.current_card_index];

        const found = inSlice(*PlayingCard, self.selected_cards, card);

        if (!found.found) {
            card.flip_target = 1.0;
            card.is_hovered = true;
            self.selected_cards.append(card) catch return;
        } else if (found.position < self.selected_cards.items.len) {
            if (card.flip_progress == 1.0) {
                card.flip_target = 0.0;
                card.is_hovered = false;
                _ = self.selected_cards.orderedRemove(found.position);
            } else {
                card.flip_target = 1.0;
                card.is_hovered = true;
            }
        }
    }

    pub fn draw(self: Hand) void {
        for (self.cards.items) |card| {
            card.draw();
        }
    }
};
