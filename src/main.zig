const std = @import("std");
const Progress = std.Progress;

var stdout_buffer: [4096]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
const stdout = &stdout_writer.interface;
const Vec3 = @Vector(3, f64);

pub fn write_color(pixel_color: Vec3) !void {
    const r: i32 = @intFromFloat(255.999 * pixel_color[0]);
    const g: i32 = @intFromFloat(255.999 * pixel_color[1]);
    const b: i32 = @intFromFloat(255.999 * pixel_color[2]);

    try stdout.print("{d} {d} {d}\n", .{ r, g, b });
}

pub fn main() !void {
    const img_width = 256;
    const img_height = 256;

    var pbuf: [1024]u8 = undefined;
    const pr = Progress.start(.{
        .draw_buffer = &pbuf,
        .root_name = "raytracing",
    });
    defer pr.end();

    try stdout.print("P3\n{d} {d}\n255\n", .{ img_width, img_height });

    for (0..img_height) |h| {
        pr.completeOne();
        for (0..img_width) |w| {
            const fw: f64 = @floatFromInt(w);
            const fh: f64 = @floatFromInt(h);
            // const r: u8 = @intFromFloat(255.999 * (fw / (img_width - 1.0)));
            // const g: u8 = @intFromFloat(255.999 * (fh / (img_height - 1.0)));
            // const b: u8 = 0;
            const color: Vec3 = .{ fw / (img_width - 1), fh / (img_height - 1), 0 };
            try write_color(color);
        }
    }
    try stdout.flush();
    std.debug.print("\rDone.\n", .{});
}
