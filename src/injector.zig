const std = @import("std");
const win32 = @import("win32").everything;

pub const PidType = u32;

/// Thread creation method for LoadLibrary injections
/// create_remote_thread by default
const ThreadMethod = enum(u2) {
    create_remote_thread,
    nt_create_thread,
    rtl_create_user_thread,
};

/// Used to store the exit code of remote threads for
/// LoadLibrary injections
var ll_remote_thread_exit_code: u32 = undefined;

const PidErrorWindow = error{
    FailedSearch,
    FailedFetch,
};

const PidErrorExe = error{
    FailedSnapshot,
    FailedSearch,
};

const LoadLibraryError = error{
    FailedOpen,
    FailedKernel32,
    FailedLoadLibrary,
    FailedAlloc,
    FailedWrite,
    FailedRemoteHandle,
    TimedOut,
};

// const MMapError = error{};

/// Simply check if a handle is valid before closing it
inline fn closeHandle(handle: ?win32.HANDLE) void {
    if (handle) |h| {
        _ = win32.CloseHandle(h);
    }
}

fn checkLlThreadFinished(handle: win32.HANDLE) void {
    std.log.info("waiting on remote thread...", .{});

    while (true) {
        defer std.debug.print("\n", .{});

        std.Thread.sleep(100 * std.time.ns_per_ms);
        std.debug.print(".", .{});

        if (win32.GetExitCodeThread(handle, &ll_remote_thread_exit_code) == 0) {
            std.log.warn("\nfailed to get exit code of remote thread\n", .{});
            break;
        }

        if (ll_remote_thread_exit_code == win32.STILL_ACTIVE) {
            continue;
        }
    }
}

// pub fn getPidByWindowTitle(allocator: std.mem.Allocator, title: []const u8) !PidType {
//     const wide_title = try std.unicode.utf8ToUtf16LeAllocZ(allocator, title);
//
//     const window = win32.FindWindowW(null, wide_title);
//
//     if (window == null) {
//         return error.FailedSearch;
//     }
//
//     var pid: PidType = undefined;
//
//     if (win32.GetWindowThreadProcessId(window, &pid) == 0) {
//         return error.FailedFetch;
//     }
//
//     return pid;
// }

// pub fn getPidByExeName(allocator: std.mem.Allocator, name: []const u8) PidErrorExe!PidType {
//     const snapshot = win32.CreateToolHelp32Snapshot(.TH32CS_SNAPPROCESS, 0);
//
//     if (snapshot == .INVALID_HANDLE_VALUE) {
//         return error.FailedSnapshot;
//     }
//
//     defer closeHandle(snapshot);
//
//     var entry = win32.PROCESSENTRY32{};
//     entry.dwSize = @sizeOf(win32.PROCESSENTRY32);
//
//     if (!win32.Process32First(snapshot, &entry)) {
//         return error.FailedSearch;
//     }
//
//     const wide_name = std.unicode.utf8ToUtf16LeAlloc(allocator, name);
//     var pid: PidType = undefined;
//
//     while (win32.Process32Next(snapshot, &entry)) {
//         if (std.mem.eql(entry.szExeFile[0..name.len], wide_name)) {
//             pid = entry.dwProcessId;
//             break;
//         }
//     }
//
//     return pid;
// }

pub fn loadLibraryInject(pid: PidType, lib: []const u8, method: ThreadMethod) !void {
    // const createThreadMethod = getThreadMethod(method);
    _ = method;
    const createThreadMethod = win32.CreateRemoteThread;

    const process_access_rights = win32.PROCESS_ACCESS_RIGHTS{
        .CREATE_THREAD = 1,
        .QUERY_INFORMATION = 1,
        .VM_OPERATION = 1,
        .VM_WRITE = 1,
        .VM_READ = 1,
    };

    const process = win32.OpenProcess(process_access_rights, win32.FALSE, pid);

    if (process == null) {
        return error.FailedOpen;
    }

    defer closeHandle(process);

    const kernel32 = win32.GetModuleHandleA("kernel32.dll");

    if (kernel32 == null) {
        return error.FailedKernel32;
    }

    const loadlib = win32.GetProcAddress(kernel32, "LoadLibraryA");

    if (loadlib == null) {
        return error.FailedLoadLibrary;
    }

    const path_alloc = win32.VirtualAllocEx(process, null, lib.len, .{ .RESERVE = 1, .COMMIT = 1 }, win32.PAGE_READWRITE);

    if (path_alloc == null) {
        return error.FailedAlloc;
    }

    defer {
        const free_status = win32.VirtualFreeEx(process, path_alloc, 0, win32.MEM_RELEASE);
        if (free_status == 0) {
            std.log.warn("failed to free memory in target for sl path\n", .{});
        }
    }

    if (win32.WriteProcessMemory(process, path_alloc, lib.ptr, lib.len, null) == 0) {
        return error.FailedWrite;
    }

    const remote_thread = createThreadMethod(process, null, 0, @ptrCast(loadlib), path_alloc, 0, null);

    if (remote_thread == null) {
        return error.FailedRemoteHandle;
    }

    defer closeHandle(remote_thread);

    const ticker_thread = try std.Thread.spawn(.{}, checkLlThreadFinished, .{remote_thread.?});
    ticker_thread.detach();

    const wait_status = win32.WaitForSingleObject(remote_thread.?, 10000);

    if (wait_status == 0x00000102) {
        return error.TimedOut;
    }

    if (ll_remote_thread_exit_code != 0) {
        std.log.warn("remote thread exited with code {d}, the injection may have failed\n", .{ll_remote_thread_exit_code});
    }

    std.log.warn("finished\n", .{});
}
