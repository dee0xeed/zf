
const std = @import("std");
const VirtualStackMachine = @import("machine.zig").VirtualStackMachine;

pub fn allotImpl(vm: *VirtualStackMachine) !void {
    const d = @bitCast(isize, try vm.dstk.pop());
    const n = @bitCast(isize, vm.dend) + d;
    vm.dend = @bitCast(usize, n); // check...
}
