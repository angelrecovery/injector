const std = @import("std");
const injector = @import("injector.zig");
const Args = @import("Args.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    const args = Args.parse(alloc) catch |err| {
        switch (err) {
            error.FailedAlloc => std.log.err("failed to allocate memory for args", .{}),
            error.MissingLib => std.log.err("no shared library supplied", .{}),
            error.MissingPid => std.log.err("no target supplied", .{}),
            error.InvalidTarget => std.log.err("invalid target supplied", .{}),
            else => unreachable,
        }

        printUsage();
        return;
    };

    std.log.info("target: {d}", .{args.pid});
    std.log.info("library: {s}", .{args.lib});

    injector.loadLibraryInject(args.pid, args.lib, .create_remote_thread) catch |err| {
        switch (err) {
            error.FailedOpen => std.log.err("failed to open handle to target", .{}),
            error.FailedKernel32 => std.log.err("failed to fetch kernel32.dll", .{}),
            error.FailedLoadLibrary => std.log.err("failed to fetch ll", .{}),
            error.FailedAlloc => std.log.err("failed to allocate memory for library path in target", .{}),
            error.FailedWrite => std.log.err("failed to write library to target", .{}),
            error.FailedRemoteHandle => std.log.err("failed to open remote handle in target", .{}),
            else => unreachable,
        }
    };
}

fn printUsage() void {
    std.debug.print("Usage: {s} --target <pid> --lib <shared_library_path>\n\n", .{Args.name_on_disk});
    std.debug.print("Inject a shared library into a running process\n", .{});
}
