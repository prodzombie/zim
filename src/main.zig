const std = @import("std");
const zim = @import("zim");
const terminal = @import("terminal.zig");

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

    const raw_mode = try terminal.RawMode.enable();
    defer raw_mode.restore();

    defer terminal.leaveAlternateScreen(&stdout.interface);
    try terminal.enterAlternateScreen(&stdout.interface);
    try terminal.render(&editor, &stdout.interface);

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
            try terminal.render(&editor, &stdout.interface);
        }
    }
}
