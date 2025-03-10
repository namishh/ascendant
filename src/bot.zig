const std = @import("std");
const Hand = @import("hand.zig").Hand;
const PlayingCard = @import("playingcard.zig").PlayingCard;
const Deck = @import("deck.zig").Deck;

pub const Bot = struct {
    hand: Hand,
    last_played_cards: [3]?PlayingCard = .{null} ** 3,
    wins: u32 = 0,

    pub fn init(allocator: std.mem.Allocator) Bot {
        return Bot{
            .hand = Hand.init(allocator),
        };
    }

    pub fn deinit(self: *Bot) void {
        self.hand.deinit();
    }
};
