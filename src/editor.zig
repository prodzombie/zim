const std = @import("std");

pub const Mode = enum {
    normal,
    insert,
};

pub const Selection = struct {
    anchor: usize = 0,
    head: usize = 0,
    desired_column: usize = 0,
};

pub const Editor = struct {
    content: []const u8,
    selections: []Selection,
    primary_index: usize = 0,
    mode: Mode = .normal,

    pub fn moveHorizontal(self: *Editor, motion: Motion) void {
        for (self.selections) |*selection| {
            switch (motion) {
                .left => {
                    if (selection.head > 0 and self.content[selection.head - 1] != '\n') {
                        selection.head -= 1;
                    }
                },
                .right => {
                    if (selection.head < self.content.len and
                        self.content[selection.head] != '\n' and
                        selection.head + 1 < self.content.len and
                        self.content[selection.head + 1] != '\n')
                    {
                        selection.head += 1;
                    }
                },
                .up, .down => unreachable,
            }
            selection.anchor = selection.head;

            var line_start = selection.head;
            while (line_start > 0 and
                self.content[line_start - 1] != '\n')
            {
                line_start -= 1;
            }
            selection.desired_column = selection.head - line_start;
        }
    }

    pub fn moveVertical(self: *Editor, motion: Motion) void {
        for (self.selections) |*selection| {
            var line_start = selection.head;
            while (line_start > 0 and
                self.content[line_start - 1] != '\n')
            {
                line_start -= 1;
            }

            var target_start: usize = undefined;
            var target_end: usize = undefined;

            switch (motion) {
                .up => {
                    if (line_start == 0) continue;

                    target_end = line_start - 1;
                    target_start = target_end;

                    while (target_start > 0 and
                        self.content[target_start - 1] != '\n')
                    {
                        target_start -= 1;
                    }
                },
                .down => {
                    var line_end = selection.head;
                    while (line_end < self.content.len and
                        self.content[line_end] != '\n')
                    {
                        line_end += 1;
                    }

                    if (line_end == self.content.len) continue;

                    target_start = line_end + 1;

                    // A final newline terminates the last line;
                    // it doesn't create another Vim cursor line.
                    if (target_start == self.content.len) continue;

                    target_end = target_start;
                    while (target_end < self.content.len and
                        self.content[target_end] != '\n')
                    {
                        target_end += 1;
                    }
                },
                .left, .right => unreachable,
            }

            const line_length = target_end - target_start;
            const last_column = if (line_length == 0)
                0
            else
                line_length - 1;

            selection.head = target_start +
                @min(selection.desired_column, last_column);
            selection.anchor = selection.head;
        }
    }
};

test "horizontal movement stays within a line" {
    var selections = [_]Selection{.{}};
    var editor: Editor = .{
        .content = "ab\ncd",
        .selections = selections[0..],
    };

    editor.moveHorizontal(.left);
    try std.testing.expectEqual(@as(usize, 0), selections[0].head);

    editor.moveHorizontal(.right);
    try std.testing.expectEqual(@as(usize, 1), selections[0].head);
    try std.testing.expectEqual(@as(usize, 1), selections[0].anchor);
    try std.testing.expectEqual(@as(usize, 1), selections[0].desired_column);

    editor.moveHorizontal(.right);
    try std.testing.expectEqual(@as(usize, 1), selections[0].head);

    selections[0].head = 3;
    editor.moveHorizontal(.left);
    try std.testing.expectEqual(@as(usize, 3), selections[0].head);
}

test "vertical movement preserves the desired column" {
    var selections = [_]Selection{
        .{
            .anchor = 3,
            .head = 3,
            .desired_column = 3,
        },
    };
    var editor: Editor = .{
        .content = "abcd\nxy\nabcd\n",
        .selections = selections[0..],
    };

    editor.moveVertical(.up);
    try std.testing.expectEqual(@as(usize, 3), selections[0].head);

    editor.moveVertical(.down);
    try std.testing.expectEqual(@as(usize, 6), selections[0].head);
    try std.testing.expectEqual(@as(usize, 3), selections[0].desired_column);

    editor.moveVertical(.down);
    try std.testing.expectEqual(@as(usize, 11), selections[0].head);
    try std.testing.expectEqual(@as(usize, 11), selections[0].anchor);

    editor.moveVertical(.down);
    try std.testing.expectEqual(@as(usize, 11), selections[0].head);

    editor.moveVertical(.up);
    try std.testing.expectEqual(@as(usize, 6), selections[0].head);
}

pub const Motion = enum {
    down,
    right,
    left,
    up,
};
