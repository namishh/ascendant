const std = @import("std");
const rl = @import("raylib");

pub const TextureCache = struct {
    textures: std.StringHashMap(rl.Texture2D),
    allocator: std.mem.Allocator,
    owned_paths: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) TextureCache {
        return .{
            .textures = std.StringHashMap(rl.Texture2D).init(allocator),
            .allocator = allocator,
            .owned_paths = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *TextureCache) void {
        var texture_iterator = self.textures.iterator();
        while (texture_iterator.next()) |entry| {
            rl.unloadTexture(entry.value_ptr.*);
        }

        for (self.owned_paths.items) |path| {
            self.allocator.free(path);
        }

        self.owned_paths.deinit();
        self.textures.deinit();
    }

    pub fn preloadTexture(self: *TextureCache, path: []const u8) !void {
        if (self.textures.contains(path)) return;

        var path_buffer = try self.allocator.allocSentinel(u8, path.len, 0);
        defer self.allocator.free(path_buffer);
        @memcpy(path_buffer[0..path.len], path);

        const texture = try rl.loadTexture(path_buffer);

        const owned_path = try self.allocator.dupe(u8, path);
        try self.owned_paths.append(owned_path);

        try self.textures.put(owned_path, texture);
    }

    pub fn getTexture(self: *TextureCache, path: []const u8) ?rl.Texture2D {
        return self.textures.get(path);
    }
};
