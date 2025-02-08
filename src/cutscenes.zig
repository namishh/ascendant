const std = @import("std");
const rl = @import("raylib");

pub const Cutscene = struct {
    texture: ?rl.Texture2D,
    character_name: ?[:0]const u8,
    dialogue: ?[:0]const u8,
    color: rl.Color,
    terminated_image_path: ?[]u8 = null,
    dialogue_lines: std.ArrayList([:0]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, image_path: ?[]const u8, character_name: ?[]const u8, dialogue: ?[]const u8, color: ?rl.Color) !Cutscene {
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

        var owned_character_name: ?[:0]const u8 = null;
        var owned_dialogue: ?[:0]const u8 = null;

        if (character_name) |name| {
            const buf = try allocator.alloc(u8, name.len + 1);
            std.mem.copyForwards(u8, buf[0..name.len], name);
            buf[name.len] = 0;
            owned_character_name = buf[0..name.len :0];
        }
        if (dialogue) |msg| {
            const buf = try allocator.alloc(u8, msg.len + 1);
            std.mem.copyForwards(u8, buf[0..msg.len], msg);
            buf[msg.len] = 0;
            owned_dialogue = buf[0..msg.len :0];
        }

        return Cutscene{
            .texture = texture,
            .terminated_image_path = terminated_image_path,
            .character_name = owned_character_name,
            .dialogue = owned_dialogue,
            .allocator = allocator,
            .color = color orelse rl.Color.white,
            .dialogue_lines = std.ArrayList([:0]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Cutscene) void {
        if (self.texture) |texture| {
            rl.unloadTexture(texture);
        }
        if (self.terminated_image_path) |tip| {
            self.allocator.free(tip);
        }
        if (self.character_name) |name| {
            self.allocator.free(name.ptr[0 .. name.len + 1]);
        }
        if (self.dialogue) |msg| {
            self.allocator.free(msg.ptr[0 .. msg.len + 1]);
        }
        for (self.dialogue_lines.items) |line| {
            self.allocator.free(line.ptr[0 .. line.len + 1]);
        }
        self.dialogue_lines.deinit();
    }
};

pub const CutsceneManager = struct {
    cutscenes: std.ArrayList(Cutscene),
    allocator: std.mem.Allocator,
    current_cutscene_index: usize,
    is_playing: bool,
    shader: rl.Shader,
    resolution_loc: c_int,
    opacity_loc: c_int,
    position_loc: c_int,
    color1_loc: c_int,
    color2_loc: c_int,
    scale_loc: c_int,
    wood_shader: rl.Shader,
    wood_resolution_loc: c_int,
    wood_opacity_loc: c_int,
    wood_position_loc: c_int,

    var font: ?rl.Font = null;

    pub fn init(allocator: std.mem.Allocator) !CutsceneManager {
        font = try rl.loadFontEx("assets/font.ttf", 32, null);

        const shader = try rl.loadShader(null, "src/shaders/overlay.fs");

        const resolution_loc = rl.getShaderLocation(shader, "resolution");
        const opacity_loc = rl.getShaderLocation(shader, "opacity");
        const position_loc = rl.getShaderLocation(shader, "position");
        const color1_loc = rl.getShaderLocation(shader, "color1");
        const color2_loc = rl.getShaderLocation(shader, "color2");
        const scale_loc = rl.getShaderLocation(shader, "scale");

        const color1 = rl.Vector4{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.5 };
        const color2 = rl.Vector4{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.5 };
        rl.setShaderValue(shader, color1_loc, &color1, .vec4);
        rl.setShaderValue(shader, color2_loc, &color2, .vec4);

        const scale: f32 = 1.0;
        rl.setShaderValue(shader, scale_loc, &scale, .float);

        const wood_shader = try rl.loadShader(null, "src/shaders/wood.fs");
        const wood_resolution_loc = rl.getShaderLocation(wood_shader, "resolution");
        const wood_opacity_loc = rl.getShaderLocation(wood_shader, "opacity");
        const wood_position_loc = rl.getShaderLocation(wood_shader, "position");

        return CutsceneManager{
            .cutscenes = std.ArrayList(Cutscene).init(allocator),
            .allocator = allocator,
            .current_cutscene_index = 0,
            .is_playing = false,
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

    pub fn deinit(self: *CutsceneManager) void {
        if (font) |f| {
            rl.unloadFont(f);
            font = null;
        }
        rl.unloadShader(self.shader);
        rl.unloadShader(self.wood_shader);
        for (self.cutscenes.items) |*cutscene| {
            cutscene.deinit();
        }
        self.cutscenes.deinit();
    }

    pub fn sequence(self: *CutsceneManager, cutscene_list: std.ArrayList(Cutscene)) void {
        for (self.cutscenes.items) |*cutscene| {
            cutscene.deinit();
        }
        self.cutscenes.deinit();
        self.cutscenes = cutscene_list;
        self.current_cutscene_index = 0;
        self.is_playing = self.cutscenes.items.len > 0;
    }

    pub fn update(self: *CutsceneManager) void {
        if (!self.is_playing) return;

        if (rl.isKeyPressed(.space)) {
            self.current_cutscene_index += 1;
            if (self.current_cutscene_index >= self.cutscenes.items.len) {
                self.is_playing = false;
                self.current_cutscene_index = 0;
            }
        }
    }

    pub fn draw(self: *CutsceneManager) !void {
        if (!self.is_playing) return;
        if (self.current_cutscene_index >= self.cutscenes.items.len) {
            self.is_playing = false;
            return;
        }

        const screen_width = @as(f32, @floatFromInt(rl.getScreenWidth()));
        const screen_height = @as(f32, @floatFromInt(rl.getScreenHeight()));
        const cutscene = &self.cutscenes.items[self.current_cutscene_index];

        const overlay_resolution = rl.Vector2{ .x = screen_width, .y = screen_height };
        const overlay_position = rl.Vector2{ .x = 0, .y = 0 };
        const overlay_opacity: f32 = 1.0;

        rl.setShaderValue(self.shader, self.resolution_loc, &overlay_resolution, .vec2);
        rl.setShaderValue(self.shader, self.opacity_loc, &overlay_opacity, .float);
        rl.setShaderValue(self.shader, self.position_loc, &overlay_position, .vec2);

        rl.beginShaderMode(self.shader);
        rl.endShaderMode();

        const box_width: f32 = screen_width * 1;
        const box_height: f32 = screen_height * 0.34;
        const box_x: f32 = (screen_width - box_width);
        const box_y: f32 = screen_height - box_height;

        const border_height: f32 = 10;
        const wood_resolution = rl.Vector2{ .x = box_width, .y = border_height };
        const wood_position = rl.Vector2{ .x = box_x, .y = box_y };
        const wood_opacity: f32 = 1.0;

        rl.setShaderValue(self.wood_shader, self.wood_resolution_loc, &wood_resolution, .vec2);
        rl.setShaderValue(self.wood_shader, self.wood_opacity_loc, &wood_opacity, .float);
        rl.setShaderValue(self.wood_shader, self.wood_position_loc, &wood_position, .vec2);

        rl.beginShaderMode(self.wood_shader);
        rl.drawRectangle(@as(i32, @intFromFloat(box_x)), @as(i32, @intFromFloat(box_y)), @as(i32, @intFromFloat(box_width)), @as(i32, @intFromFloat(border_height)), rl.Color.white);
        rl.endShaderMode();

        rl.drawRectangleRec(rl.Rectangle{ .x = box_x, .y = box_y + 10, .width = box_width, .height = box_height - 10 }, rl.Color{ .r = 199, .g = 179, .b = 161, .a = 255 });

        var text_start_x: f32 = box_x + 20;
        const text_start_y: f32 = box_y + border_height + 20;
        const text_width_limit: f32 = box_width - 40;
        var image_offset_x: f32 = 0;

        if (cutscene.texture) |texture| {
            const texture_aspect_ratio = @as(f32, @floatFromInt(texture.width)) / @as(f32, @floatFromInt(texture.height));

            const scale_factor: f32 = 1.25;

            const card_width: f32 = (box_height - 40) * scale_factor;
            const card_height: f32 = card_width / texture_aspect_ratio;

            const card_x = 0; // Adjust x for protrusion

            const card_y = box_y + border_height + 20 - (card_height - (box_height - 40)) / 2; // Adjust y for protrusion

            rl.drawTexturePro(
                texture,
                rl.Rectangle{ .x = 0, .y = 0, .width = @as(f32, @floatFromInt(texture.width)), .height = @as(f32, @floatFromInt(texture.height)) },
                rl.Rectangle{ .x = card_x, .y = card_y, .width = card_width, .height = card_height },
                rl.Vector2{ .x = 0, .y = 0 },
                0,
                rl.Color.white,
            );

            image_offset_x = card_width + 20; // Adjust offset based on the scaled image width
            text_start_x += image_offset_x;
        }
        if (cutscene.character_name) |name| {
            rl.drawTextPro(font.?, name.ptr, rl.Vector2{ .x = text_start_x, .y = text_start_y - 10 }, rl.Vector2{ .x = 0, .y = 0 }, 0, 50, 0, cutscene.color);
        }

        if (cutscene.dialogue) |dialogue_text| {
            for (cutscene.dialogue_lines.items) |line| {
                cutscene.allocator.free(line.ptr[0 .. line.len + 1]);
            }
            cutscene.dialogue_lines.clearRetainingCapacity();

            var words = std.mem.splitScalar(u8, dialogue_text, ' ');
            var current_line = std.ArrayList(u8).init(cutscene.allocator);
            defer current_line.deinit();

            while (words.next()) |word| {
                if (current_line.items.len == 0) {
                    try current_line.appendSlice(word);
                } else {
                    const space_needed = current_line.items.len + 1 + word.len;
                    var test_line = try cutscene.allocator.allocSentinel(u8, space_needed, 0);
                    defer cutscene.allocator.free(test_line[0 .. space_needed + 1]);

                    @memcpy(test_line[0..current_line.items.len], current_line.items);
                    test_line[current_line.items.len] = ' ';
                    @memcpy(test_line[current_line.items.len + 1 ..][0..word.len], word);

                    const width = rl.measureTextEx(font.?, test_line[0..space_needed :0], 20, 0).x;

                    if (width <= text_width_limit - image_offset_x) {
                        try current_line.append(' ');
                        try current_line.appendSlice(word);
                    } else {
                        var line_buf = try cutscene.allocator.allocSentinel(u8, current_line.items.len, 0);
                        @memcpy(line_buf[0..current_line.items.len], current_line.items);
                        try cutscene.dialogue_lines.append(line_buf[0..current_line.items.len :0]);

                        current_line.clearRetainingCapacity();
                        try current_line.appendSlice(word);
                    }
                }
            }

            if (current_line.items.len > 0) {
                var final_line = try cutscene.allocator.allocSentinel(u8, current_line.items.len, 0);
                @memcpy(final_line[0..current_line.items.len], current_line.items);
                try cutscene.dialogue_lines.append(final_line[0..current_line.items.len :0]);
            }

            var current_y = text_start_y + 40;
            for (cutscene.dialogue_lines.items) |line| {
                rl.drawTextPro(font.?, line.ptr, rl.Vector2{ .x = text_start_x, .y = current_y }, rl.Vector2{ .x = 0, .y = 0 }, 0, 32, 0, rl.Color.black);
                current_y += 22;
            }
        }
    }
};
