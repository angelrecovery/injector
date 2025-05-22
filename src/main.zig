const std = @import("std");
const cli = @import("cli.zig");
const injector = @import("injector.zig");

const Args = @import("Args.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    const args = Args.parse(alloc) catch |err| {
        switch (err) {
            error.FailedAlloc => cli.err("failed to allocate memory for args\n", .{}),
            error.MissingLib => cli.errWithHelp("no shared library supplied\n", .{}),
            error.MissingPid => cli.errWithHelp("no target supplied\n", .{}),
            error.InvalidTarget => cli.errWithHelp("invalid target supplied\n", .{}),
            else => unreachable,
        }

        return;
    };

    cli.info("target: {d}\n", .{args.pid});
    cli.info("library: {s}\n", .{args.lib});

    injector.loadLibraryInject(args.pid, args.lib, .create_remote_thread) catch |err| {
        switch (err) {
            error.FailedOpen => cli.err("failed to open handle to target\n", .{}),
            error.FailedKernel32 => cli.err("failed to fetch kernel32.dll\n", .{}),
            error.FailedLoadLibrary => cli.err("failed to fetch ll\n", .{}),
            error.FailedAlloc => cli.err("failed to allocate memory for library path in target\n", .{}),
            error.FailedWrite => cli.err("failed to write library to target\n", .{}),
            error.FailedRemoteHandle => cli.err("failed to open remote handle in target\n", .{}),
            else => unreachable,
        }
    };
}
