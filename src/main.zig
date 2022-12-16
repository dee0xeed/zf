
const std = @import("std");
const Machine = @import("machine.zig").VirtualStackMachine;

pub fn main() !void {

    var vm = try Machine.init();
    vm.run() catch |err| {
        std.debug.print("{}\n", .{err});
    };
    std.debug.print("\nBye, see you later!\n", .{});
}
