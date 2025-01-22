const rl = @import("raylib");
const std = @import("std");

pub const PlayingCard = struct {
    value: []const u8,
    suit: []const u8,
    x: i32,
    y: i32,
    width: i32 = 100,
    height: i32 = 125,
    is_hovered: bool = false,
    flip_progress: f32 = 0.0, // 0.0 = front facing, 1.0 = back facing

    var font: ?rl.Font = null;
    var suit_textures: ?std.StringHashMap(rl.Texture2D) = null;
    var face_card_textures: ?std.StringHashMap(rl.Texture2D) = null;
    var joker_textures: ?std.StringHashMap(rl.Texture2D) = null;
    var card_back_texture: ?rl.Texture2D = null;
    var allocator: std.mem.Allocator = undefined;

    fn isFaceCard(value: []const u8) bool {
        return std.mem.eql(u8, value, "k") or
            std.mem.eql(u8, value, "q") or
            std.mem.eql(u8, value, "j");
    }

    fn isJoker(value: []const u8) bool {
        return std.mem.eql(u8, value, "J");
    }

    pub fn initResources() !void {
        if (font != null) return;

        allocator = std.heap.page_allocator;

        font = try rl.loadFontEx("assets/font.ttf", 32, null);

        // Load card back texture
        card_back_texture = try rl.loadTexture("assets/card-back.jpg");

        // Initialize hashmaps
        suit_textures = std.StringHashMap(rl.Texture2D).init(allocator);
        face_card_textures = std.StringHashMap(rl.Texture2D).init(allocator);
        joker_textures = std.StringHashMap(rl.Texture2D).init(allocator);

        // Load joker textures
        const joker_numbers = [_][]const u8{ "1", "2" };
        for (joker_numbers) |num| {
            const key = try allocator.dupe(u8, num);
            errdefer allocator.free(key);

            const path = try std.fmt.allocPrintZ(allocator, "assets/joker-{s}.jpg", .{num});
            defer allocator.free(path);

            const joker_texture = try rl.loadTexture(path.ptr);
            try joker_textures.?.put(key, joker_texture);
        }

        const suits = [_][]const u8{ "hearts", "diamonds", "clubs", "spades" };
        for (suits) |suit| {
            const suit_path = try std.fmt.allocPrintZ(allocator, "assets/{s}.png", .{suit});
            defer allocator.free(suit_path);
            const texture = try rl.loadTexture(suit_path.ptr);
            try suit_textures.?.put(suit, texture);

            const face_cards = [_][]const u8{ "k", "q", "j" };
            for (face_cards) |face| {
                const ext = ".jpg";
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
        };
    }

    pub fn update(self: *PlayingCard) void {
        const mouse_pos = rl.getMousePosition();
        self.is_hovered = mouse_pos.x >= @as(f32, @floatFromInt(self.x)) and
            mouse_pos.x <= @as(f32, @floatFromInt(self.x + self.width)) and
            mouse_pos.y >= @as(f32, @floatFromInt(self.y)) and
            mouse_pos.y <= @as(f32, @floatFromInt(self.y + self.height));

        // Update flip animation with easing
        const flip_speed: f32 = 4.0;
        if (self.is_hovered) {
            self.flip_progress = @min(1.0, self.flip_progress + rl.getFrameTime() * flip_speed);
        } else {
            self.flip_progress = @max(0.0, self.flip_progress - rl.getFrameTime() * flip_speed);
        }
    }

    pub fn draw(self: PlayingCard) void {
        const flip_angle = self.flip_progress * std.math.pi;
        const perspective_scale = 0.25;
        const shadow_intensity = 0.3;

        // Calculate animated properties
        const width_scale = @abs(@cos(flip_angle));
        const scaled_width = @as(i32, @intFromFloat(@as(f32, @floatFromInt(self.width)) * width_scale));
        const vertical_offset = @as(i32, @intFromFloat(@sin(flip_angle) * perspective_scale * 50));
        const x_offset = @divTrunc(self.width - scaled_width, 2);

        // Draw shadow with perspective
        const shadow_alpha = @as(u8, @intFromFloat(80 * (1.0 - width_scale) + 50 * shadow_intensity));
        const shadow_color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = shadow_alpha };
        rl.drawRectangle(self.x + x_offset + 5, self.y + 10 + @as(i32, @intCast(@abs(vertical_offset))), scaled_width, self.height, shadow_color);

        // Draw card base with perspective transform
        if (width_scale > 0.1) {
            // Front face
            const front_alpha = @as(u8, @intFromFloat(255 * (1.0 - self.flip_progress)));
            rl.beginScissorMode(self.x + x_offset, self.y, scaled_width, self.height);
            self.drawFront(x_offset, vertical_offset * @as(i32, @intFromFloat(1.0 - self.flip_progress)), front_alpha);
            rl.endScissorMode();
        }

        if (self.flip_progress > 0.1) {
            // Back face
            const back_alpha = @as(u8, @intFromFloat(255 * self.flip_progress));
            rl.beginScissorMode(self.x + x_offset, self.y, scaled_width, self.height);
            self.drawBack(x_offset, vertical_offset * @as(i32, @intFromFloat(self.flip_progress)), back_alpha);
            rl.endScissorMode();
        }

        // Add specular highlight
        const highlight_alpha = @as(u8, @intFromFloat(80 * @abs(@sin(flip_angle * 2))));
        rl.drawRectangle(self.x + x_offset, self.y + vertical_offset, scaled_width, self.height, rl.Color{ .r = 255, .g = 255, .b = 255, .a = highlight_alpha });
    }

    fn drawFront(self: PlayingCard, x_offset: i32, y_offset: i32, alpha: u8) void {
        const border_color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = alpha };
        const card_color = rl.Color{ .r = 255, .g = 255, .b = 255, .a = alpha };

        const current_width = self.width - x_offset * 2;
        const current_height = self.height;
        const border_size: i32 = 2;
        const corner_cut: i32 = 3;

        const x = self.x + x_offset;
        const y = self.y + y_offset;

        rl.drawRectangle(x + corner_cut, y, current_width - corner_cut * 2, border_size, border_color);
        rl.drawRectangle(x + corner_cut, y + current_height - border_size, current_width - corner_cut * 2, border_size, border_color);
        rl.drawRectangle(x, y + corner_cut, border_size, current_height - corner_cut * 2, border_color);
        rl.drawRectangle(x + current_width - border_size, y + corner_cut, border_size, current_height - corner_cut * 2, border_color);

        rl.drawRectangle(x + border_size, y + border_size, current_width - border_size * 2, current_height - border_size * 2, card_color);

        rl.beginScissorMode(self.x + x_offset, self.y + y_offset, self.width - x_offset * 2, self.height);
        defer rl.endScissorMode();

        if (isJoker(self.value)) {
            if (joker_textures.?.get(self.suit)) |texture| {
                const maxWidth = @as(f32, @floatFromInt(self.width - x_offset * 2 - 10));
                const maxHeight = @as(f32, @floatFromInt(self.height - 10));
                const imageWidth = @as(f32, @floatFromInt(texture.width));
                const imageHeight = @as(f32, @floatFromInt(texture.height));

                const scaleWidth = maxWidth / imageWidth;
                const scaleHeight = maxHeight / imageHeight;
                const scale = @min(scaleWidth, scaleHeight);

                const scaledWidth = imageWidth * scale;
                const scaledHeight = imageHeight * scale;

                const imageX = self.x + x_offset + @as(i32, @intFromFloat((@as(f32, @floatFromInt(self.width - x_offset * 2)) - scaledWidth) / 2));
                const imageY = self.y + @as(i32, @intFromFloat((@as(f32, @floatFromInt(self.height)) - scaledHeight) / 2));

                rl.drawTextureEx(
                    texture,
                    rl.Vector2{ .x = @as(f32, @floatFromInt(imageX)), .y = @as(f32, @floatFromInt(imageY)) },
                    0,
                    scale,
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

                const scaledWidth = imageWidth * scale;
                const scaledHeight = imageHeight * scale;

                const imageX = self.x + x_offset + @as(i32, @intFromFloat((@as(f32, @floatFromInt(self.width - x_offset * 2)) - scaledWidth) / 2));
                const imageY = self.y + @as(i32, @intFromFloat((@as(f32, @floatFromInt(self.height)) - scaledHeight) / 2));

                rl.drawTextureEx(
                    texture,
                    rl.Vector2{ .x = @as(f32, @floatFromInt(imageX)), .y = @as(f32, @floatFromInt(imageY)) },
                    0,
                    scale,
                    rl.Color.white,
                );
            }
        } else {
            const color = if (std.mem.eql(u8, self.suit, "hearts") or std.mem.eql(u8, self.suit, "diamonds"))
                rl.Color.red
            else
                rl.Color.black;

            const fontSize: f32 = 24;

            const valueWithNull = std.fmt.allocPrintZ(allocator, "{s}", .{self.value}) catch |err| {
                std.log.err("Failed to allocate value string: {}", .{err});
                return;
            };
            defer allocator.free(valueWithNull);

            const valueWidth = rl.measureTextEx(font.?, valueWithNull.ptr, fontSize, 0).x;

            const valueX = self.x + x_offset + 10;
            const valueY = self.y + 10;
            rl.drawTextEx(font.?, valueWithNull.ptr, rl.Vector2{ .x = @as(f32, @floatFromInt(valueX)), .y = @as(f32, @floatFromInt(valueY)) }, fontSize, 0, color);

            const valueXBottomRight = self.x + self.width - x_offset - @as(i32, @intFromFloat(valueWidth)) - 10;
            const valueYBottomRight = self.y + self.height - @as(i32, @intFromFloat(fontSize)) - 10;
            rl.drawTextPro(
                font.?,
                valueWithNull.ptr,
                rl.Vector2{
                    .x = @as(f32, @floatFromInt(valueXBottomRight)),
                    .y = @as(f32, @floatFromInt(valueYBottomRight)),
                },
                rl.Vector2{ .x = valueWidth, .y = fontSize },
                180,
                fontSize,
                0,
                color,
            );

            if (suit_textures.?.get(self.suit)) |texture| {
                const scale = 0.15;
                const scaledWidth = @as(f32, @floatFromInt(texture.width)) * scale;
                const scaledHeight = @as(f32, @floatFromInt(texture.height)) * scale;
                const suitX = self.x + x_offset + @divTrunc(self.width - x_offset * 2, 2) - @divTrunc(@as(i32, @intFromFloat(scaledWidth)), 2);
                const suitY = self.y + @divTrunc(self.height, 2) - @divTrunc(@as(i32, @intFromFloat(scaledHeight)), 2);

                rl.drawTextureEx(
                    texture,
                    rl.Vector2{ .x = @as(f32, @floatFromInt(suitX)), .y = @as(f32, @floatFromInt(suitY)) },
                    0,
                    scale,
                    rl.Color.white,
                );
            }
        }
    }

    // In the drawBack function, ensure scissor mode is applied:
    fn drawBack(self: PlayingCard, x_offset: i32, y_offset: i32, alpha: u8) void {
        const texture = card_back_texture.?;
        const maxWidth = @as(f32, @floatFromInt(self.width - x_offset * 2 - 10));
        const maxHeight = @as(f32, @floatFromInt(self.height - 10));
        const imageWidth = @as(f32, @floatFromInt(texture.width));
        const imageHeight = @as(f32, @floatFromInt(texture.height));

        const scaleWidth = maxWidth / imageWidth;
        const scaleHeight = maxHeight / imageHeight;
        const scale = @min(scaleWidth, scaleHeight);

        const scaledWidth = imageWidth * scale;
        const scaledHeight = imageHeight * scale;

        const imageX = self.x + x_offset + @as(i32, @intFromFloat((@as(f32, @floatFromInt(self.width - x_offset * 2)) - scaledWidth) / 2));
        const imageY = self.y + @as(i32, @intFromFloat((@as(f32, @floatFromInt(self.height)) - scaledHeight) / 2));

        const border_color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = alpha };
        const card_color = rl.Color{ .r = 245, .g = 242, .b = 237, .a = alpha };
        const current_width = self.width - x_offset * 2;
        const current_height = self.height;
        const border_size: i32 = 2;
        const corner_cut: i32 = 5;

        const x = self.x + x_offset;
        const y = self.y + y_offset;

        rl.drawRectangle(x + corner_cut, y, current_width - corner_cut * 2, border_size, border_color);
        rl.drawRectangle(x + corner_cut, y + current_height - border_size, current_width - corner_cut * 2, border_size, border_color);
        rl.drawRectangle(x, y + corner_cut, border_size, current_height - corner_cut * 2, border_color);
        rl.drawRectangle(x + current_width - border_size, y + corner_cut, border_size, current_height - corner_cut * 2, border_color);

        rl.drawRectangle(x + border_size, y + border_size, current_width - border_size * 2, current_height - border_size * 2, card_color);

        rl.beginScissorMode(self.x + x_offset, self.y + y_offset, self.width - x_offset * 2, self.height);
        defer rl.endScissorMode();

        rl.drawTextureEx(
            texture,
            rl.Vector2{ .x = @as(f32, @floatFromInt(imageX)), .y = @as(f32, @floatFromInt(imageY)) },
            0,
            scale,
            rl.Color.white,
        );
    }
};
