const rl = @import("raylib");
const std = @import("std");

pub const Suit = enum(u8) {
    fire = 0,
    water = 1,
    ice = 2,
};

fn calculateCardCorners(x: f32, y: f32, theta: f32, width: f32, height: f32, padding: f32) struct { top_left: rl.Vector2, bottom_right: rl.Vector2 } {
    const half_width = (width - 2 * padding) / 2;
    const half_height = (height - 2 * padding) / 2;

    const cos_theta = @cos(theta);
    const sin_theta = @sin(theta);

    const top_left = rl.Vector2{ .x = (x + -half_width * cos_theta + half_height * sin_theta), .y = (y + -half_width * sin_theta - half_height * cos_theta) };
    const bottom_right = rl.Vector2{ .x = (x + half_width * cos_theta - half_height * sin_theta), .y = (y + half_width * sin_theta + half_height * cos_theta) };

    return .{ .top_left = top_left, .bottom_right = bottom_right };
}

pub const PlayingCard = struct {
    value: u8,
    suit: Suit,
    x: f32,
    y: f32,
    target_x: f32,
    target_y: f32,
    base_y: f32,
    width: i32 = 95,
    height: i32 = 125,
    move_speed: f32 = 0.1,
    rotation_speed: f32 = 0.1,
    is_power_card: bool = false,
    is_hovered: bool = false,
    is_current: bool = false,
    hover_offset: f32 = 0.0,
    flip_progress: f32 = 0.0,
    flip_target: f32 = 0.0,
    rotation: f32 = 0.0,
    target_rotation: f32 = 0.0,
    borderSpace: i32 = 2,
    borderColor: rl.Color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 255 },

    var font: ?rl.Font = null;
    var suit_textures: ?std.StringHashMap(rl.Texture2D) = null;
    var face_card_textures: ?std.StringHashMap(rl.Texture2D) = null;
    var joker_textures: ?std.StringHashMap(rl.Texture2D) = null;
    var card_back_texture: ?rl.Texture2D = null;
    var card_back_power_texture: ?rl.Texture2D = null;
    var allocator: std.mem.Allocator = undefined;

    fn isFaceCard(value: u8) bool {
        return value >= 11 and value <= 14;
    }

    fn isJoker(value: u8) bool {
        return value == 15;
    }

    pub fn initResources() !void {
        if (font != null) return;

        allocator = std.heap.page_allocator;

        font = try rl.loadFontEx("assets/font.ttf", 108, null);

        card_back_texture = try rl.loadTexture("assets/card-back.png");
        card_back_power_texture = try rl.loadTexture("assets/power-card.jpg");

        suit_textures = std.StringHashMap(rl.Texture2D).init(allocator);
        face_card_textures = std.StringHashMap(rl.Texture2D).init(allocator);
        joker_textures = std.StringHashMap(rl.Texture2D).init(allocator);

        const joker_nums = [_][]const u8{ "1", "2" };
        for (joker_nums) |num| {
            const key = try allocator.dupe(u8, num);
            errdefer allocator.free(key);

            const path = try std.fmt.allocPrintZ(allocator, "assets/joker-{s}.jpeg", .{num});
            defer allocator.free(path);

            const joker_texture = try rl.loadTexture(path.ptr);
            try joker_textures.?.put(key, joker_texture);
        }

        const suits = [_][]const u8{ "fire", "water", "ice" };
        for (suits) |suit_name| {
            const suit_path = try std.fmt.allocPrintZ(allocator, "assets/{s}.png", .{suit_name});
            defer allocator.free(suit_path);
            const texture = try rl.loadTexture(suit_path.ptr);
            try suit_textures.?.put(suit_name, texture);

            const face_cards = [_][]const u8{ "j", "q", "k", "a" };
            for (face_cards) |face| {
                const key = try allocator.dupe(u8, try std.fmt.allocPrint(allocator, "{s}-{s}", .{ face, suit_name }));
                errdefer allocator.free(key);

                const path = try std.fmt.allocPrintZ(allocator, "assets/{s}-{s}.jpeg", .{ face, suit_name });
                defer allocator.free(path);

                const face_texture = try rl.loadTexture(path.ptr);
                try face_card_textures.?.put(key, face_texture);
            }
        }
    }

    pub fn deinitResources() void {
        if (font) |f| {
            rl.unloadFont(f);
            font = null;
        }

        if (card_back_texture) |texture| {
            rl.unloadTexture(texture);
            card_back_texture = null;
        }

        if (card_back_power_texture) |texture| {
            rl.unloadTexture(texture);
            card_back_power_texture = null;
        }

        if (suit_textures) |*textures| {
            var iterator = textures.iterator();
            while (iterator.next()) |entry| {
                rl.unloadTexture(entry.value_ptr.*);
            }
            textures.deinit();
            suit_textures = null;
        }

        if (face_card_textures) |*textures| {
            var iterator = textures.iterator();
            while (iterator.next()) |entry| {
                rl.unloadTexture(entry.value_ptr.*);
                allocator.free(entry.key_ptr.*);
            }
            textures.deinit();
            face_card_textures = null;
        }

        if (joker_textures) |*textures| {
            var iterator = textures.iterator();
            while (iterator.next()) |entry| {
                rl.unloadTexture(entry.value_ptr.*);
                allocator.free(entry.key_ptr.*);
            }
            textures.deinit();
            joker_textures = null;
        }
    }

    pub fn init(value: u8, suit: Suit, x: f32, y: f32) PlayingCard {
        return PlayingCard{
            .value = value,
            .suit = suit,
            .x = x,
            .y = y,
            .target_x = x,
            .target_y = y,
            .base_y = y,
            .rotation = 0.0,
            .target_rotation = 0.0,
            .flip_progress = 1.0, // Start face down
            .flip_target = 1.0,
        };
    }

    pub fn update(self: *PlayingCard) void {
        // Interpolate x
        const dx = self.target_x - self.x;
        self.x += dx * self.move_speed;

        // Interpolate y
        const dy = self.target_y - self.y;
        self.y += dy * self.move_speed;

        // Interpolate rotation
        var dr = self.target_rotation - self.rotation;
        if (dr > 180) dr -= 360 else if (dr < -180) dr += 360;
        self.rotation += dr * self.rotation_speed;

        // Interpolate flip
        const flip_speed = 0.05;
        if (self.flip_progress < self.flip_target) {
            self.flip_progress = @min(self.flip_progress + flip_speed, self.flip_target);
        } else if (self.flip_progress > self.flip_target) {
            self.flip_progress = @max(self.flip_progress - flip_speed, self.flip_target);
        }
    }

    pub fn draw(self: PlayingCard) void {
        const flip_angle = self.flip_progress * std.math.pi;
        const scale = @abs(@cos(flip_angle));
        const current_width = @as(i32, @intFromFloat(@as(f32, @floatFromInt(self.width)) * scale));
        const x_offset = @divTrunc(self.width - current_width, 2);

        // Draw shadow
        const shadow_alpha = @as(u8, @intFromFloat(100.0 * (1.0 - scale)));
        rl.drawRectangle(
            @intFromFloat(self.x + @as(f32, @floatFromInt(x_offset))),
            @intFromFloat(self.y),
            current_width,
            self.height,
            rl.Color{ .r = 0, .g = 0, .b = 0, .a = shadow_alpha },
        );

        if (self.flip_progress < 0.5) {
            self.drawFront(x_offset, 0, 255);
        } else {
            self.drawBack(x_offset, 0, 255);
        }

        if (self.is_hovered) {
            const highlight_intensity = @abs(@sin(flip_angle));
            const highlight_alpha = @as(u8, @intFromFloat(80.0 * highlight_intensity));
            rl.drawRectangle(
                @intFromFloat(self.x + @as(f32, @floatFromInt(x_offset))),
                @intFromFloat(self.y),
                current_width,
                self.height,
                rl.Color{ .r = 255, .g = 255, .b = 255, .a = highlight_alpha },
            );
        }
    }

    fn drawFront(self: PlayingCard, x_offset: i32, y_offset: i32, alpha: u8) void {
        const card_color = rl.Color{ .r = 255, .g = 255, .b = 255, .a = alpha };
        const current_width = self.width - x_offset * 2;
        const current_height = self.height;

        const center_x = self.x + @as(f32, @floatFromInt(x_offset + @divTrunc(current_width, 2)));
        const center_y = self.y + @as(f32, @floatFromInt(y_offset + @divTrunc(current_height, 2)));

        const outer_rect = rl.Rectangle{ .x = center_x, .y = center_y, .width = @floatFromInt(current_width), .height = @floatFromInt(current_height) };
        const outer_origin = rl.Vector2{ .x = @floatFromInt(@divTrunc(current_width, 2)), .y = @floatFromInt(@divTrunc(current_height, 2)) };
        const inner_rect = rl.Rectangle{ .x = center_x, .y = center_y, .width = @floatFromInt(current_width - self.borderSpace * 2), .height = @floatFromInt(current_height - self.borderSpace * 2) };
        const inner_origin = rl.Vector2{ .x = @floatFromInt(@divTrunc(current_width - self.borderSpace * 2, 2)), .y = @floatFromInt(@divTrunc(current_height - self.borderSpace * 2, 2)) };

        rl.drawRectanglePro(outer_rect, outer_origin, self.rotation, self.borderColor);
        rl.drawRectanglePro(inner_rect, inner_origin, self.rotation, card_color);

        if (isJoker(self.value)) {
            const joker_key = if (self.suit == .fire) "1" else "2";
            if (joker_textures.?.get(joker_key)) |texture| {
                self.drawTexture(texture, center_x, center_y, self.rotation);
            }
        } else if (isFaceCard(self.value)) {
            const face_str = switch (self.value) {
                11 => "j",
                12 => "q",
                13 => "k",
                14 => "a",
                else => unreachable,
            };
            const suit_str = switch (self.suit) {
                .fire => "fire",
                .water => "water",
                .ice => "ice",
            };
            const key = std.fmt.allocPrintZ(allocator, "{s}-{s}", .{ face_str, suit_str }) catch return;
            defer allocator.free(key);

            if (face_card_textures.?.get(key)) |texture| {
                self.drawTexture(texture, center_x, center_y, self.rotation);
            }
        } else {
            const value_str = std.fmt.allocPrintZ(allocator, "{}", .{self.value}) catch "2";
            defer allocator.free(value_str);

            const suit_str = switch (self.suit) {
                .fire => "fire",
                .water => "water",
                .ice => "ice",
            };

            if (suit_textures.?.get(suit_str)) |texture| {
                self.drawTexture(texture, center_x, center_y, self.rotation);
            }

            const positions = calculateCardCorners(center_x, center_y, std.math.degreesToRadians(self.rotation), @floatFromInt(self.width), @floatFromInt(self.height), 10);
            const color = switch (self.suit) {
                .fire => rl.Color.orange,
                .water => rl.Color.blue,
                .ice => rl.Color.sky_blue,
            };

            rl.drawTextPro(font.?, value_str.ptr, positions.top_left, rl.Vector2{ .x = 0, .y = 0 }, self.rotation, 28, 0, color);
            rl.drawTextPro(font.?, value_str.ptr, positions.bottom_right, rl.Vector2{ .x = 0, .y = 0 }, self.rotation + 180, 28, 0, color);
        }
    }

    fn drawTexture(self: PlayingCard, texture: rl.Texture2D, center_x: f32, center_y: f32, rotation: f32) void {
        const maxWidth = @as(f32, @floatFromInt(self.width - 10));
        const maxHeight = @as(f32, @floatFromInt(self.height - 10));
        const imageWidth = @as(f32, @floatFromInt(texture.width));
        const imageHeight = @as(f32, @floatFromInt(texture.height));

        var scale = @min(maxWidth / imageWidth, maxHeight / imageHeight);
        if (!self.is_power_card and self.flip_progress == 0) scale *= 0.66;

        const source_rect = rl.Rectangle{ .x = 0, .y = 0, .width = imageWidth, .height = imageHeight };
        const dest_rect = rl.Rectangle{ .x = center_x, .y = center_y, .width = imageWidth * scale, .height = imageHeight * scale };
        const img_origin = rl.Vector2{ .x = (imageWidth * scale) / 2, .y = (imageHeight * scale) / 2 };

        rl.drawTexturePro(texture, source_rect, dest_rect, img_origin, rotation, rl.Color.white);
    }

    fn drawBack(self: PlayingCard, x_offset: i32, y_offset: i32, alpha: u8) void {
        const texture = if (self.is_power_card) card_back_power_texture.? else card_back_texture.?;
        const card_color = rl.Color{ .r = 255, .g = 255, .b = 255, .a = alpha };

        const current_width = self.width - x_offset * 2;
        const current_height = self.height;

        const center_x = self.x + @as(f32, @floatFromInt(x_offset + @divTrunc(current_width, 2)));
        const center_y = self.y + @as(f32, @floatFromInt(y_offset + @divTrunc(current_height, 2)));

        const outer_rect = rl.Rectangle{ .x = center_x, .y = center_y, .width = @floatFromInt(current_width), .height = @floatFromInt(current_height) };
        const outer_origin = rl.Vector2{ .x = @floatFromInt(@divTrunc(current_width, 2)), .y = @floatFromInt(@divTrunc(current_height, 2)) };
        const inner_rect = rl.Rectangle{ .x = center_x, .y = center_y, .width = @floatFromInt(current_width - self.borderSpace * 2), .height = @floatFromInt(current_height - self.borderSpace * 2) };
        const inner_origin = rl.Vector2{ .x = @floatFromInt(@divTrunc(current_width - self.borderSpace * 2, 2)), .y = @floatFromInt(@divTrunc(current_height - self.borderSpace * 2, 2)) };

        rl.drawRectanglePro(outer_rect, outer_origin, self.rotation, self.borderColor);
        rl.drawRectanglePro(inner_rect, inner_origin, self.rotation, card_color);
        self.drawTexture(texture, center_x, center_y, self.rotation);
    }

    pub fn equals(self: PlayingCard, other: PlayingCard) bool {
        return self.value == other.value and self.suit == other.suit;
    }
};
