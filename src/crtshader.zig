// crtshader.zig
const rl = @import("raylib");
const std = @import("std");

pub const CRTShader = struct {
    shader: rl.Shader,
    time_loc: c_int,
    speed_loc: c_int,
    render_texture: rl.RenderTexture2D,
    current_speed: f32,
    target_speed: f32,
    transition_rate: f32,
    time: f32,

    pub fn init(screen_width: c_int, screen_height: c_int) !CRTShader {
        const shader = try rl.loadShader("src/shaders/crt.vs", "src/shaders/crt.fs");
        const time_loc = rl.getShaderLocation(shader, "time");
        const speed_loc = rl.getShaderLocation(shader, "scanSpeed"); // New uniform for scan speed

        const render_texture = try rl.loadRenderTexture(screen_width, screen_height);

        var default_speed: f32 = 0.35;
        var default_time: f32 = 0.0;
        rl.setShaderValue(shader, speed_loc, &default_speed, .float);
        rl.setShaderValue(shader, time_loc, &default_time, .float);

        return CRTShader{
            .shader = shader,
            .time_loc = time_loc,
            .speed_loc = speed_loc,
            .render_texture = render_texture,
            .current_speed = 0.35,
            .target_speed = 0.35,
            .transition_rate = 0.5,
            .time = 0.0,
        };
    }

    pub fn deinit(self: *CRTShader) void {
        rl.unloadShader(self.shader);
        rl.unloadRenderTexture(self.render_texture);
    }

    pub fn update(self: *CRTShader, delta_time: f32) void {
        self.time += delta_time;

        if (self.current_speed != self.target_speed) {
            const diff = self.target_speed - self.current_speed;
            const step = diff * self.transition_rate * delta_time;

            if (@abs(diff) < 0.01) {
                self.current_speed = self.target_speed;
            } else {
                self.current_speed += step;
            }
        }

        rl.setShaderValue(self.shader, self.speed_loc, &self.current_speed, .float);
        rl.setShaderValue(self.shader, self.time_loc, &self.time, .float);
    }

    pub fn setSpeed(self: *CRTShader, speed: f32) void {
        self.target_speed = speed;
    }

    pub fn beginRender(self: *CRTShader) void {
        rl.beginTextureMode(self.render_texture);
        rl.clearBackground(rl.Color.ray_white);
    }

    pub fn drawFinal(self: *CRTShader) void {
        rl.beginShaderMode(self.shader);
        rl.drawTextureRec(self.render_texture.texture, rl.Rectangle{
            .x = 0,
            .y = 0,
            .width = @as(f32, @floatFromInt(self.render_texture.texture.width)),
            .height = @as(f32, @floatFromInt(self.render_texture.texture.height)),
        }, rl.Vector2{ .x = 0, .y = 0 }, rl.Color.white);
        rl.endShaderMode();
    }
};
