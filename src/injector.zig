const std = @import("std");
const utility = @import("utility.zig");
const win32 = @import("win32").everything;

const log = std.log.scoped(.injector);

/// Thread creation method for LoadLibrary injections
/// create_remote_thread by default
const ThreadMethod = enum(u2) {
    create_remote_thread,
    nt_create_thread,
    rtl_create_user_thread,
};

const State = struct {
    alloc: std.mem.Allocator = undefined,

    target_pid: u32 = undefined,

    target_handle: ?win32.HANDLE = undefined,

    /// Module handle to kernel32.dll
    kernel32: ?win32.HINSTANCE = undefined,

    /// Ptr to the LoadLibrary function
    ll_fn: *const fn () callconv(.c) isize = undefined,
    /// Ptr to the FreeLibrary function
    fl_fn: *const fn () callconv(.c) isize = undefined,

    /// Exit code
    remote_thread_exit_code: u32 = undefined,
};
var state: State = .{};

const InitError = error{
    FailedOpen,
    NoKernel32,
};

const InjectError = error{
    NoLoadLibrary,
    FailedVirtualAlloc,
    FailedWrite,
    FailedCreateThread,
    FailedCheckerThread,
    TimedOut,
};

const EjectError = error{
    NoFreeLibrary,
};

// Stuff that needs to happen regardless of if
// we're injecting or ejecting
pub fn init(alloc: std.mem.Allocator, pid: u32) InitError!void {
    state.alloc = alloc;
    state.target_pid = pid;

    const process_access_rights = win32.PROCESS_ACCESS_RIGHTS{
        .CREATE_THREAD = 1,
        .QUERY_INFORMATION = 1,
        .VM_OPERATION = 1,
        .VM_WRITE = 1,
        .VM_READ = 1,
    };

    state.target_handle = win32.OpenProcess(process_access_rights, win32.FALSE, state.target_pid);

    if (state.target_handle == null) {
        return error.FailedOpen;
    }

    errdefer utility.closeHandle(state.target_handle);

    // kernel32.dll is where some functions we need live
    state.kernel32 = win32.GetModuleHandleA("kernel32.dll") orelse return error.NoKernel32;
}

pub inline fn deinit() void {
    utility.closeHandle(state.target_handle);
}

pub fn inject(lib: []const u8, thread_method: ThreadMethod) InjectError!void {
    defer log.info("finished", .{});

    // Get `LoadLibrary` from kernel32.dll
    state.ll_fn = win32.GetProcAddress(state.kernel32, "LoadLibraryA") orelse return error.NoLoadLibrary;

    _ = thread_method;

    const createThreadMethod = win32.CreateRemoteThread;

    // Allocate space for the shared library path in the target process
    const path_alloc = win32.VirtualAllocEx(state.target_handle, null, lib.len, .{ .RESERVE = 1, .COMMIT = 1 }, win32.PAGE_READWRITE);

    if (path_alloc == null) {
        return error.FailedVirtualAlloc;
    }

    defer {
        const free_status = win32.VirtualFreeEx(state.target_handle, path_alloc, 0, win32.MEM_RELEASE);
        if (free_status == 0) {
            utility.logErrWin(state.alloc, "failed to free memory in target for sl path", .{});
        }
    }

    // Write shared library path to target
    if (win32.WriteProcessMemory(state.target_handle, path_alloc, lib.ptr, lib.len, null) == 0) {
        return error.FailedWrite;
    }

    // Create a thread in the target process that calls `LoadLibrary`
    // with the shared library path as the passed argument
    const ll_thread = createThreadMethod(state.target_handle, null, 0, @ptrCast(state.ll_fn), path_alloc, 0, null);

    if (ll_thread == null) {
        return error.FailedCreateThread;
    }

    defer utility.closeHandle(ll_thread);

    const checker_thread = std.Thread.spawn(.{}, checkLlThreadFinished, .{ll_thread.?}) catch {
        return error.FailedCheckerThread;
    };
    checker_thread.detach();

    // Wait up to 15 seconds for the thread to finish
    const wait_status = win32.WaitForSingleObject(ll_thread.?, 15000);

    if (wait_status == 0x00000102) {
        return error.TimedOut;
    }

    if (state.remote_thread_exit_code != 0) {
        log.warn("ll thread exited with code {d}, the injection may have failed", .{state.remote_thread_exit_code});
    }
}

pub fn eject(lib: []const u8, thread_method: ThreadMethod) EjectError!void {
    defer log.info("finished", .{});

    // Get `FreeLibrary` from kernel32.dll
    state.fl_fn = win32.GetProcAddress(state.kernel32, "FreeLibrary") orelse return error.NoFreeLibrary;

    _ = lib;
    _ = thread_method;
}

fn checkLlThreadFinished(handle: win32.HANDLE) void {
    log.info("waiting on remote thread...", .{});
    defer std.debug.print("\n", .{});

    while (true) {
        std.Thread.sleep(100 * std.time.ns_per_ms);
        std.debug.print(".", .{});

        if (win32.GetExitCodeThread(handle, &state.remote_thread_exit_code) == 0) {
            utility.logErrWin(state.alloc, "\nfailed to get exit code of remote thread", .{});
            break;
        }

        if (state.remote_thread_exit_code == win32.STILL_ACTIVE) {
            continue;
        }
    }
}
