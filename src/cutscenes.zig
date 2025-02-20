const std = @import("std");
const rl = @import("raylib");
const TextureCache = @import("texture-cache.zig").TextureCache;

pub const Cutscene = struct {
    texture: ?rl.Texture2D,
    character_name: ?[:0]const u8,
    dialogue: ?[:0]const u8,
    color: rl.Color,
    dialogue_lines: std.ArrayList([:0]const u8),
    allocator: std.mem.Allocator,
    chars_to_show: usize,
    last_char_time: f64,
    char_delay: f64,

    pub fn init(allocator: std.mem.Allocator, texture: rl.Texture2D, character_name: ?[]const u8, dialogue: ?[]const u8, color: ?rl.Color) !Cutscene {
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
            .character_name = owned_character_name,
            .dialogue = owned_dialogue,
            .allocator = allocator,
            .color = color orelse rl.Color.white,
            .dialogue_lines = std.ArrayList([:0]const u8).init(allocator),
            .chars_to_show = 0,
            .last_char_time = 0,
            .char_delay = 0.03,
        };
    }

    pub fn deinit(self: *Cutscene) void {
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
    scale_loc: c_int,
    wood_texture: rl.Texture2D,
    resource_cache: TextureCache,

    var font: ?rl.Font = null;

    pub fn init(allocator: std.mem.Allocator) !CutsceneManager {
        font = try rl.loadFontEx("assets/font.ttf", 108, null);

        const shader = try rl.loadShader(null, "src/shaders/overlay.fs");
        const resolution_loc = rl.getShaderLocation(shader, "resolution");
        const opacity_loc = rl.getShaderLocation(shader, "opacity");
        const position_loc = rl.getShaderLocation(shader, "position");
        const color1_loc = rl.getShaderLocation(shader, "color1");
        const scale_loc = rl.getShaderLocation(shader, "scale");

        const color1 = rl.Vector4{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.8 };
        rl.setShaderValue(shader, color1_loc, &color1, .vec4);

        const scale: f32 = 1.0;
        rl.setShaderValue(shader, scale_loc, &scale, .float);

        const wood_texture = try rl.loadTexture("assets/parchment.png");

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
            .scale_loc = scale_loc,
            .wood_texture = wood_texture,
            .resource_cache = TextureCache.init(allocator),
        };
    }

    pub fn deinit(self: *CutsceneManager) void {
        if (font) |f| {
            rl.unloadFont(f);
            font = null;
        }
        rl.unloadShader(self.shader);
        rl.unloadTexture(self.wood_texture);
        for (self.cutscenes.items) |*cutscene| {
            cutscene.deinit();
        }
        self.cutscenes.deinit();
        self.resource_cache.deinit();
    }

    pub fn preloadResources(self: *CutsceneManager) !void {
        try self.resource_cache.preloadTexture("assets/valkyrie.png");
    }

    pub fn createCutscene(self: *CutsceneManager, texture_path: []const u8, character_name: []const u8, dialogue: []const u8, color: rl.Color) !Cutscene {
        const texture = self.resource_cache.getTexture(texture_path) orelse return error.TextureNotPreloaded;
        return try Cutscene.init(self.allocator, texture, character_name, dialogue, color);
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

        var cutscene = &self.cutscenes.items[self.current_cutscene_index];
        const current_time = rl.getTime();

        if (current_time - cutscene.last_char_time >= cutscene.char_delay) {
            cutscene.last_char_time = current_time;

            var total_chars: usize = 0;
            for (cutscene.dialogue_lines.items) |line| {
                total_chars += line.len;
            }

            if (cutscene.chars_to_show < total_chars) {
                cutscene.chars_to_show += 1;
            }
        }

        if (rl.isKeyPressed(.space)) {
            var total_chars: usize = 0;
            for (cutscene.dialogue_lines.items) |line| {
                total_chars += line.len;
            }

            if (cutscene.chars_to_show < total_chars) {
                cutscene.chars_to_show = total_chars;
            } else {
                self.current_cutscene_index += 1;
                if (self.current_cutscene_index < self.cutscenes.items.len) {
                    self.cutscenes.items[self.current_cutscene_index].chars_to_show = 0;
                    self.cutscenes.items[self.current_cutscene_index].last_char_time = current_time;
                } else {
                    self.is_playing = false;
                    self.current_cutscene_index = 0;
                }
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
        rl.drawRectangle(0, 0, rl.getScreenWidth(), rl.getScreenWidth(), rl.Color.white);
        rl.endShaderMode();

        const box_width: f32 = screen_width * 1;
        const box_height: f32 = screen_height * 0.3;
        const box_x: f32 = (screen_width - box_width);
        const box_y: f32 = screen_height - box_height;

        const texture_width = @as(f32, @floatFromInt(self.wood_texture.width));
        const texture_height = @as(f32, @floatFromInt(self.wood_texture.height));
        const tiles_x = @ceil(box_width / texture_width);
        const tiles_y = @ceil(box_height / texture_height);

        var ty: f32 = 0;
        while (ty < tiles_y) : (ty += 1) {
            var tx: f32 = 0;
            while (tx < tiles_x) : (tx += 1) {
                const draw_x = box_x + (tx * texture_width);
                const draw_y = box_y + (ty * texture_height);

                const tile_width = @min(texture_width, box_width - (tx * texture_width));
                const tile_height = @min(texture_height, box_height - (ty * texture_height));

                rl.drawTexturePro(
                    self.wood_texture,
                    rl.Rectangle{ .x = 0, .y = 0, .width = tile_width, .height = tile_height },
                    rl.Rectangle{ .x = draw_x, .y = draw_y, .width = tile_width, .height = tile_height },
                    rl.Vector2{ .x = 0, .y = 0 },
                    0,
                    rl.Color.white,
                );
            }
        }

        var text_start_x: f32 = box_x + 20;
        const text_start_y: f32 = box_y + 20;
        const text_width_limit: f32 = box_width - 40;
        var image_offset_x: f32 = 0;

        if (cutscene.texture) |texture| {
            const texture_aspect_ratio = @as(f32, @floatFromInt(texture.width)) / @as(f32, @floatFromInt(texture.height));
            const scale_factor: f32 = 1.5;
            const card_width: f32 = (box_height - 40) * scale_factor;
            const card_height: f32 = card_width / texture_aspect_ratio;
            const card_x = 0;
            const card_y = box_y + 20 - (card_height - (box_height - 40)) / 2;

            rl.drawTexturePro(
                texture,
                rl.Rectangle{ .x = 0, .y = 0, .width = @as(f32, @floatFromInt(texture.width)), .height = @as(f32, @floatFromInt(texture.height)) },
                rl.Rectangle{ .x = card_x, .y = card_y, .width = card_width, .height = card_height },
                rl.Vector2{ .x = 0, .y = 0 },
                0,
                rl.Color.white,
            );

            image_offset_x = card_width + 20;
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

                    const width = rl.measureTextEx(font.?, test_line[0..space_needed :0], 32, 0).x;

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
            var total_chars_shown: usize = 0;

            for (cutscene.dialogue_lines.items) |line| {
                const remaining_chars = if (cutscene.chars_to_show > total_chars_shown)
                    @min(line.len, cutscene.chars_to_show - total_chars_shown)
                else
                    0;

                if (remaining_chars > 0) {
                    var visible_text = try cutscene.allocator.allocSentinel(u8, remaining_chars, 0);
                    defer cutscene.allocator.free(visible_text[0 .. remaining_chars + 1]);
                    @memcpy(visible_text[0..remaining_chars], line[0..remaining_chars]);

                    rl.drawTextPro(
                        font.?,
                        visible_text.ptr,
                        rl.Vector2{ .x = text_start_x, .y = current_y },
                        rl.Vector2{ .x = 0, .y = 0 },
                        0,
                        32,
                        0,
                        rl.Color.white,
                    );
                }

                total_chars_shown += line.len;
                current_y += 32;
            }
        }
    }
};
