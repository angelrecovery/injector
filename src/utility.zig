//! General utilities used everywhere

const std = @import("std");
const win32 = @import("win32").everything;

/// Check if a handle is valid first, then close it
pub inline fn closeHandle(handle: ?win32.HANDLE) void {
    if (handle) |h| {
        _ = win32.CloseHandle(h);
    }
}

pub inline fn stringEndsWith(str: []const u8, suffix: []const u8) bool {
    if (suffix.len > str.len) return false;
    return std.mem.eql(u8, str[str.len - suffix.len ..], suffix);
}

/// Print an error with the last windows error under it
/// https://learn.microsoft.com/en-us/windows/win32/debug/system-error-codes--0-499-
const win_log = std.log.scoped(.windows);
pub inline fn logErrWin(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) void {
    const last_error: u32 = @intFromEnum(win32.GetLastError());

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    const fmter = win32.fmtError(last_error);
    fmter.format(
        "s",
        .{},
        buf.writer(),
    ) catch {
        return;
    };

    // Make the message fully lowercase, maybe
    // a little dumb but it makes stuff match
    buf.items[0] = buf.items[0] + 32;

    std.log.err(fmt, args);
    win_log.err("{s}", .{buf.items});
}

const PidErrorWindow = error{
    FailedAlloc,
    FailedSearch,
    FailedFetch,
};

const PidErrorExe = error{
    FailedAlloc,
    FailedSnapshot,
    FailedSearch,
};

const WindowSearchType = enum(u1) {
    window_title,
    window_class,
};

pub fn getPidByWindow(allocator: std.mem.Allocator, str: []const u8, search_type: WindowSearchType) PidErrorWindow!u32 {
    const wide_str = std.unicode.utf8ToUtf16LeAllocZ(allocator, str) catch {
        return error.FailedAlloc;
    };

    var window: ?win32.HWND = undefined;

    if (search_type == .window_title) {
        window = win32.FindWindowW(null, wide_str);
    } else {
        window = win32.FindWindowW(wide_str, null);
    }

    if (window == null) {
        return error.FailedSearch;
    }

    var pid: u32 = undefined;

    if (win32.GetWindowThreadProcessId(window, &pid) == 0) {
        return error.FailedFetch;
    }

    return pid;
}
