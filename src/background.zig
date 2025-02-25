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
    }

    pub fn draw(self: *Background, screen_width: c_int, screen_height: c_int) void {
        rl.beginShaderMode(self.shader);
        rl.drawRectangle(0, 0, screen_width, screen_height, rl.Color.white);
        rl.endShaderMode();
    }

    // Helper function to convert Color to vec4
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

    pub fn setSpinRotation(self: *Background, value: f32) !void {
        self.spin_rotation = value;
        rl.setShaderValue(self.shader, self.spin_rotation_loc, &self.spin_rotation, .float);
    }

    pub fn setSpinSpeed(self: *Background, value: f32) !void {
        self.spin_speed = value;
        rl.setShaderValue(self.shader, self.spin_speed_loc, &self.spin_speed, .float);
    }

    pub fn setOffset(self: *Background, x: f32, y: f32) !void {
        self.offset = rl.Vector2{ .x = x, .y = y };
        rl.setShaderValue(self.shader, self.offset_loc, &self.offset, .vec2);
    }

    pub fn setColor1(self: *Background, color: rl.Color) !void {
        self.color_1 = color;
        var color_vec = self.colorToVec4(color);
        rl.setShaderValue(self.shader, self.color_1_loc, &color_vec, .vec4);
    }

    pub fn setColor2(self: *Background, color: rl.Color) !void {
        self.color_2 = color;
        var color_vec = self.colorToVec4(color);
        rl.setShaderValue(self.shader, self.color_2_loc, &color_vec, .vec4);
    }

    pub fn setColor3(self: *Background, color: rl.Color) !void {
        self.color_3 = color;
        var color_vec = self.colorToVec4(color);
        rl.setShaderValue(self.shader, self.color_3_loc, &color_vec, .vec4);
    }

    pub fn setContrast(self: *Background, value: f32) !void {
        self.contrast = value;
        rl.setShaderValue(self.shader, self.contrast_loc, &self.contrast, .float);
    }

    pub fn setLighting(self: *Background, value: f32) !void {
        self.lighting = value;
        rl.setShaderValue(self.shader, self.lighting_loc, &self.lighting, .float);
    }

    pub fn setSpinAmount(self: *Background, value: f32) !void {
        self.spin_amount = value;
        rl.setShaderValue(self.shader, self.spin_amount_loc, &self.spin_amount, .float);
    }

    pub fn setPixelFilter(self: *Background, value: f32) !void {
        self.pixel_filter = value;
        rl.setShaderValue(self.shader, self.pixel_filter_loc, &self.pixel_filter, .float);
    }

    pub fn setSpinEase(self: *Background, value: f32) !void {
        self.spin_ease = value;
        rl.setShaderValue(self.shader, self.spin_ease_loc, &self.spin_ease, .float);
    }

    pub fn setIsRotate(self: *Background, value: bool) !void {
        self.is_rotate = value;
        var rotate_int = boolToInt(value);
        rl.setShaderValue(self.shader, self.is_rotate_loc, &rotate_int, .int);
    }
};
