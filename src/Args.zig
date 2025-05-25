const Args = @This();

const std = @import("std");
const builtin = @import("builtin");

const utility = @import("utility.zig");

//
target: union(TargetType) {
    pid: u32,
    window_name: []const u8,
    exe_name: []const u8,
} = undefined,

lib: []const u8 = undefined,
//

/// The user can provide either a pid, a window name,
/// a class name, or the executable name of a target process
const TargetType = enum(u2) {
    pid,
    window_name,
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
    var found_target: ?[]const u8 = null;
    var found_lib: ?[]const u8 = null;

    while (args_iter.next()) |arg| {
        if (argExists("--target", "-t", arg)) {
            if (args_iter.next()) |target| {
                // If we can parse this argument as an integer, the user provided
                // the pid directly
                const parsed_pid = std.fmt.parseInt(u32, target, 10) catch null;

                if (parsed_pid) |pid| {
                    found_pid = pid;
                } else {
                    found_target = target;
                }
            }
        }

        if (argExists("--lib", "-l", arg)) {
            if (args_iter.next()) |lib| {
                found_lib = lib;
            }
        }
    }

    var parsed = Args{};

    if (found_pid) |pid| {
        parsed.target = .{ .pid = pid };
    } else if (found_target) |target| {
        // The user provided either a window name or an exe name
        // Now we determine which one
        if (utility.stringEndsWith(target, ".exe")) {
            parsed.target = .{ .exe_name = target };
        } else {
            parsed.target = .{ .window_name = target };
        }
    } else {
        return error.MissingTarget;
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
