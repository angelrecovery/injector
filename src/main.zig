const std = @import("std");
const utility = @import("utility.zig");
const injector = @import("injector.zig");
const Args = @import("Args.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const arena_alloc = arena.allocator();

    var args = Args.parse(arena_alloc) catch |err| {
        switch (err) {
            error.FailedAlloc => std.log.err("failed to allocate memory for args", .{}),
            error.MissingLib => std.log.err("no shared library supplied", .{}),
            error.MissingTarget => std.log.err("no target supplied", .{}),
            error.InvalidLib => std.log.err("invalid library suppllied", .{}),
            error.InvalidTarget => std.log.err("invalid target supplied", .{}),
            else => unreachable,
        }

        printUsage();
        return;
    };
    defer args.deinit();

    const target_pid = switch (args.target) {
        .pid => args.target.pid,
        .window_title => utility.getPidByWindow(
            arena_alloc,
            args.target.window_title,
            .window_title,
        ) catch {
            utility.logErrWin(arena_alloc, "failed to find target (window title search)", .{});
            return;
        },
        .window_class => utility.getPidByWindow(
            arena_alloc,
            args.target.window_class,
            .window_class,
        ) catch {
            utility.logErrWin(arena_alloc, "failed to find target (window class search)", .{});
            return;
        },
        .exe_name => unreachable,
    };

    injector.init(arena_alloc, target_pid) catch |err| {
        switch (err) {
            error.FailedOpen => utility.logErrWin(arena_alloc, "failed to open handle to target", .{}),
            error.NoKernel32 => utility.logErrWin(arena_alloc, "failed to fetch kernel32.dll", .{}),
            else => unreachable,
        }
        return;
    };
    defer injector.deinit();

    injector.inject(args.lib, .create_remote_thread) catch |err| {
        switch (err) {
            error.NoLoadLibrary => utility.logErrWin(arena_alloc, "failed to fetch ll", .{}),
            error.FailedVirtualAlloc => utility.logErrWin(arena_alloc, "failed to allocate memory for library path in target", .{}),
            error.FailedWrite => utility.logErrWin(arena_alloc, "failed to write library path to target", .{}),
            error.FailedCreateThread => utility.logErrWin(arena_alloc, "failed to create thread in target", .{}),
            error.FailedCheckerThread => utility.logErrWin(arena_alloc, "failed to create thread checker", .{}),
            error.TimedOut => utility.logErrWin(arena_alloc, "thread timed out", .{}),
            else => unreachable,
        }
    };
}

inline fn printUsage() void {
    std.debug.print("\nUsage: {s} (--pid,--exe,--window) --lib <shared_library_path>\n", .{Args.local_exe_name});
}
