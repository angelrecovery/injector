const Args = @This();

const std = @import("std");
const builtin = @import("builtin");

const utility = @import("utility.zig");

//
target: union(TargetType) {
    pid: u32,
    window_title: []const u8,
    window_class: []const u8,
    exe_name: []const u8,
} = undefined,

lib: []const u8 = undefined,
//

/// The user can provide either a pid, a window title,
/// a class name, or the executable name of a target process
const TargetType = enum(u2) {
    pid,
    window_title,
    window_class,
    exe_name,
};

/// Name of the injector executable on disk
/// Used for the help message
pub var local_exe_name: []const u8 = undefined;

var args_iter: std.process.ArgIterator = undefined;

inline fn argExists(full: []const u8, short: []const u8, arg: []const u8) bool {
    return std.mem.eql(u8, arg, full) or std.mem.eql(u8, arg, short);
}

pub const ParseError = error{
    FailedAlloc,
    InvalidTarget,
    InvalidLib,
    MissingTarget,
    MissingLib,
};

pub inline fn deinit(args: *Args) void {
    _ = args;
    args_iter.deinit();
}

pub fn parse(alloc: std.mem.Allocator) ParseError!Args {
    args_iter = std.process.argsWithAllocator(alloc) catch {
        return error.FailedAlloc;
    };
    errdefer args_iter.deinit();

    // This should be the first argument
    if (builtin.mode == .Debug) {
        local_exe_name = "injector";
    } else {
        local_exe_name = std.fs.path.stem(std.fs.path.basename(args_iter.next().?));
    }

    var found_pid: ?u32 = null;
    var found_window_name: ?[]const u8 = null;
    var found_exe_name: ?[]const u8 = null;
    var found_class_name: ?[]const u8 = null;
    var found_lib: ?[]const u8 = null;

    while (args_iter.next()) |arg| {
        if (argExists("--pid", "-p", arg)) {
            if (args_iter.next()) |pid_str| {
                found_pid = std.fmt.parseInt(u32, pid_str, 10) catch {
                    return error.InvalidTarget;
                };
            }
        }

        if (argExists("--window_title", "-wt", arg)) {
            if (args_iter.next()) |window_name| {
                found_window_name = window_name;
            }
        }

        if (argExists("--window_class", "-wc", arg)) {
            if (args_iter.next()) |class_name| {
                found_class_name = class_name;
            }
        }

        if (argExists("--exe", "-e", arg)) {
            if (args_iter.next()) |exe_name| {
                found_exe_name = exe_name;
            }
        }

        if (argExists("--lib", "-l", arg)) {
            if (args_iter.next()) |lib| {
                found_lib = lib;
            }
        }
    }

    var parsed = Args{};

    // Ensure only one target type is specified
    const target_count =
        @intFromBool(found_pid != null) +
        @intFromBool(found_window_name != null) +
        @intFromBool(found_exe_name != null) +
        @intFromBool(found_class_name != null);

    if (target_count == 0) {
        return error.MissingTarget;
    }

    if (target_count > 1) {
        return error.InvalidTarget;
    }

    if (found_pid) |pid| {
        parsed.target = .{ .pid = pid };
    } else if (found_window_name) |window_name| {
        parsed.target = .{ .window_title = window_name };
    } else if (found_exe_name) |exe_name| {
        parsed.target = .{ .exe_name = exe_name };
    } else if (found_class_name) |class_name| {
        parsed.target = .{ .window_class = class_name };
    }

    if (found_lib) |lib| {
        parsed.lib = lib;
        // Not a .dll
        if (!utility.stringEndsWith(lib, ".dll")) {
            return error.InvalidLib;
        }
    } else {
        return error.MissingLib;
    }

    return parsed;
}
