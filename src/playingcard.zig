const rl = @import("raylib");
const std = @import("std");

pub const PlayingCard = struct {
    value: []const u8,
    suit: []const u8,
    x: i32,
    y: i32,
    width: i32 = 100,
    height: i32 = 125,

    var font: ?rl.Font = null;
    var suit_textures: ?std.StringHashMap(rl.Texture2D) = null;
    var face_card_textures: ?std.StringHashMap(rl.Texture2D) = null;
    var allocator: std.mem.Allocator = undefined;

    fn isFaceCard(value: []const u8) bool {
        return std.mem.eql(u8, value, "k") or
            std.mem.eql(u8, value, "q") or
            std.mem.eql(u8, value, "j");
    }

    pub fn initResources() !void {
        if (font != null) return;

        allocator = std.heap.page_allocator;

        font = try rl.loadFontEx("assets/font.ttf", 32, null);

        // hashmap
        suit_textures = std.StringHashMap(rl.Texture2D).init(allocator);
        face_card_textures = std.StringHashMap(rl.Texture2D).init(allocator);

        const suits = [_][]const u8{ "hearts", "diamonds", "clubs", "spades" };
        for (suits) |suit| {
            const suit_path = try std.fmt.allocPrintZ(allocator, "assets/{s}.png", .{suit});
            defer allocator.free(suit_path);
            const texture = try rl.loadTexture(suit_path.ptr);
            try suit_textures.?.put(suit, texture);

            const face_cards = [_][]const u8{ "k", "q", "j" };
            for (face_cards) |face| {
                const ext = ".jpg";
                // shoutout claude for this
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
                // Free the allocated key
                allocator.free(entry.key_ptr.*);
            }
            textures.deinit();
            face_card_textures = null;
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

    pub fn draw(self: PlayingCard) void {
        if (font == null or suit_textures == null or face_card_textures == null) {
            std.log.err("Resources not initialized before drawing card", .{});
            return;
        }

        // Draw card background
        rl.drawRectangle(self.x, self.y, self.width, self.height, rl.Color.white);
        rl.drawRectangleLines(self.x, self.y, self.width, self.height, rl.Color.black);

        if (isFaceCard(self.value)) {
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
                const maxWidth = @as(f32, @floatFromInt(self.width - 10));
                const maxHeight = @as(f32, @floatFromInt(self.height - 10));
                const imageWidth = @as(f32, @floatFromInt(texture.width));
                const imageHeight = @as(f32, @floatFromInt(texture.height));

                const scaleWidth = maxWidth / imageWidth;
                const scaleHeight = maxHeight / imageHeight;
                const scale = @min(scaleWidth, scaleHeight);

                const scaledWidth = imageWidth * scale;
                const scaledHeight = imageHeight * scale;

                // Center the image on the card
                const imageX = self.x + @as(i32, @intFromFloat((@as(f32, @floatFromInt(self.width)) - scaledWidth) / 2));
                const imageY = self.y + @as(i32, @intFromFloat((@as(f32, @floatFromInt(self.height)) - scaledHeight) / 2));

                rl.drawTextureEx(
                    texture,
                    rl.Vector2{ .x = @as(f32, @floatFromInt(imageX)), .y = @as(f32, @floatFromInt(imageY)) },
                    0,
                    scale,
                    rl.Color.white,
                );
            } else {
                std.log.err("Face card texture not found for key: {s}", .{key});
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

            const valueX = self.x + 10;
            const valueY = self.y + 10;
            rl.drawTextEx(font.?, valueWithNull.ptr, rl.Vector2{ .x = @as(f32, @floatFromInt(valueX)), .y = @as(f32, @floatFromInt(valueY)) }, fontSize, 0, color);

            const valueXBottomRight = self.x + self.width - @as(i32, @intFromFloat(valueWidth)) - 10;
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
                const scale = 0.25;
                const scaledWidth = @as(f32, @floatFromInt(texture.width)) * scale;
                const scaledHeight = @as(f32, @floatFromInt(texture.height)) * scale;
                const suitX = self.x + @divTrunc(self.width, 2) - @divTrunc(@as(i32, @intFromFloat(scaledWidth)), 2);
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
};
