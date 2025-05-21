const std = @import("std");
const PidType = @import("injector.zig").PidType;

/// Name of the injector executable on disk
/// Used for the help message
var name_on_disk: []const u8 = undefined;

pub const ArgsError = error{
    FailedAlloc,
    InvalidTarget,
    MissingPid,
    MissingLib,
};

pub const ParsedArgs = struct {
    pid: PidType,
    lib: []const u8,
};

pub fn parseArgs(alloc: std.mem.Allocator) !ParsedArgs {
    var args = std.process.argsWithAllocator(alloc) catch {
        return error.FailedAlloc;
    };
    defer args.deinit();

    var parsed: ParsedArgs = undefined;

    var found_pid = false;
    var found_lib = false;

    name_on_disk = std.fs.path.stem(std.fs.path.basename(args.next() orelse "injector"));

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--target") or std.mem.eql(u8, arg, "-t")) {
            if (args.next()) |pid| {
                parsed.pid = std.fmt.parseInt(PidType, pid, 10) catch {
                    return error.InvalidTarget;
                };
                found_pid = true;
            }
        }

        if (std.mem.eql(u8, arg, "--lib") or std.mem.eql(u8, arg, "-l")) {
            if (args.next()) |lib| {
                parsed.lib = alloc.dupe(u8, lib) catch {
                    return error.FailedAlloc;
                };
                found_lib = true;
            }
        }
    }

    if (!found_pid) {
        return error.MissingPid;
    }

    if (!found_lib) {
        return error.MissingLib;
    }

    return parsed;
}

pub fn info(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("\x1b[94minfo:\x1b[97m ", .{});
    std.debug.print(fmt, args);
    std.debug.print("\x1b[0m", .{});
}

pub fn warning(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("\x1b[93mwarning:\x1b[97m ", .{});
    std.debug.print(fmt, args);
    std.debug.print("\x1b[0m", .{});
}

/// Print error message
pub fn err(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("\x1b[91merror:\x1b[97m ", .{});
    std.debug.print(fmt, args);
    std.debug.print("\x1b[0m", .{});
}

/// Exit with error message and print usage
pub fn errWithHelp(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("\x1b[91merror:\x1b[97m ", .{});
    std.debug.print(fmt, args);
    std.debug.print("\x1b[0m\n", .{});
    std.debug.print("Usage: {s} --target <pid> --lib <shared_library_path>\n\n", .{name_on_disk});
    std.debug.print("Use LoadLibrary to inject a shared library into a running process\n", .{});
}
