
const std = @import("std");
const Machine = @import("machine.zig").VirtualStackMachine;

pub fn main() !void {

    var vm = try Machine.init();
    std.debug.print("{} predefined words\n", .{vm.dict.nwords});
    try vm.loadWords("std.zf");
    std.debug.print("--- type 'bye' to quit (or press ^D)\n", .{});
    std.debug.print("--- type '.dict' to see all words\n", .{});
    vm.run() catch |err| {
        std.debug.print("{}\n", .{err});
    };
    std.debug.print("\nBye, see you later!\n", .{});
}
