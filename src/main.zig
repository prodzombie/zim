const std = @import("std");
const zim = @import("zim");

pub fn main(init: std.process.Init) !void {
    var buffer: [1024]u8 = undefined;
    var stdout: std.Io.File.Writer = .init(
        .stdout(),
        init.io,
        &buffer,
    );
    try zim.printAnotherMessage(&stdout.interface);
    try stdout.interface.flush();
}
