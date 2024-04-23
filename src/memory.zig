
const std = @import("std");
const VirtualStackMachine = @import("machine.zig").VirtualStackMachine;

pub fn here(vm: *VirtualStackMachine) !void {
    try vm.dstk.push(vm.dend);
}

pub fn allot(vm: *VirtualStackMachine) !void {
    const d: isize = @bitCast(try vm.dstk.pop());
    const n: isize = @as(isize, @intCast(vm.dend)) + d;
//    if (n > )
    vm.dend = @bitCast(n); // check...
}
