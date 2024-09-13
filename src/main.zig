const std = @import("std");
const win32 = @import("win32");

pub const UNICODE: bool = true;

var allocator: std.mem.Allocator = undefined;
var width: i32 = 640;
var height: i32 = 480;
var running: bool = true;

var bitmapInfo: win32.graphics.gdi.BITMAPINFO = undefined;
var bitmapMemory: ?[]Color = null;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    allocator = gpa.allocator();

    createWindow();
    if (bitmapMemory) |memory| allocator.free(memory);
}

fn createWindow() void {
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
        style, default, default, width, height, //
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

const Color = extern struct { b: u8 = 0, g: u8 = 0, r: u8 = 0, a: u8 = 0 };

fn resizeDIBSection() void {
    if (bitmapMemory) |memory| allocator.free(memory);

    bitmapInfo = std.mem.zeroes(win32.graphics.gdi.BITMAPINFO);
    bitmapInfo.bmiHeader.biSize = @sizeOf(@TypeOf(bitmapInfo.bmiHeader));
    bitmapInfo.bmiHeader.biWidth = width;
    bitmapInfo.bmiHeader.biHeight = -height;
    bitmapInfo.bmiHeader.biPlanes = 1;
    bitmapInfo.bmiHeader.biBitCount = 32;
    bitmapInfo.bmiHeader.biCompression = win32.graphics.gdi.BI_RGB;

    const size: usize = @intCast(width * height * @sizeOf(Color));
    bitmapMemory = allocator.alloc(Color, size) catch unreachable.?;

    const w: usize = @intCast(width);
    for (0..@as(usize, @intCast(height))) |y| {
        for (0..w) |x| {
            bitmapMemory.?[x + y * w] = .{
                .b = @truncate(x),
                .g = @truncate(y),
            };
        }
    }
}

fn win32UpdateWindow(hdc: ?win32.graphics.gdi.HDC) void {
    const header = bitmapInfo.bmiHeader;
    const result = win32.graphics.gdi.StretchDIBits(hdc, //
        0, 0, width, height, // 目标地址
        0, 0, header.biWidth, -header.biHeight, // 源地址
        bitmapMemory.?.ptr, &bitmapInfo, //
        .RGB_COLORS, win32.graphics.gdi.SRCCOPY);
    if (result == 0) win32ErrorPanic();
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
            std.log.info("resize", .{});
            var rect: win32.foundation.RECT = undefined;
            _ = win32.ui.windows_and_messaging.GetClientRect(window, &rect);
            // { .left = 0, .top = 0, .right = 624, .bottom = 441 }
            //  可以看到真实的客户区大小和定义的不一致，因为有边框这些。
            width = rect.right - rect.left;
            height = rect.bottom - rect.top;
            resizeDIBSection();
        },
        win32.ui.windows_and_messaging.WM_PAINT => {
            var paint: win32.graphics.gdi.PAINTSTRUCT = undefined;
            const hdc = win32.graphics.gdi.BeginPaint(window, &paint);
            defer _ = win32.graphics.gdi.EndPaint(window, &paint);

            win32UpdateWindow(hdc);
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
