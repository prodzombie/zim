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
};
