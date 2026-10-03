const std = @import("std");
const zim = @import("zim");
const c = @cImport({
    @cInclude("termios.h");
    @cInclude("unistd.h");
});

const Terminal = struct {
    const enter_alternate_screen = "\x1b[?1049h";
    const leave_alternate_screen = "\x1b[?1049l";
    const clear_screen = "\x1b[2J";
    const cursor_home = "\x1b[H";

    /// Positions the cursor using one-based terminal coordinates.
    fn moveCursor(writer: *std.Io.Writer, row: usize, column: usize) !void {
        try writer.print("\x1b[{d};{d}H", .{ row, column });
    }
};

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

    var selections = [_]zim.Selection{
        .{},
    };

    var editor: zim.Editor = .{
        .content = content,
        .selections = selections[0..],
    };

    var buffer: [1024]u8 = undefined;
    var stdout: std.Io.File.Writer = .init(
        .stdout(),
        init.io,
        &buffer,
    );

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
            std.debug.print("Could not restore terminal settings.\n", .{});
        }
    }

    defer {
        stdout.interface.writeAll(Terminal.leave_alternate_screen) catch {};
        stdout.interface.flush() catch {};
    }

    try stdout.interface.writeAll(Terminal.enter_alternate_screen);
    try render(&editor, &stdout.interface);

    while (true) {
        var key: [1]u8 = undefined;
        const count = try std.Io.File.stdin().readStreaming(
            init.io,
            &.{key[0..]},
        );
        if (count == 0) break;
        if (editor.mode == .normal) {
            if (key[0] == 'q') break;
            switch (key[0]) {
                'h' => editor.moveHorizontal(.left),
                'l' => editor.moveHorizontal(.right),
                else => {},
            }
            try render(&editor, &stdout.interface);
        }
    }
}

pub fn render(editor: *const zim.Editor, writer: *std.Io.Writer) !void {
    try writer.writeAll(Terminal.clear_screen);
    try writer.writeAll(Terminal.cursor_home);

    var lines = std.mem.splitScalar(u8, editor.content, '\n');
    var first = true;
    while (lines.next()) |line| {
        if (!first) try writer.writeAll("\r\n");
        try writer.writeAll(line);
        first = false;
    }

    const head = editor.selections[editor.primary_index].head;
    var row: usize = 1;
    var column: usize = 1;

    for (editor.content[0..head]) |byte| {
        if (byte == '\n') {
            row += 1;
            column = 1;
        } else {
            column += 1;
        }
    }

    try Terminal.moveCursor(writer, row, column);
    try writer.flush();
}
