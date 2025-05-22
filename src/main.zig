const std = @import("std");
const injector = @import("injector.zig");
const Args = @import("Args.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    const args = Args.parse(alloc) catch |err| {
        switch (err) {
            error.FailedAlloc => std.log.err("failed to allocate memory for args\n", .{}),
            error.MissingLib => std.log.err("no shared library supplied\n", .{}),
            error.MissingPid => std.log.err("no target supplied\n", .{}),
            error.InvalidTarget => std.log.err("invalid target supplied\n", .{}),
            else => unreachable,
        }

        printUsage();
        return;
    };

    std.log.info("target: {d}\n", .{args.pid});
    std.log.info("library: {s}\n", .{args.lib});

    injector.loadLibraryInject(args.pid, args.lib, .create_remote_thread) catch |err| {
        switch (err) {
            error.FailedOpen => std.log.err("failed to open handle to target\n", .{}),
            error.FailedKernel32 => std.log.err("failed to fetch kernel32.dll\n", .{}),
            error.FailedLoadLibrary => std.log.err("failed to fetch ll\n", .{}),
            error.FailedAlloc => std.log.err("failed to allocate memory for library path in target\n", .{}),
            error.FailedWrite => std.log.err("failed to write library to target\n", .{}),
            error.FailedRemoteHandle => std.log.err("failed to open remote handle in target\n", .{}),
            else => unreachable,
        }
    };
}

fn printUsage() void {
    std.debug.print("Usage: {s} --target <pid> --lib <shared_library_path>\n\n", .{"injector"});
    std.debug.print("Inject a shared library into a running process\n", .{});
}
