const rl = @import("raylib");
const PlayingCard = @import("playingcard.zig").PlayingCard;

pub const CardOverlay = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: i32 = 100,
    height: i32 = 120,
    rotation: f32 = 0,
    target_x: f32 = 0,
    target_y: f32 = 0,
    target_rotation: f32 = 0,
    move_speed: f32 = 0.2,
    rotation_speed: f32 = 0.2,

    pub fn init() CardOverlay {
        return CardOverlay{};
    }

    pub fn update(self: *CardOverlay, card: PlayingCard) void {
        self.target_x = @floatFromInt(card.x + @divTrunc(card.width, 2));
        self.target_y = @floatFromInt(card.y + @divTrunc(card.height, 2));
        self.target_rotation = card.rotation;
        self.width = card.width;
        self.height = card.height;

        const dx = self.target_x - self.x;
        const dy = self.target_y - self.y;
        self.x += dx * self.move_speed;
        self.y += dy * self.move_speed;

        var dr = self.target_rotation - self.rotation;
        if (dr > 180) {
            dr -= 360;
        } else if (dr < -180) {
            dr += 360;
        }
        self.rotation += dr * self.rotation_speed;
    }

    pub fn deinit(self: *CardOverlay) void {
        _ = self;
    }

    pub fn draw(self: CardOverlay) void {
        const inner_rect = rl.Rectangle{
            .x = self.x,
            .y = self.y,
            .width = @floatFromInt(self.width - 4), // Slightly smaller than card
            .height = @floatFromInt(self.height - 4),
        };

        const origin = rl.Vector2{
            .x = @floatFromInt(@divTrunc(self.width - 4, 2)),
            .y = @floatFromInt(@divTrunc(self.height - 4, 2)),
        };

        rl.drawRectanglePro(
            inner_rect,
            origin,
            self.rotation,
            rl.Color{ .r = 22, .g = 67, .b = 130, .a = 100 },
        );
    }
};
