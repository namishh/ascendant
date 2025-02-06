const rl = @import("raylib");
const std = @import("std");

pub const Toast = struct {
    texture: ?rl.Texture2D,
    title: ?[:0]const u8,
    priority: ?[:0]const u8,
    message: ?[:0]const u8,
    created_at: f64,
    opacity: f32 = 1.0,
    y_offset: f32 = 0,
    allocator: std.mem.Allocator,
    lifetime: f32 = 5.0,
    fade_speed: f32 = 0.5,
    height: f32 = 100,
    padding: f32 = 10,
    spacing: f32 = 10,
    terminated_image_path: ?[]u8 = null,

    pub fn init(allocator: std.mem.Allocator, image_path: ?[]const u8, title: ?[]const u8, priority: ?[]const u8, message: ?[]const u8) !Toast {
        var texture: ?rl.Texture2D = null;
        var terminated_image_path: ?[]u8 = null;

        if (image_path) |path| {
            terminated_image_path = try allocator.alloc(u8, path.len + 1);
            std.mem.copyForwards(u8, terminated_image_path.?, path);
            terminated_image_path.?[path.len] = 0;

            const loaded_texture = rl.loadTexture(@as([*:0]const u8, @ptrCast(terminated_image_path.?.ptr))) catch |err| {
                std.log.err("Failed to load texture: {s}", .{path});
                return err;
            };
            texture = loaded_texture;
        }

        var owned_title: ?[:0]const u8 = null;
        var owned_message: ?[:0]const u8 = null;
        var owned_priority: ?[:0]const u8 = null;

        if (title) |t| {
            const buf = try allocator.alloc(u8, t.len + 1);
            std.mem.copyForwards(u8, buf[0..t.len], t);
            buf[t.len] = 0;
            owned_title = buf[0..t.len :0];
        }
        if (message) |m| {
            const buf = try allocator.alloc(u8, m.len + 1);
            std.mem.copyForwards(u8, buf[0..m.len], m);
            buf[m.len] = 0;
            owned_message = buf[0..m.len :0];
        }
        if (priority) |p| {
            const buf = try allocator.alloc(u8, p.len + 1);
            std.mem.copyForwards(u8, buf[0..p.len], p);
            buf[p.len] = 0;
            owned_priority = buf[0..p.len :0];
        }

        return Toast{
            .texture = texture,
            .terminated_image_path = terminated_image_path,
            .title = owned_title,
            .priority = owned_priority,
            .message = owned_message,
            .created_at = rl.getTime(),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Toast) void {
        if (self.texture) |texture| {
            rl.unloadTexture(texture);
        }
        if (self.terminated_image_path) |tip| {
            self.allocator.free(tip);
        }
        if (self.title) |title| {
            self.allocator.free(title.ptr[0 .. title.len + 1]);
        }
        if (self.message) |message| {
            self.allocator.free(message.ptr[0 .. message.len + 1]);
        }
        if (self.priority) |priority| {
            self.allocator.free(priority.ptr[0 .. priority.len + 1]);
        }
    }
};

pub const ToastManager = struct {
    toasts: std.ArrayList(Toast),
    allocator: std.mem.Allocator,

    var font: ?rl.Font = null;

    pub fn init(allocator: std.mem.Allocator) !ToastManager {
        font = try rl.loadFontEx("assets/font.ttf", 32, null);
        return ToastManager{
            .toasts = std.ArrayList(Toast).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ToastManager) void {
        if (font) |f| {
            rl.unloadFont(f);
            font = null;
        }
        for (self.toasts.items) |*toast| {
            toast.deinit();
        }
        self.toasts.deinit();
    }

    pub fn show(self: *ToastManager, image_path: ?[]const u8, title: ?[]const u8, priority: ?[]const u8, message: ?[]const u8) !void {
        const toast = try Toast.init(self.allocator, image_path, title, priority, message);
        try self.toasts.append(toast);
    }

    pub fn update(self: *ToastManager) void {
        const current_time = rl.getTime();
        var i: usize = 0;
        while (i < self.toasts.items.len) {
            var toast = &self.toasts.items[i];
            const age = @as(f32, @floatCast(current_time - toast.created_at));

            if (age < toast.fade_speed) {
                toast.opacity = age / toast.fade_speed;
            } else if (age > toast.lifetime - toast.fade_speed) {
                toast.opacity = 1.0 - (age - (toast.lifetime - toast.fade_speed)) / toast.fade_speed;
            } else {
                toast.opacity = 1.0;
            }

            if (age >= toast.lifetime) {
                toast.deinit();
                _ = self.toasts.orderedRemove(i);
                continue;
            }

            const target_y = @as(f32, @floatFromInt(i)) * (toast.height + toast.spacing) + 20;
            toast.y_offset += (target_y - toast.y_offset) * 0.1;

            i += 1;
        }
    }

    pub fn draw(self: *ToastManager) void {
        const screen_width = @as(f32, @floatFromInt(rl.getScreenWidth()));
        for (self.toasts.items) |toast| {
            const toast_width: f32 = 300;
            const x = screen_width - toast_width - toast.padding;
            const y = toast.padding + toast.y_offset;

            rl.drawRectangle(
                @as(i32, @intFromFloat(x)),
                @as(i32, @intFromFloat(y)),
                @as(i32, @intFromFloat(toast_width)),
                @as(i32, @intFromFloat(toast.height)),
                rl.Color{
                    .r = 0,
                    .g = 0,
                    .b = 0,
                    .a = @as(u8, @intFromFloat(180.0 * toast.opacity)),
                },
            );

            var image_offset: f32 = 0;

            if (toast.texture) |texture| {
                const max_height = toast.height - (toast.padding * 2);
                const scale = max_height / @as(f32, @floatFromInt(texture.height));
                image_offset = @as(f32, @floatFromInt(texture.width)) * scale + toast.padding;

                rl.drawTextureEx(
                    texture,
                    rl.Vector2{
                        .x = x + toast.padding,
                        .y = y + toast.padding,
                    },
                    0,
                    scale,
                    rl.Color{
                        .r = 255,
                        .g = 255,
                        .b = 255,
                        .a = @as(u8, @intFromFloat(255.0 * toast.opacity)),
                    },
                );
            }

            const text_x = x + toast.padding + image_offset;

            // Draw title if exists
            if (toast.title) |title| {
                rl.drawTextPro(
                    font.?,
                    title.ptr,
                    rl.Vector2{ .x = text_x, .y = y + toast.padding },
                    rl.Vector2{ .x = 0, .y = 0 },
                    0,
                    24,
                    0,
                    rl.Color{
                        .r = 255,
                        .g = 255,
                        .b = 255,
                        .a = @as(u8, @intFromFloat(255.0 * toast.opacity)),
                    },
                );
            }

            if (toast.message) |message| {
                rl.drawTextPro(
                    font.?,
                    message.ptr,
                    rl.Vector2{ .x = text_x, .y = y + toast.padding + 25 },
                    rl.Vector2{ .x = 0, .y = 0 },
                    0,
                    16,
                    0,
                    rl.Color{
                        .r = 255,
                        .g = 255,
                        .b = 255,
                        .a = @as(u8, @intFromFloat(255.0 * toast.opacity)),
                    },
                );
            }
        }
    }
};
