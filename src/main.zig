const std = @import("std");

var stdout_buffer: [4096]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
const stdout = &stdout_writer.interface;
const Vec3 = @Vector(3, f64);
var pbuf: [1024]u8 = undefined;

inline fn vsplat(x: f64) Vec3 {
    return @as(Vec3, @splat(x));
}

pub const Ray = struct {
    origin: Vec3,
    dir: Vec3,

    fn at(self: @This(), t: f64) Vec3 {
        return self.origin + vsplat(t) * self.dir;
    }
};

pub const Hit = struct {
    p: Vec3,
    n: Vec3,
    t: f64,
    front_face: bool,

    pub fn set_face_normal(self: *Hit, ray: Ray, outward_normal: Vec3) void {
        const front = @reduce(.Add, ray.dir * outward_normal) < 0.0;
        self.front_face = front;
        self.n = if (front) outward_normal else -outward_normal;
    }
};

inline fn unit_vector(v: Vec3) Vec3 {
    const len = @sqrt(@reduce(.Add, v * v));
    return v / vsplat(len);
}

pub const Sphere = struct {
    center: Vec3,
    radius: f64,

    pub fn hit(self: Sphere, ray: Ray, tmin: f64, tmax: f64) ?Hit {
        const oc = self.center - ray.origin;
        const a = @reduce(.Add, ray.dir * ray.dir);
        const h = @reduce(.Add, ray.dir * oc);
        const c = @reduce(.Add, oc * oc) - self.radius * self.radius;

        const disc = h * h - a * c;
        if (disc < 0.0) return null;

        const sqrtd = std.math.sqrt(disc);

        var root = (h - sqrtd) / a;
        if (root <= tmin or root >= tmax) {
            root = (h + sqrtd) / a;
            if (root <= tmin or root >= tmax) return null;
        }

        var rec = Hit{
            .p = ray.at(root),
            .n = undefined,
            .t = root,
            .front_face = undefined,
        };

        const outward = (rec.p - self.center) / vsplat(self.radius);
        rec.set_face_normal(ray, outward);
        return rec;
    }
};

const Hittable = union(enum) {
    sphere: Sphere,

    pub fn hit(self: Hittable, r: Ray, tmin: f64, tmax: f64) ?Hit {
        return switch (self) {
            .sphere => |s| s.hit(r, tmin, tmax),
        };
    }
};

const HittableList = struct {
    objects: []const Hittable,

    pub fn hit(self: *const HittableList, r: Ray, tmin: f64, tmax: f64) ?Hit {
        var closest = tmax;
        var best: ?Hit = null;

        for (self.objects) |obj| {
            if (obj.hit(r, tmin, closest)) |h| {
                closest = h.t;
                best = h;
            }
        }
        return best;
    }
};

fn ray_color(r: Ray, world: *const HittableList) Vec3 {
    if (world.hit(r, 0.001, std.math.inf(f64))) |rec| {
        // Visualizza la normale come colore: 0.5 * (n + 1)
        return (rec.n + @as(Vec3, .{ 1.0, 1.0, 1.0 })) * vsplat(0.5);
    }

    const unit_direction = unit_vector(r.dir);
    const a: f64 = 0.5 * (unit_direction[1] + 1.0);
    return @as(Vec3, .{ 1.0, 1.0, 1.0 }) * vsplat(1.0 - a) + @as(Vec3, .{ 0.5, 0.7, 1.0 }) * vsplat(a);
}

pub fn write_color(pixel_color: Vec3) !void {
    const r: i32 = @intFromFloat(255.999 * pixel_color[0]);
    const g: i32 = @intFromFloat(255.999 * pixel_color[1]);
    const b: i32 = @intFromFloat(255.999 * pixel_color[2]);
    try stdout.print("{d} {d} {d}\n", .{ r, g, b });
}

pub fn main() !void {
    const aspect_ratio = 16.0 / 9.0;
    const img_width = 800;
    comptime var img_height: usize = @intFromFloat(@as(f64, @floatFromInt(img_width)) / aspect_ratio);
    if (img_height < 1) img_height = 1;

    const f_img_width: f64 = @as(f64, @floatFromInt(img_width));
    const f_img_height: f64 = @as(f64, @floatFromInt(img_height));

    const focal_length: f64 = 1.0;
    const viewport_height: f64 = 2.0;
    const viewport_width: f64 = viewport_height * (f_img_width / f_img_height);

    const camera_center: Vec3 = .{ 0.0, 0.0, 0.0 };

    const viewport_u: Vec3 = .{ viewport_width, 0.0, 0.0 };
    const viewport_v: Vec3 = .{ 0.0, -viewport_height, 0.0 };

    const pixel_delta_u = viewport_u / vsplat(f_img_width);
    const pixel_delta_v = viewport_v / vsplat(f_img_height);

    const viewport_upper_left =
        camera_center - @as(Vec3, .{ 0.0, 0.0, focal_length }) - viewport_u / vsplat(2.0) - viewport_v / vsplat(2.0);

    const pixel00_loc = viewport_upper_left + vsplat(0.5) * (pixel_delta_u + pixel_delta_v);

    var world_objs = [_]Hittable{
        .{ .sphere = Sphere{ .center = .{ 0.0, 0.0, -1.0 }, .radius = 0.5 } },
        .{ .sphere = Sphere{ .center = .{ 0.0, -100.5, -1.0 }, .radius = 100.0 } },
    };
    const world = HittableList{ .objects = world_objs[0..] };

    const root_node = std.Progress.start(.{ .draw_buffer = &pbuf, .root_name = "raytracing" });
    defer root_node.end();
    const sub_node = root_node.start("Scanlines", img_height);
    defer sub_node.end();

    try stdout.print("P3\n{d} {d}\n255\n", .{ img_width, img_height });

    for (0..img_height) |h| {
        sub_node.completeOne();
        for (0..img_width) |w| {
            const fw: f64 = @floatFromInt(w);
            const fh: f64 = @floatFromInt(h);

            const pixel_center = pixel00_loc + pixel_delta_u * vsplat(fw) + pixel_delta_v * vsplat(fh);

            const ray_direction = pixel_center - camera_center;
            const r = Ray{ .origin = camera_center, .dir = ray_direction };

            const color = ray_color(r, &world);
            try write_color(color);
        }
    }

    try stdout.flush();
    std.debug.print("\rDone.\n", .{});
}
