const std = @import("std");

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
    std.debug.print("Usage: {s} --target <pid> --lib <shared_library_path>\n\n", .{"injector"});
    std.debug.print("Inject a shared library into a running process\n", .{});
}
