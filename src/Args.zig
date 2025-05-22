const Args = @This();

const std = @import("std");
const PidType = @import("injector.zig").PidType;

pid: PidType = undefined,
lib: []const u8 = undefined,

/// Name of the injector executable on disk
/// Used for the help message
pub var name_on_disk: []const u8 = undefined;

pub const ParseError = error{
    FailedAlloc,
    InvalidTarget,
    MissingPid,
    MissingLib,
};

pub fn parse(alloc: std.mem.Allocator) ParseError!Args {
    var args = std.process.argsWithAllocator(alloc) catch {
        return error.FailedAlloc;
    };
    defer args.deinit();

    // This should be the first argument
    name_on_disk = alloc.dupe(u8, std.fs.path.stem(std.fs.path.basename(args.next().?))) catch "injector";

    var parsed: Args = undefined;

    // This is dumb
    var found_pid = false;
    var found_lib = false;

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
