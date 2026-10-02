const std = @import("std");
const zim = @import("zim");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);

    if (args.len != 2) {
        std.debug.print("Usage: zim <file>\n", .{});
        std.process.exit(1);
    }

    const path = args[1];
    const content = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(1024 * 1024));
    defer init.gpa.free(content);

    var buffer: [1024]u8 = undefined;
    var stdout: std.Io.File.Writer = .init(
        .stdout(),
        init.io,
        &buffer,
    );
    try stdout.interface.writeAll(content);
    try stdout.interface.flush();
}
