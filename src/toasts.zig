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
    spacing: f32 = 20,
    terminated_image_path: ?[]u8 = null,
    title_lines: std.ArrayList([:0]const u8),
    message_lines: std.ArrayList([:0]const u8),
    y_position: f32 = 0,

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
            .title_lines = std.ArrayList([:0]const u8).init(allocator),
            .message_lines = std.ArrayList([:0]const u8).init(allocator),
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
        for (self.title_lines.items) |line| {
            self.allocator.free(line.ptr[0 .. line.len + 1]);
        }
        self.title_lines.deinit();
        for (self.message_lines.items) |line| {
            self.allocator.free(line.ptr[0 .. line.len + 1]);
        }
        self.message_lines.deinit();
    }

    pub fn getHeight(self: *const Toast) f32 {
        return self.height + self.spacing;
    }
};

pub const ToastManager = struct {
    toasts: std.ArrayList(Toast),
    allocator: std.mem.Allocator,
    max_height: f32,
    shader: rl.Shader,
    resolution_loc: c_int,
    opacity_loc: c_int,
    position_loc: c_int,
    color1_loc: c_int,
    color2_loc: c_int,
    scale_loc: c_int,
    wood_shader: rl.Shader, // New wood shader
    wood_resolution_loc: c_int, // Uniform location for wood shader
    wood_opacity_loc: c_int, // Uniform location for wood shader
    wood_position_loc: c_int, // Uniform location for wood shader

    var font: ?rl.Font = null;

    pub fn init(allocator: std.mem.Allocator) !ToastManager {
        font = try rl.loadFontEx("assets/font.ttf", 108, null);

        const fsPath = "src/shaders/checkerboard.fs";
        const shader: rl.Shader = try rl.loadShader(null, fsPath);

        const resolution_loc = rl.getShaderLocation(shader, "resolution");
        const opacity_loc = rl.getShaderLocation(shader, "opacity");
        const position_loc = rl.getShaderLocation(shader, "position");
        const color1_loc = rl.getShaderLocation(shader, "color1");
        const color2_loc = rl.getShaderLocation(shader, "color2");
        const scale_loc = rl.getShaderLocation(shader, "scale");

        const color1 = rl.Vector4{ .x = 137 / 255, .y = 160 / 255, .z = 60 / 255, .w = 1.0 };
        const color2 = rl.Vector4{ .x = 0.2862, .y = 0.207, .z = 0.164, .w = 1.0 };
        rl.setShaderValue(shader, color1_loc, &color1, .vec4);
        rl.setShaderValue(shader, color2_loc, &color2, .vec4);

        const scale: f32 = 20.0;
        rl.setShaderValue(shader, scale_loc, &scale, .float);

        // Load wood shader
        const woodFsPath = "src/shaders/wood.fs";
        const wood_shader: rl.Shader = try rl.loadShader(null, woodFsPath);
        const wood_resolution_loc = rl.getShaderLocation(wood_shader, "resolution");
        const wood_opacity_loc = rl.getShaderLocation(wood_shader, "opacity");
        const wood_position_loc = rl.getShaderLocation(wood_shader, "position");

        return ToastManager{
            .toasts = std.ArrayList(Toast).init(allocator),
            .allocator = allocator,
            .max_height = @as(f32, @floatFromInt(rl.getScreenHeight())) - 40, // Leave some margin
            .shader = shader,
            .resolution_loc = resolution_loc,
            .opacity_loc = opacity_loc,
            .position_loc = position_loc,
            .color1_loc = color1_loc,
            .color2_loc = color2_loc,
            .scale_loc = scale_loc,
            .wood_shader = wood_shader,
            .wood_resolution_loc = wood_resolution_loc,
            .wood_opacity_loc = wood_opacity_loc,
            .wood_position_loc = wood_position_loc,
        };
    }

    pub fn deinit(self: *ToastManager) void {
        if (font) |f| {
            rl.unloadFont(f);
            font = null;
        }
        rl.unloadShader(self.shader);
        rl.unloadShader(self.wood_shader); // Unload wood shader
        for (self.toasts.items) |*toast| {
            toast.deinit();
        }
        self.toasts.deinit();
    }

    fn wrapText(
        allocator: std.mem.Allocator,
        text: []const u8,
        fontSize: f32,
        maxWidth: f32,
    ) !std.ArrayList([:0]const u8) { // Changed return type
        var lines = std.ArrayList([:0]const u8).init(allocator);
        errdefer {
            for (lines.items) |line| {
                allocator.free(line[0 .. line.len + 1]);
            }
            lines.deinit();
        }

        var words = std.mem.splitScalar(u8, text, ' ');

        var current_line = std.ArrayList(u8).init(allocator);
        defer current_line.deinit();

        while (words.next()) |word| {
            if (current_line.items.len == 0) {
                try current_line.appendSlice(word);
            } else {
                const candidate_buf = try allocator.allocSentinel(u8, current_line.items.len + 1 + word.len, 0);
                defer allocator.free(candidate_buf);

                @memcpy(candidate_buf[0..current_line.items.len], current_line.items);
                candidate_buf[current_line.items.len] = ' ';
                @memcpy(candidate_buf[current_line.items.len + 1 ..][0..word.len], word);

                const width = rl.measureTextEx(font.?, candidate_buf, fontSize, 0).x;

                if (width <= maxWidth) {
                    try current_line.append(' ');
                    try current_line.appendSlice(word);
                } else {
                    // Create null-terminated line
                    const line_buf = try allocator.allocSentinel(u8, current_line.items.len, 0);
                    @memcpy(line_buf[0..current_line.items.len], current_line.items);
                    try lines.append(line_buf[0..current_line.items.len :0]);

                    current_line.clearRetainingCapacity();
                    try current_line.appendSlice(word);
                }
            }
        }

        // Add the last line if it exists
        if (current_line.items.len > 0) {
            const line_buf = try allocator.allocSentinel(u8, current_line.items.len, 0);
            @memcpy(line_buf[0..current_line.items.len], current_line.items);
            try lines.append(line_buf[0..current_line.items.len :0]);
        }

        return lines;
    }

    pub fn show(self: *ToastManager, image_path: ?[]const u8, title: ?[]const u8, priority: ?[]const u8, message: ?[]const u8) !void {
        var toast = try Toast.init(self.allocator, image_path, title, priority, message);
        errdefer toast.deinit();

        var scaled_width: f32 = 0;
        if (toast.texture) |texture| {
            const max_image_height: f32 = 80;
            const scale = max_image_height / @as(f32, @floatFromInt(texture.height));
            scaled_width = @as(f32, @floatFromInt(texture.width)) * scale;
        }

        const toast_width: f32 = 300;
        const available_text_width = toast_width - 3 * toast.padding - scaled_width;

        if (toast.title) |title_text| {
            toast.title_lines = try wrapText(toast.allocator, title_text, 24, // title font size
                available_text_width);
        }

        if (toast.message) |message_text| {
            toast.message_lines = try wrapText(toast.allocator, message_text, 20, // message font size
                available_text_width);
        }

        const title_line_height: f32 = 24 + 2; // font size + line spacing
        const message_line_height: f32 = 20 + 2;
        const title_lines_count = @as(f32, @floatFromInt(toast.title_lines.items.len));
        const message_lines_count = @as(f32, @floatFromInt(toast.message_lines.items.len));

        var content_height: f32 = 0;
        if (title_lines_count > 0) {
            content_height += title_lines_count * title_line_height;
        }
        if (message_lines_count > 0) {
            if (title_lines_count > 0) {
                content_height += 10; // spacing between title and message
            }
            content_height += message_lines_count * message_line_height;
        }

        // Account for image height if present
        if (toast.texture != null) {
            const image_height: f32 = 80;
            content_height = @max(content_height, image_height);
        }

        // Set final toast height with padding
        toast.height = content_height + (2 * toast.padding);

        // Calculate initial position
        var y_pos: f32 = 20; // Initial margin from top
        for (self.toasts.items) |existing_toast| {
            y_pos += existing_toast.getHeight();
        }
        toast.y_position = y_pos;

        // Check if we need to remove older toasts due to space constraints
        if (y_pos + toast.getHeight() > self.max_height and self.toasts.items.len > 0) {
            // Find how many toasts we need to remove
            var space_needed = y_pos + toast.getHeight() - self.max_height;
            while (space_needed > 0 and self.toasts.items.len > 0) {
                const oldest_toast = &self.toasts.items[0];
                oldest_toast.lifetime = 0; // Mark for removal
                space_needed -= oldest_toast.getHeight();
            }
        }

        // Add the new toast
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

                var j: usize = i;
                while (j < self.toasts.items.len) : (j += 1) {
                    var remaining_toast = &self.toasts.items[j];
                    remaining_toast.y_position -= toast.getHeight();
                }
                continue;
            }

            i += 1;
        }

        var current_y: f32 = 20;
        for (self.toasts.items) |*toast| {
            const target_y = current_y;
            toast.y_position += (target_y - toast.y_position) * 0.1;
            current_y += toast.getHeight();
            if (current_y > self.max_height) {
                if (self.toasts.items.len > 1) {
                    var oldest_toast = &self.toasts.items[0];
                    oldest_toast.lifetime = 0;
                }
            }
        }
    }

    pub fn draw(self: *ToastManager) void {
        const screen_width = @as(f32, @floatFromInt(rl.getScreenWidth()));
        for (self.toasts.items) |toast| {
            const toast_width: f32 = 300;
            const x = screen_width - toast_width - toast.padding;
            const y = toast.y_position;

            const border_padding: f32 = 6;
            const border_x = x - border_padding;
            const border_y = y - border_padding;
            const border_width = toast_width + 2 * border_padding;
            const border_height = toast.height + 2 * border_padding;

            const wood_resolution = rl.Vector2{ .x = border_width, .y = border_height };
            const wood_position = rl.Vector2{ .x = border_x, .y = border_y };
            const wood_opacity = toast.opacity; // Fade border with toast

            rl.setShaderValue(self.wood_shader, self.wood_resolution_loc, &wood_resolution, .vec2);
            rl.setShaderValue(self.wood_shader, self.wood_opacity_loc, &wood_opacity, .float);
            rl.setShaderValue(self.wood_shader, self.wood_position_loc, &wood_position, .vec2);

            rl.beginShaderMode(self.wood_shader);
            rl.drawRectangle(@as(i32, @intFromFloat(border_x)), @as(i32, @intFromFloat(border_y)), @as(i32, @intFromFloat(border_width)), @as(i32, @intFromFloat(border_height)), rl.Color.white);
            rl.endShaderMode();

            const resolution = rl.Vector2{ .x = toast_width, .y = toast.height };
            const position = rl.Vector2{ .x = x, .y = y };
            const opacity = toast.opacity;

            rl.setShaderValue(self.shader, self.resolution_loc, &resolution, .vec2);
            rl.setShaderValue(self.shader, self.opacity_loc, &opacity, .float);
            rl.setShaderValue(self.shader, self.position_loc, &position, .vec2);

            rl.beginShaderMode(self.shader);
            rl.drawRectangle(@as(i32, @intFromFloat(x)), @as(i32, @intFromFloat(y)), @as(i32, @intFromFloat(toast_width)), @as(i32, @intFromFloat(toast.height)), rl.Color.white);
            rl.endShaderMode();

            var image_offset: f32 = 0;

            if (toast.texture) |texture| {
                const max_image_height: f32 = 80;
                const scale = max_image_height / @as(f32, @floatFromInt(texture.height));
                const scaled_width = @as(f32, @floatFromInt(texture.width)) * scale;
                image_offset = scaled_width + toast.padding;

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
            var current_y = y + toast.padding;

            for (toast.title_lines.items) |line| {
                var color = rl.Color{
                    .r = 255,
                    .g = 255,
                    .b = 255,
                    .a = @as(u8, @intFromFloat(255.0 * toast.opacity)),
                };
                if (toast.priority) |priority| {
                    if (std.mem.eql(u8, priority, "error")) {
                        color = rl.Color{
                            .r = 237,
                            .g = 146,
                            .b = 185,
                            .a = @as(u8, @intFromFloat(255.0 * toast.opacity)),
                        };
                    } else if (std.mem.eql(u8, priority, "rare")) {
                        color = rl.Color{
                            .r = 145,
                            .g = 196,
                            .b = 237,
                            .a = @as(u8, @intFromFloat(255.0 * toast.opacity)),
                        };
                    }
                }
                rl.drawTextPro(
                    font.?,
                    line.ptr,
                    rl.Vector2{ .x = text_x, .y = current_y },
                    rl.Vector2{ .x = 0, .y = 0 },
                    0,
                    24,
                    0,
                    color,
                );
                current_y += 24 + 2;
            }

            current_y += 10;

            for (toast.message_lines.items) |line| {
                rl.drawTextPro(
                    font.?,
                    line.ptr,
                    rl.Vector2{ .x = text_x, .y = current_y },
                    rl.Vector2{ .x = 0, .y = 0 },
                    0,
                    20,
                    0,
                    rl.Color{
                        .r = 255,
                        .g = 255,
                        .b = 255,
                        .a = @as(u8, @intFromFloat(255.0 * toast.opacity)),
                    },
                );
                current_y += 20 + 2;
            }
        }
    }
};
