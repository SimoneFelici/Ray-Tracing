const std = @import("std");

pub fn main() !void {
    const img_width: u32 = 256;
    const img_height: u32 = 256;
    var stdout_buffer: [1024]u8 = undefined;
    var file_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &file_writer.interface;

    try stdout.print("P3\n{d} {d}\n255\n", .{ img_width, img_height });
    for (0..img_height) |j| {
        for (0..img_width) |i| {
            const r = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(img_width - 1));
            const g = @as(f64, @floatFromInt(j)) / @as(f64, @floatFromInt(img_height - 1));
            const b = 0.0;

            const ir: u8 = @intFromFloat(255.999 * r);
            const ig: u8 = @intFromFloat(255.999 * g);
            const ib: u8 = @intFromFloat(255.999 * b);
            try stdout.print("{d} {d} {d}\n", .{ ir, ig, ib });
        }
    }
    try stdout.flush();
}
