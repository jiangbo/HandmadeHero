const std = @import("std");
const win32 = @import("win32");

pub const UNICODE: bool = true;

const WIDTH: i32 = 640;
const HEIGHT: i32 = 480;
var running: bool = true;

pub fn main() !void {
    var class = std.mem.zeroes(win32.ui.windows_and_messaging.WNDCLASSW);
    class.style = .{ .OWNDC = 1, .HREDRAW = 1, .VREDRAW = 1 };
    class.lpfnWndProc = mainWindowCallback;
    class.hInstance = win32.system.library_loader.GetModuleHandle(null);
    class.lpszClassName = win32.zig.L("Handmade Hero");

    if (win32.ui.windows_and_messaging.RegisterClassW(&class) == 0) {
        win32ErrorPanic();
    }

    var style = win32.ui.windows_and_messaging.WS_OVERLAPPEDWINDOW;
    style.VISIBLE = 1;
    const default = win32.ui.windows_and_messaging.CW_USEDEFAULT;
    const window = win32.ui.windows_and_messaging.CreateWindowEx(.{}, //
        class.lpszClassName, win32.zig.L("手工英雄"), //
        style, default, default, WIDTH, HEIGHT, //
        null, null, class.hInstance, null);

    if (window == null) win32ErrorPanic();

    var message = std.mem.zeroes(win32.ui.windows_and_messaging.MSG);
    while (running) {
        if (win32.ui.windows_and_messaging.GetMessage(&message, null, 0, 0) > 0) {
            _ = win32.ui.windows_and_messaging.TranslateMessage(&message);
            _ = win32.ui.windows_and_messaging.DispatchMessage(&message);
        }
    }
}

pub fn mainWindowCallback(
    window: win32.foundation.HWND,
    message: u32,
    wParam: win32.foundation.WPARAM,
    lParam: win32.foundation.LPARAM,
) callconv(std.os.windows.WINAPI) win32.foundation.LRESULT {
    switch (message) {
        win32.ui.windows_and_messaging.WM_CREATE => {
            std.log.info("create", .{});
        },
        win32.ui.windows_and_messaging.WM_SIZE => {
            var rect = std.mem.zeroes(win32.foundation.RECT);
            _ = win32.ui.windows_and_messaging.GetClientRect(window, &rect);
            // { .left = 0, .top = 0, .right = 624, .bottom = 441 }
            //  可以看到真实的客户区大小和定义的不一致，因为有边框这些。
            std.log.debug("rect: {}", .{rect});
        },
        win32.ui.windows_and_messaging.WM_CLOSE => running = false,
        win32.ui.windows_and_messaging.WM_DESTROY => running = false,
        else => return win32.ui.windows_and_messaging.DefWindowProc(window, message, wParam, lParam),
    }
    return 0;
}

fn win32ErrorPanic() noreturn {
    const err = win32.foundation.GetLastError();
    std.log.err("win32 panic code {}", .{@intFromEnum(err)});
    @panic(@tagName(err));
}
