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

pub const Motion = enum {
    left,
    right,
};
