const std = @import("std");
const zim = @import("zim");
const c = @cImport({
    @cInclude("termios.h");
    @cInclude("unistd.h");
});

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

    var original: c.struct_termios = undefined;
    if (c.tcgetattr(c.STDIN_FILENO, &original) != 0) {
        return error.TerminalSettingsReadFailed;
    }
    var raw = original;
    c.cfmakeraw(&raw);
    raw.c_cc[c.VMIN] = 1;
    raw.c_cc[c.VTIME] = 0;

    if (c.tcsetattr(c.STDIN_FILENO, c.TCSAFLUSH, &raw) != 0) {
        return error.TerminalSettingsWriteFailed;
    }
    defer {
        if (c.tcsetattr(c.STDIN_FILENO, c.TCSAFLUSH, &original) != 0) {
            std.debug.print("Could not restore terminal settings.\n:", .{});
        }
    }

    while (true) {
        var key: [1]u8 = undefined;
        const count = try std.Io.File.stdin().readStreaming(
            init.io,
            &.{key[0..]},
        );
        if (count == 0) break;
        if (key[0] == 'q') break;
    }
}
