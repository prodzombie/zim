const std = @import("std");
const zim = @import("zim");
const c = @cImport({
    @cInclude("termios.h");
    @cInclude("unistd.h");
});

const enter_alternate_screen = "\x1b[?1049h";
const leave_alternate_screen = "\x1b[?1049l";
const clear_screen = "\x1b[2J";
const cursor_home = "\x1b[H";

pub const RawMode = struct {
    original: c.struct_termios,

    pub fn enable() !RawMode {
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
        return .{ .original = original };
    }

    pub fn restore(self: *const RawMode) void {
        if (c.tcsetattr(c.STDIN_FILENO, c.TCSAFLUSH, &self.original) != 0) {
            std.debug.print("Could not restore terminal settings.\n", .{});
        }
    }
};

pub fn enterAlternateScreen(writer: *std.Io.Writer) !void {
    try writer.writeAll(enter_alternate_screen);
}

pub fn leaveAlternateScreen(writer: *std.Io.Writer) void {
    writer.writeAll(leave_alternate_screen) catch {};
    writer.flush() catch {};
}

/// Positions the cursor using one-based terminal coordinates.
fn moveCursor(writer: *std.Io.Writer, row: usize, column: usize) !void {
    try writer.print("\x1b[{d};{d}H", .{ row, column });
}

pub fn render(editor: *const zim.Editor, writer: *std.Io.Writer) !void {
    try writer.writeAll(clear_screen);
    try writer.writeAll(cursor_home);

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

    try moveCursor(writer, row, column);
    try writer.flush();
}
