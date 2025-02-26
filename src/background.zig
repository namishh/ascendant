const rl = @import("raylib");
const std = @import("std");

pub const Background = struct {
    shader: rl.Shader,
    time: f32,
    resolution: rl.Vector2,

    spin_rotation: f32 = -2.0,
    spin_speed: f32 = 2.0,
    offset: rl.Vector2 = rl.Vector2{ .x = 0.0, .y = 0.0 },
    color_1: rl.Color = rl.Color{ .r = 201, .g = 38, .b = 74, .a = 255 },
    color_2: rl.Color = rl.Color{ .r = 64, .g = 171, .b = 130, .a = 255 },
    color_3: rl.Color = rl.Color{ .r = 25, .g = 25, .b = 25, .a = 255 },
    contrast: f32 = 3.5,
    lighting: f32 = 0.4,
    spin_amount: f32 = 0.25,
    pixel_filter: f32 = 325.0,
    spin_ease: f32 = 1.0,
    is_rotate: bool = false,

    target_spin_rotation: f32 = -2.0,
    target_spin_speed: f32 = 2.0,
    target_offset: rl.Vector2 = rl.Vector2{ .x = 0.0, .y = 0.0 },
    target_color_1: rl.Color = rl.Color{ .r = 201, .g = 38, .b = 74, .a = 255 },
    target_color_2: rl.Color = rl.Color{ .r = 64, .g = 171, .b = 130, .a = 255 },
    target_color_3: rl.Color = rl.Color{ .r = 25, .g = 25, .b = 25, .a = 255 },
    target_contrast: f32 = 3.5,
    target_lighting: f32 = 0.4,
    target_spin_amount: f32 = 0.25,
    target_pixel_filter: f32 = 325.0,
    target_spin_ease: f32 = 1.0,
    target_is_rotate: bool = false,

    transition_active: [11]bool = [_]bool{false} ** 11,
    transition_times: [11]f32 = [_]f32{0.0} ** 11,
    transition_duration: f32 = 2,

    // Shader locations
    time_loc: c_int,
    resolution_loc: c_int,
    spin_rotation_loc: c_int,
    spin_speed_loc: c_int,
    offset_loc: c_int,
    color_1_loc: c_int,
    color_2_loc: c_int,
    color_3_loc: c_int,
    contrast_loc: c_int,
    lighting_loc: c_int,
    spin_amount_loc: c_int,
    pixel_filter_loc: c_int,
    spin_ease_loc: c_int,
    is_rotate_loc: c_int,

    // Property indices for transition arrays
    const PROP_SPIN_ROTATION = 0;
    const PROP_SPIN_SPEED = 1;
    const PROP_OFFSET = 2;
    const PROP_COLOR_1 = 3;
    const PROP_COLOR_2 = 4;
    const PROP_COLOR_3 = 5;
    const PROP_CONTRAST = 6;
    const PROP_LIGHTING = 7;
    const PROP_SPIN_AMOUNT = 8;
    const PROP_PIXEL_FILTER = 9;
    const PROP_SPIN_EASE = 10;

    pub fn init(screen_width: c_int, screen_height: c_int) !Background {
        const vs_path = "src/shaders/background.vs";
        const fs_path = "src/shaders/background.fs";
        const shader = try rl.loadShader(vs_path, fs_path);

        const resolution = rl.Vector2.init(
            @as(f32, @floatFromInt(screen_width)),
            @as(f32, @floatFromInt(screen_height)),
        );

        var bg = Background{
            .shader = shader,
            .time = 0.0,
            .resolution = resolution,
            .time_loc = rl.getShaderLocation(shader, "time"),
            .resolution_loc = rl.getShaderLocation(shader, "resolution"),
            .spin_rotation_loc = rl.getShaderLocation(shader, "SPIN_ROTATION"),
            .spin_speed_loc = rl.getShaderLocation(shader, "SPIN_SPEED"),
            .offset_loc = rl.getShaderLocation(shader, "OFFSET"),
            .color_1_loc = rl.getShaderLocation(shader, "COLOUR_1"),
            .color_2_loc = rl.getShaderLocation(shader, "COLOUR_2"),
            .color_3_loc = rl.getShaderLocation(shader, "COLOUR_3"),
            .contrast_loc = rl.getShaderLocation(shader, "CONTRAST"),
            .lighting_loc = rl.getShaderLocation(shader, "LIGTHING"),
            .spin_amount_loc = rl.getShaderLocation(shader, "SPIN_AMOUNT"),
            .pixel_filter_loc = rl.getShaderLocation(shader, "PIXEL_FILTER"),
            .spin_ease_loc = rl.getShaderLocation(shader, "SPIN_EASE"),
            .is_rotate_loc = rl.getShaderLocation(shader, "IS_ROTATE"),
        };

        // Set initial values
        try bg.updateAllUniforms();

        return bg;
    }

    pub fn deinit(self: *Background) void {
        rl.unloadShader(self.shader);
    }

    pub fn update(self: *Background, delta_time: f32) !void {
        self.time += delta_time;
        rl.setShaderValue(self.shader, self.time_loc, &self.time, .float);

        var updated = false;

        if (rl.isKeyDown(.b)) {
            if (rl.isKeyPressed(.up)) {
                self.setColor2(rl.Color{ .r = 252, .g = 92, .b = 125, .a = 255 }) catch {};
                self.setColor1(rl.Color{ .r = 106, .g = 130, .b = 251, .a = 255 }) catch {};
            }
            if (rl.isKeyPressed(.left)) {
                self.setColor2(rl.Color{ .r = 15, .g = 155, .b = 15, .a = 255 }) catch {};
                self.setColor1(rl.Color{ .r = 0, .g = 0, .b = 0, .a = 255 }) catch {};
            }
            if (rl.isKeyPressed(.right)) {
                self.setColor1(rl.Color{ .r = 201, .g = 38, .b = 74, .a = 255 }) catch {};
                self.setColor2(rl.Color{ .r = 64, .g = 171, .b = 130, .a = 255 }) catch {};
            }
            if (rl.isKeyPressed(.down)) {
                self.setColor2(rl.Color{ .r = 247, .g = 255, .b = 0, .a = 255 }) catch {};
                self.setColor1(rl.Color{ .r = 219, .g = 54, .b = 164, .a = 255 }) catch {};
            }
        }

        inline for (0..self.transition_active.len) |i| {
            if (self.transition_active[i]) {
                self.transition_times[i] += delta_time;

                if (self.transition_times[i] >= self.transition_duration) {
                    self.transition_active[i] = false;
                    self.transition_times[i] = 0.0;

                    switch (i) {
                        PROP_SPIN_ROTATION => self.spin_rotation = self.target_spin_rotation,
                        PROP_SPIN_SPEED => self.spin_speed = self.target_spin_speed,
                        PROP_OFFSET => self.offset = self.target_offset,
                        PROP_COLOR_1 => self.color_1 = self.target_color_1,
                        PROP_COLOR_2 => self.color_2 = self.target_color_2,
                        PROP_COLOR_3 => self.color_3 = self.target_color_3,
                        PROP_CONTRAST => self.contrast = self.target_contrast,
                        PROP_LIGHTING => self.lighting = self.target_lighting,
                        PROP_SPIN_AMOUNT => self.spin_amount = self.target_spin_amount,
                        PROP_PIXEL_FILTER => self.pixel_filter = self.target_pixel_filter,
                        PROP_SPIN_EASE => self.spin_ease = self.target_spin_ease,
                        else => {},
                    }
                } else {
                    const t = self.transition_times[i] / self.transition_duration;
                    const smoothT = t * t * (3.0 - 2.0 * t);

                    switch (i) {
                        PROP_SPIN_ROTATION => {
                            self.spin_rotation = self.lerp(self.spin_rotation, self.target_spin_rotation, smoothT);
                        },
                        PROP_SPIN_SPEED => {
                            self.spin_speed = self.lerp(self.spin_speed, self.target_spin_speed, smoothT);
                        },
                        PROP_OFFSET => {
                            self.offset.x = self.lerp(self.offset.x, self.target_offset.x, smoothT);
                            self.offset.y = self.lerp(self.offset.y, self.target_offset.y, smoothT);
                        },
                        PROP_COLOR_1 => {
                            self.color_1 = self.lerpColor(self.color_1, self.target_color_1, smoothT);
                        },
                        PROP_COLOR_2 => {
                            self.color_2 = self.lerpColor(self.color_2, self.target_color_2, smoothT);
                        },
                        PROP_COLOR_3 => {
                            self.color_3 = self.lerpColor(self.color_3, self.target_color_3, smoothT);
                        },
                        PROP_CONTRAST => {
                            self.contrast = self.lerp(self.contrast, self.target_contrast, smoothT);
                        },
                        PROP_LIGHTING => {
                            self.lighting = self.lerp(self.lighting, self.target_lighting, smoothT);
                        },
                        PROP_SPIN_AMOUNT => {
                            self.spin_amount = self.lerp(self.spin_amount, self.target_spin_amount, smoothT);
                        },
                        PROP_PIXEL_FILTER => {
                            self.pixel_filter = self.lerp(self.pixel_filter, self.target_pixel_filter, smoothT);
                        },
                        PROP_SPIN_EASE => {
                            self.spin_ease = self.lerp(self.spin_ease, self.target_spin_ease, smoothT);
                        },
                        else => {},
                    }
                }
                updated = true;
            }
        }

        if (updated) {
            try self.updateAllUniforms();
        }
    }

    pub fn draw(self: *Background, screen_width: c_int, screen_height: c_int) void {
        rl.beginShaderMode(self.shader);
        rl.drawRectangle(0, 0, screen_width, screen_height, rl.Color.white);
        rl.endShaderMode();
    }

    fn lerp(self: *Background, start: f32, end: f32, t: f32) f32 {
        _ = self;
        return start + t * (end - start);
    }

    fn lerpColor(self: *Background, start: rl.Color, end: rl.Color, t: f32) rl.Color {
        _ = self;
        return rl.Color{
            .r = @as(u8, @intFromFloat(@max(0.0, @min(255.0, @as(f32, @floatFromInt(start.r)) + t * @as(f32, @floatFromInt(@as(i16, end.r) - @as(i16, start.r))))))),
            .g = @as(u8, @intFromFloat(@max(0.0, @min(255.0, @as(f32, @floatFromInt(start.g)) + t * @as(f32, @floatFromInt(@as(i16, end.g) - @as(i16, start.g))))))),
            .b = @as(u8, @intFromFloat(@max(0.0, @min(255.0, @as(f32, @floatFromInt(start.b)) + t * @as(f32, @floatFromInt(@as(i16, end.b) - @as(i16, start.b))))))),
            .a = 255,
        };
    }

    const ColorComponent = enum {
        red,
        green,
        blue,
    };

    const ColorTarget = enum {
        all,
        color_1,
        color_2,
        color_3,
    };

    fn safeIncrement(value: u8, increment: u8) u8 {
        if (value >= 255 - increment) {
            return 255;
        } else {
            return value + increment;
        }
    }

    pub fn increaseColorComponent(self: *Background, component: ColorComponent, target: ColorTarget, increment: u8) !void {
        self.target_color_1 = self.color_1;
        self.target_color_2 = self.color_2;
        self.target_color_3 = self.color_3;

        switch (component) {
            .red => {
                if (target == .all or target == .color_1) {
                    self.target_color_1.r = safeIncrement(self.target_color_1.r, increment);
                    self.transition_active[PROP_COLOR_1] = true;
                    self.transition_times[PROP_COLOR_1] = 0.0;
                }
                if (target == .all or target == .color_2) {
                    self.target_color_2.r = safeIncrement(self.target_color_2.r, increment);
                    self.transition_active[PROP_COLOR_2] = true;
                    self.transition_times[PROP_COLOR_2] = 0.0;
                }
                if (target == .all or target == .color_3) {
                    self.target_color_3.r = safeIncrement(self.target_color_3.r, increment);
                    self.transition_active[PROP_COLOR_3] = true;
                    self.transition_times[PROP_COLOR_3] = 0.0;
                }
            },
            .green => {
                if (target == .all or target == .color_1) {
                    self.target_color_1.g = safeIncrement(self.target_color_1.g, increment);
                    self.transition_active[PROP_COLOR_1] = true;
                    self.transition_times[PROP_COLOR_1] = 0.0;
                }
                if (target == .all or target == .color_2) {
                    self.target_color_2.g = safeIncrement(self.target_color_2.g, increment);
                    self.transition_active[PROP_COLOR_2] = true;
                    self.transition_times[PROP_COLOR_2] = 0.0;
                }
                if (target == .all or target == .color_3) {
                    self.target_color_3.g = safeIncrement(self.target_color_3.g, increment);
                    self.transition_active[PROP_COLOR_3] = true;
                    self.transition_times[PROP_COLOR_3] = 0.0;
                }
            },
            .blue => {
                if (target == .all or target == .color_1) {
                    self.target_color_1.b = safeIncrement(self.target_color_1.b, increment);
                    self.transition_active[PROP_COLOR_1] = true;
                    self.transition_times[PROP_COLOR_1] = 0.0;
                }
                if (target == .all or target == .color_2) {
                    self.target_color_2.b = safeIncrement(self.target_color_2.b, increment);
                    self.transition_active[PROP_COLOR_2] = true;
                    self.transition_times[PROP_COLOR_2] = 0.0;
                }
                if (target == .all or target == .color_3) {
                    self.target_color_3.b = safeIncrement(self.target_color_3.b, increment);
                    self.transition_active[PROP_COLOR_3] = true;
                    self.transition_times[PROP_COLOR_3] = 0.0;
                }
            },
        }
    }

    fn colorToVec4(color: rl.Color) [4]f32 {
        return [_]f32{
            @as(f32, @floatFromInt(color.r)) / 255.0,
            @as(f32, @floatFromInt(color.g)) / 255.0,
            @as(f32, @floatFromInt(color.b)) / 255.0,
            @as(f32, @floatFromInt(color.a)) / 255.0,
        };
    }

    fn boolToInt(b: bool) c_int {
        return if (b) 1 else 0;
    }

    pub fn updateAllUniforms(self: *Background) !void {
        rl.setShaderValue(self.shader, self.time_loc, &self.time, .float);
        rl.setShaderValue(self.shader, self.resolution_loc, &self.resolution, .vec2);
        rl.setShaderValue(self.shader, self.spin_rotation_loc, &self.spin_rotation, .float);
        rl.setShaderValue(self.shader, self.spin_speed_loc, &self.spin_speed, .float);
        rl.setShaderValue(self.shader, self.offset_loc, &self.offset, .vec2);

        var color1_vec = colorToVec4(self.color_1);
        var color2_vec = colorToVec4(self.color_2);
        var color3_vec = colorToVec4(self.color_3);

        rl.setShaderValue(self.shader, self.color_1_loc, &color1_vec, .vec4);
        rl.setShaderValue(self.shader, self.color_2_loc, &color2_vec, .vec4);
        rl.setShaderValue(self.shader, self.color_3_loc, &color3_vec, .vec4);

        rl.setShaderValue(self.shader, self.contrast_loc, &self.contrast, .float);
        rl.setShaderValue(self.shader, self.lighting_loc, &self.lighting, .float);
        rl.setShaderValue(self.shader, self.spin_amount_loc, &self.spin_amount, .float);
        rl.setShaderValue(self.shader, self.pixel_filter_loc, &self.pixel_filter, .float);
        rl.setShaderValue(self.shader, self.spin_ease_loc, &self.spin_ease, .float);

        var rotate_int = boolToInt(self.is_rotate);
        rl.setShaderValue(self.shader, self.is_rotate_loc, &rotate_int, .int);
    }

    // All setter functions now use transitions
    pub fn setSpinRotation(self: *Background, value: f32) !void {
        self.target_spin_rotation = value;
        self.transition_active[PROP_SPIN_ROTATION] = true;
        self.transition_times[PROP_SPIN_ROTATION] = 0.0;
    }

    pub fn setSpinSpeed(self: *Background, value: f32) !void {
        self.target_spin_speed = value;
        self.transition_active[PROP_SPIN_SPEED] = true;
        self.transition_times[PROP_SPIN_SPEED] = 0.0;
    }

    pub fn setOffset(self: *Background, x: f32, y: f32) !void {
        self.target_offset = rl.Vector2{ .x = x, .y = y };
        self.transition_active[PROP_OFFSET] = true;
        self.transition_times[PROP_OFFSET] = 0.0;
    }

    pub fn setColor1(self: *Background, color: rl.Color) !void {
        self.target_color_1 = color;
        self.transition_active[PROP_COLOR_1] = true;
        self.transition_times[PROP_COLOR_1] = 0.0;
    }

    pub fn setColor2(self: *Background, color: rl.Color) !void {
        self.target_color_2 = color;
        self.transition_active[PROP_COLOR_2] = true;
        self.transition_times[PROP_COLOR_2] = 0.0;
    }

    pub fn setColor3(self: *Background, color: rl.Color) !void {
        self.target_color_3 = color;
        self.transition_active[PROP_COLOR_3] = true;
        self.transition_times[PROP_COLOR_3] = 0.0;
    }

    pub fn setContrast(self: *Background, value: f32) !void {
        self.target_contrast = value;
        self.transition_active[PROP_CONTRAST] = true;
        self.transition_times[PROP_CONTRAST] = 0.0;
    }

    pub fn setLighting(self: *Background, value: f32) !void {
        self.target_lighting = value;
        self.transition_active[PROP_LIGHTING] = true;
        self.transition_times[PROP_LIGHTING] = 0.0;
    }

    pub fn setSpinAmount(self: *Background, value: f32) !void {
        self.target_spin_amount = value;
        self.transition_active[PROP_SPIN_AMOUNT] = true;
        self.transition_times[PROP_SPIN_AMOUNT] = 0.0;
    }

    pub fn setPixelFilter(self: *Background, value: f32) !void {
        self.target_pixel_filter = value;
        self.transition_active[PROP_PIXEL_FILTER] = true;
        self.transition_times[PROP_PIXEL_FILTER] = 0.0;
    }

    pub fn setSpinEase(self: *Background, value: f32) !void {
        self.target_spin_ease = value;
        self.transition_active[PROP_SPIN_EASE] = true;
        self.transition_times[PROP_SPIN_EASE] = 0.0;
    }

    pub fn setIsRotate(self: *Background, value: bool) !void {
        self.is_rotate = value;
        var rotate_int = boolToInt(value);
        rl.setShaderValue(self.shader, self.is_rotate_loc, &rotate_int, .int);
    }
};
