const rl = @import("raylib");
const std = @import("std");

pub fn calculateCardCorners(x: f32, y: f32, theta: f32, width: f32, height: f32, padding: f32) struct { top_left: rl.Vector2, bottom_right: rl.Vector2 } {
    const half_width = (width - 2 * padding) / 2;
    const half_height = (height - 2 * padding) / 2;

    const cos_theta = @cos(theta);
    const sin_theta = @sin(theta);

    const top_left = rl.Vector2{ .x = (x + -half_width * cos_theta + half_height * sin_theta), .y = (y + -half_width * sin_theta - half_height * cos_theta) };

    const bottom_right = rl.Vector2{ .x = (x + half_width * cos_theta - half_height * sin_theta), .y = (y + half_width * sin_theta + half_height * cos_theta) };

    return .{ .top_left = top_left, .bottom_right = bottom_right };
}

pub const PlayingCard = struct {
    value: []const u8,
    suit: []const u8,
    x: i32,
    y: i32,
    width: i32 = 120,
    height: i32 = 150,
    base_y: i32 = 0,
    current_hover: f32 = 0.0,
    target_hover: f32 = 0.0,
    hover_speed: f32 = 0.2,

    is_hovered: bool = false,
    is_current: bool = false,
    hover_offset: f32 = 0.0,
    flip_progress: f32 = 0.0,
    flip_target: f32 = 0.0,
    rotation: f32 = 0.0,
    borderSpace: i32 = 2,
    borderColor: rl.Color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 255 },

    var font: ?rl.Font = null;
    var suit_textures: ?std.StringHashMap(rl.Texture2D) = null;
    var face_card_textures: ?std.StringHashMap(rl.Texture2D) = null;
    var joker_textures: ?std.StringHashMap(rl.Texture2D) = null;
    var card_back_texture: ?rl.Texture2D = null;
    var allocator: std.mem.Allocator = undefined;

    fn isFaceCard(value: []const u8) bool {
        return std.mem.eql(u8, value, "k") or
            std.mem.eql(u8, value, "q") or
            std.mem.eql(u8, value, "j") or std.mem.eql(u8, value, "a");
    }

    fn isJoker(value: []const u8) bool {
        return std.mem.eql(u8, value, "J");
    }

    pub fn initResources() !void {
        if (font != null) return;

        allocator = std.heap.page_allocator;

        font = try rl.loadFontEx("assets/font.ttf", 32, null);

        card_back_texture = try rl.loadTexture("assets/card-back.jpeg");

        suit_textures = std.StringHashMap(rl.Texture2D).init(allocator);
        face_card_textures = std.StringHashMap(rl.Texture2D).init(allocator);
        joker_textures = std.StringHashMap(rl.Texture2D).init(allocator);

        const joker_numbers = [_][]const u8{ "1", "2" };
        for (joker_numbers) |num| {
            const key = try allocator.dupe(u8, num);
            errdefer allocator.free(key);

            const path = try std.fmt.allocPrintZ(allocator, "assets/joker-{s}.jpeg", .{num});
            defer allocator.free(path);

            const joker_texture = try rl.loadTexture(path.ptr);
            try joker_textures.?.put(key, joker_texture);
        }

        const suits = [_][]const u8{ "fire", "water", "ice" };
        for (suits) |suit| {
            const suit_path = try std.fmt.allocPrintZ(allocator, "assets/{s}.png", .{suit});
            defer allocator.free(suit_path);
            const texture = try rl.loadTexture(suit_path.ptr);
            try suit_textures.?.put(suit, texture);

            const face_cards = [_][]const u8{ "k", "q", "j", "a" };
            for (face_cards) |face| {
                const ext = ".jpeg";
                const key = try allocator.dupe(u8, try std.fmt.allocPrint(allocator, "{s}-{s}", .{ face, suit }));
                errdefer allocator.free(key);

                const path = try std.fmt.allocPrintZ(allocator, "assets/{s}-{s}{s}", .{ face, suit, ext });
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

    pub fn init(value: []const u8, suit: []const u8, x: i32, y: i32) PlayingCard {
        return PlayingCard{
            .value = value,
            .suit = suit,
            .x = x,
            .y = y,
            .base_y = y,
        };
    }

    pub fn update(self: *PlayingCard) void {
        self.target_hover = if (self.is_hovered) 1.0 else 0.0;

        if (self.current_hover < self.target_hover) {
            self.current_hover = @min(self.current_hover + self.hover_speed, self.target_hover);
        } else if (self.current_hover > self.target_hover) {
            self.current_hover = @max(self.current_hover - self.hover_speed, self.target_hover);
        }

        self.y = self.base_y + @as(i32, @intFromFloat(self.current_hover * self.hover_offset));

        // Flipping animation
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

        // Draw shadow aligned with card
        const shadow_alpha = @as(u8, @intFromFloat(100.0 * (1.0 - scale)));
        rl.drawRectangle(
            self.x + x_offset,
            self.y,
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
                self.x + x_offset,
                self.y,
                current_width,
                self.height,
                rl.Color{ .r = 255, .g = 255, .b = 255, .a = highlight_alpha },
            );
        }
    }

    fn drawFront(self: PlayingCard, x_offset: i32, y_offset: i32, alpha: u8) void {
        //const border_color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = alpha };
        const card_color = rl.Color{ .r = 255, .g = 255, .b = 255, .a = alpha };

        const current_width = self.width - x_offset * 2;
        const current_height = self.height;

        // Calculate center point for rotation
        const center_x = @as(f32, @floatFromInt(self.x + x_offset + @divTrunc(current_width, 2)));
        const center_y = @as(f32, @floatFromInt(self.y + y_offset + @divTrunc(current_height, 2)));

        // Draw outer rectangle (border) with rotation
        const outer_rect = rl.Rectangle{
            .x = center_x,
            .y = center_y,
            .width = @floatFromInt(current_width),
            .height = @floatFromInt(current_height),
        };
        const outer_origin = rl.Vector2{
            .x = @floatFromInt(@divTrunc(current_width, 2)),
            .y = @floatFromInt(@divTrunc(current_height, 2)),
        };

        // Draw inner rectangle (card background) with rotation
        const inner_rect = rl.Rectangle{
            .x = center_x,
            .y = center_y,
            .width = @floatFromInt(current_width - self.borderSpace * 2),
            .height = @floatFromInt(current_height - self.borderSpace * 2),
        };
        const inner_origin = rl.Vector2{
            .x = @floatFromInt(@divTrunc(current_width - self.borderSpace * 2, 2)),
            .y = @floatFromInt(@divTrunc(current_height - self.borderSpace * 2, 2)),
        };

        // Draw border and card background
        rl.drawRectanglePro(outer_rect, outer_origin, self.rotation, self.borderColor);
        rl.drawRectanglePro(inner_rect, inner_origin, self.rotation, card_color);

        if (isJoker(self.value)) {
            if (joker_textures.?.get(self.suit)) |texture| {
                const maxWidth = @as(f32, @floatFromInt(self.width - x_offset * 2 - 10));
                const maxHeight = @as(f32, @floatFromInt(self.height - 10));
                const imageWidth = @as(f32, @floatFromInt(texture.width));
                const imageHeight = @as(f32, @floatFromInt(texture.height));

                const scaleWidth = maxWidth / imageWidth;
                const scaleHeight = maxHeight / imageHeight;
                const scale = @min(scaleWidth, scaleHeight);

                const source_rect = rl.Rectangle{
                    .x = 0,
                    .y = 0,
                    .width = imageWidth,
                    .height = imageHeight,
                };

                const dest_rect = rl.Rectangle{
                    .x = center_x,
                    .y = center_y,
                    .width = imageWidth * scale,
                    .height = imageHeight * scale,
                };

                const img_origin = rl.Vector2{
                    .x = (imageWidth * scale) / 2,
                    .y = (imageHeight * scale) / 2,
                };

                rl.drawTexturePro(
                    texture,
                    source_rect,
                    dest_rect,
                    img_origin,
                    self.rotation,
                    rl.Color.white,
                );
            }
        } else if (isFaceCard(self.value)) {
            const lower_value = if (self.value[0] >= 'A' and self.value[0] <= 'Z')
                @as(u8, self.value[0] + 32)
            else
                self.value[0];

            const key = std.fmt.allocPrintZ(allocator, "{c}-{s}", .{ lower_value, self.suit }) catch |err| {
                std.log.err("Failed to allocate face card key: {}", .{err});
                return;
            };
            defer allocator.free(key);

            if (face_card_textures.?.get(key)) |texture| {
                const maxWidth = @as(f32, @floatFromInt(self.width - x_offset * 2 - 10));
                const maxHeight = @as(f32, @floatFromInt(self.height - 10));
                const imageWidth = @as(f32, @floatFromInt(texture.width));
                const imageHeight = @as(f32, @floatFromInt(texture.height));

                const scaleWidth = maxWidth / imageWidth;
                const scaleHeight = maxHeight / imageHeight;
                const scale = @min(scaleWidth, scaleHeight);

                const source_rect = rl.Rectangle{
                    .x = 0,
                    .y = 0,
                    .width = imageWidth,
                    .height = imageHeight,
                };

                const dest_rect = rl.Rectangle{
                    .x = center_x,
                    .y = center_y,
                    .width = imageWidth * scale,
                    .height = imageHeight * scale,
                };

                const img_origin = rl.Vector2{
                    .x = (imageWidth * scale) / 2,
                    .y = (imageHeight * scale) / 2,
                };

                rl.drawTexturePro(
                    texture,
                    source_rect,
                    dest_rect,
                    img_origin,
                    self.rotation,
                    rl.Color.white,
                );
            }
        } else {
            const color = if (std.mem.eql(u8, self.suit, "water") or std.mem.eql(u8, self.suit, "ice"))
                rl.Color.sky_blue
            else
                rl.Color.orange;

            const fontSize: f32 = 28;

            // Draw value text
            const valueWithNull = std.fmt.allocPrintZ(allocator, "{s}", .{self.value}) catch |err| {
                std.log.err("Failed to allocate value string: {}", .{err});
                return;
            };
            defer allocator.free(valueWithNull);

            // Draw suit texture
            if (suit_textures.?.get(self.suit)) |texture| {
                const scale = 0.25;
                const imageWidth = @as(f32, @floatFromInt(texture.width));
                const imageHeight = @as(f32, @floatFromInt(texture.height));

                const source_rect = rl.Rectangle{
                    .x = 0,
                    .y = 0,
                    .width = imageWidth,
                    .height = imageHeight,
                };

                const dest_rect = rl.Rectangle{
                    .x = center_x,
                    .y = center_y,
                    .width = imageWidth * scale,
                    .height = imageHeight * scale,
                };

                const img_origin = rl.Vector2{
                    .x = (imageWidth * scale) / 2,
                    .y = (imageHeight * scale) / 2,
                };

                rl.drawTexturePro(
                    texture,
                    source_rect,
                    dest_rect,
                    img_origin,
                    self.rotation,
                    rl.Color.white,
                );
            }

            const positions = calculateCardCorners(center_x, center_y, std.math.degreesToRadians(self.rotation), @as(f32, @floatFromInt(self.width)), @as(f32, @floatFromInt(self.height)), 10);

            rl.drawTextPro(
                font.?,
                valueWithNull.ptr,
                positions.top_left,
                rl.Vector2{ .x = 0, .y = 0 },
                self.rotation,
                fontSize,
                0,
                color,
            );

            rl.drawTextPro(
                font.?,
                valueWithNull.ptr,
                positions.bottom_right,
                rl.Vector2{ .x = 0, .y = 0 },
                self.rotation + 180,
                fontSize,
                0,
                color,
            );
        }
    }

    pub fn equals(self: *PlayingCard, other: *PlayingCard) bool {
        return std.mem.eql(u8, self.value, other.value) and std.mem.eql(u8, self.suit, other.suit);
    }

    fn drawBack(self: PlayingCard, x_offset: i32, y_offset: i32, alpha: u8) void {
        const texture = card_back_texture.?;
        const card_color = rl.Color{ .r = 255, .g = 255, .b = 255, .a = alpha };

        const current_width = self.width - x_offset * 2;
        const current_height = self.height;

        // Calculate center point for rotation
        const center_x = @as(f32, @floatFromInt(self.x + x_offset + @divTrunc(current_width, 2)));
        const center_y = @as(f32, @floatFromInt(self.y + y_offset + @divTrunc(current_height, 2)));

        // Draw outer rectangle (border) with rotation
        const outer_rect = rl.Rectangle{
            .x = center_x,
            .y = center_y,
            .width = @floatFromInt(current_width),
            .height = @floatFromInt(current_height),
        };
        const outer_origin = rl.Vector2{
            .x = @floatFromInt(@divTrunc(current_width, 2)),
            .y = @floatFromInt(@divTrunc(current_height, 2)),
        };

        // Draw inner rectangle (card background) with rotation
        const inner_rect = rl.Rectangle{
            .x = center_x,
            .y = center_y,
            .width = @floatFromInt(current_width - self.borderSpace * 2),
            .height = @floatFromInt(current_height - self.borderSpace * 2),
        };
        const inner_origin = rl.Vector2{
            .x = @floatFromInt(@divTrunc(current_width - self.borderSpace * 2, 2)),
            .y = @floatFromInt(@divTrunc(current_height - self.borderSpace * 2, 2)),
        };

        // Draw border and card background
        rl.drawRectanglePro(outer_rect, outer_origin, self.rotation, self.borderColor);
        rl.drawRectanglePro(inner_rect, inner_origin, self.rotation, card_color);

        // Draw back texture
        const imageWidth = @as(f32, @floatFromInt(texture.width));
        const imageHeight = @as(f32, @floatFromInt(texture.height));
        const maxWidth = @as(f32, @floatFromInt(self.width - x_offset * 2 - 10));
        const maxHeight = @as(f32, @floatFromInt(self.height - 10));

        const scaleWidth = maxWidth / imageWidth;
        const scaleHeight = maxHeight / imageHeight;
        const scale = @min(scaleWidth, scaleHeight);

        const source_rect = rl.Rectangle{
            .x = 0,
            .y = 0,
            .width = imageWidth,
            .height = imageHeight,
        };

        const dest_rect = rl.Rectangle{
            .x = center_x,
            .y = center_y,
            .width = imageWidth * scale,
            .height = imageHeight * scale,
        };

        const img_origin = rl.Vector2{
            .x = (imageWidth * scale) / 2,
            .y = (imageHeight * scale) / 2,
        };

        rl.drawTexturePro(
            texture,
            source_rect,
            dest_rect,
            img_origin,
            self.rotation,
            rl.Color.white,
        );
    }
};
