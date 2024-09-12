const std = @import("std");
const win32 = @import("win32");

pub const UNICODE: bool = true;

pub fn main() !void {
    const name = win32.zig.L("手工英雄");
    const style = win32.ui.windows_and_messaging.MB_ICONINFORMATION;
    _ = win32.everything.MessageBoxW(null, name, name, style);
}
