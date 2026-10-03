const editor = @import("editor.zig");

pub const Editor = editor.Editor;
pub const Selection = editor.Selection;
pub const Mode = editor.Mode;
pub const Motion = editor.Motion;

test {
    @import("std").testing.refAllDecls(editor);
}
