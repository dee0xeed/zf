
const std = @import("std");
const VirtualStackMachine = @import("machine.zig").VirtualStackMachine;

pub fn jumpImpl(vm: *VirtualStackMachine) !void {
    vm.cptr = vm.code[vm.cptr];
}

pub fn jifzImpl(vm: *VirtualStackMachine) !void {
    const tods = try vm.dstk.pop();
    if (0 == tods) {
        vm.cptr = vm.code[vm.cptr];
    } else {
        vm.cptr += 1;
    }
}

pub fn callImpl(vm: *VirtualStackMachine) !void {
    try vm.rstk.push(vm.cptr);
    vm.cptr = vm.current_word.cpos.?;
}

pub fn returnImpl(vm: *VirtualStackMachine) !void {
    vm.cptr = try vm.rstk.pop();
}

// DO I LOOP
// https://stackoverflow.com/questions/6949434/how-to-implement-loop-in-a-forth-like-language-interpreter-written-in-c

pub fn doImpl(vm: *VirtualStackMachine) !void {
    const index = try vm.dstk.pop();
    const limit = try vm.dstk.pop();
    try vm.rstk.push(limit);
    try vm.rstk.push(index);
}

pub fn indexImpl(vm: *VirtualStackMachine) !void {
    const index = vm.rstk.mem[vm.rstk.top];
    try vm.dstk.push(index);
}

pub fn loopImpl(vm: *VirtualStackMachine) !void {
    vm.rstk.mem[vm.rstk.top] += 1;
    if (vm.rstk.mem[vm.rstk.top] == vm.rstk.mem[vm.rstk.top - 1]) {
        // end loop
        _ = try vm.rstk.pop();
        _ = try vm.rstk.pop();
        vm.cptr += 1;
    } else {
        // go to the beginning of the loop
        vm.cptr = vm.code[vm.cptr];
    }
}

pub fn litImpl(vm: *VirtualStackMachine) !void {
    const code = vm.code[vm.cptr];
    try vm.dstk.push(code);
    vm.cptr += 1; // step over the literal
}

pub fn dupImpl(vm: *VirtualStackMachine) !void {
    const x = try vm.dstk.pop();
    try vm.dstk.push(x);
    try vm.dstk.push(x);
}

pub fn dropImpl(vm: *VirtualStackMachine) !void {
    _ = try vm.dstk.pop();
}

pub fn swapImpl(vm: *VirtualStackMachine) !void {
    const a = try vm.dstk.pop();
    const b = try vm.dstk.pop();
    try vm.dstk.push(a);
    try vm.dstk.push(b);
}

pub fn addImpl(vm: *VirtualStackMachine) !void {
    const rhs = try vm.dstk.pop();
    const lhs = try vm.dstk.pop();
    const res = @bitCast(isize, lhs) + @bitCast(isize, rhs);
    try vm.dstk.push(@bitCast(usize, res));
}

pub fn incImpl(vm: *VirtualStackMachine) !void {
    const num = @bitCast(isize, try vm.dstk.pop());
    const res = num + @as(isize, 1);
    try vm.dstk.push(@bitCast(usize, res));
}

pub fn subImpl(vm: *VirtualStackMachine) !void {
    const rhs = try vm.dstk.pop();
    const lhs = try vm.dstk.pop();
    const res = @bitCast(isize, lhs) - @bitCast(isize, rhs);
    try vm.dstk.push(@bitCast(usize, res));
}

pub fn decImpl(vm: *VirtualStackMachine) !void {
    const num = @bitCast(isize, try vm.dstk.pop());
    const res = num - @as(isize, 1);
    try vm.dstk.push(@bitCast(usize, res));
}

pub fn mulImpl(vm: *VirtualStackMachine) !void {
    const rhs = try vm.dstk.pop();
    const lhs = try vm.dstk.pop();
    const res = @bitCast(isize, lhs) * @bitCast(isize, rhs);
    try vm.dstk.push(@bitCast(usize, res));
}

pub fn divImpl(vm: *VirtualStackMachine) !void {
    const rhs = try vm.dstk.pop();
    const lhs = try vm.dstk.pop();
    const res = @divTrunc(@bitCast(isize, lhs), @bitCast(isize, rhs));
    try vm.dstk.push(@bitCast(usize, res));
}

pub fn modImpl(vm: *VirtualStackMachine) !void {
    const rhs = try vm.dstk.pop();
    const lhs = try vm.dstk.pop();
    const res = @mod(@bitCast(isize, lhs), @bitCast(isize, rhs));
    try vm.dstk.push(@bitCast(usize, res));
}

pub fn eqlImpl(vm: *VirtualStackMachine) !void {
    const rhs = try vm.dstk.pop();
    const lhs = try vm.dstk.pop();
    const res: bool = (lhs == rhs);
    try vm.dstk.push(@boolToInt(res));
}

pub fn eqzImpl(vm: *VirtualStackMachine) !void {
    const num = try vm.dstk.pop();
    const res: bool = (num == 0);
    try vm.dstk.push(@boolToInt(res));
}

pub fn neqImpl(vm: *VirtualStackMachine) !void {
    const rhs = try vm.dstk.pop();
    const lhs = try vm.dstk.pop();
    const res: bool = (lhs != rhs);
    try vm.dstk.push(@boolToInt(res));
}

pub fn nezImpl(vm: *VirtualStackMachine) !void {
    const num = try vm.dstk.pop();
    const res: bool = (num != 0);
    try vm.dstk.push(@boolToInt(res));
}

pub fn gtImpl(vm: *VirtualStackMachine) !void {
    const rhs = try vm.dstk.pop();
    const lhs = try vm.dstk.pop();
    const res = @bitCast(isize, lhs) > @bitCast(isize, rhs);
    try vm.dstk.push(@boolToInt(res));
}

pub fn gtzImpl(vm: *VirtualStackMachine) !void {
    const num = @bitCast(isize, try vm.dstk.pop());
    const res: bool = (num > 0);
    try vm.dstk.push(@boolToInt(res));
}

pub fn ltImpl(vm: *VirtualStackMachine) !void {
    const rhs = try vm.dstk.pop();
    const lhs = try vm.dstk.pop();
    const res = @bitCast(isize, lhs) < @bitCast(isize, rhs);
    try vm.dstk.push(@boolToInt(res));
}

pub fn ltzImpl(vm: *VirtualStackMachine) !void {
    const num = @bitCast(isize, try vm.dstk.pop());
    const res: bool = (num < 0);
    try vm.dstk.push(@boolToInt(res));
}

pub fn maxImpl(vm: *VirtualStackMachine) !void {
    const rhs = @bitCast(isize, try vm.dstk.pop());
    const lhs = @bitCast(isize, try vm.dstk.pop());
    const res = if (lhs > rhs) lhs else rhs;
    try vm.dstk.push(@bitCast(usize, res));
}

pub fn minImpl(vm: *VirtualStackMachine) !void {
    const rhs = @bitCast(isize, try vm.dstk.pop());
    const lhs = @bitCast(isize, try vm.dstk.pop());
    const res = if (lhs < rhs) lhs else rhs;
    try vm.dstk.push(@bitCast(usize, res));
}

pub fn addrImpl(vm: *VirtualStackMachine) !void {
    const addr = vm.current_word.dpos.?;
    try vm.dstk.push(addr);
}

pub fn loadImpl(vm: *VirtualStackMachine) !void {
    const addr = try vm.dstk.pop();
    const numb = vm.data[addr];
    try vm.dstk.push(numb);
}

pub fn storeImpl(vm: *VirtualStackMachine) !void {
    const addr = try vm.dstk.pop();
    const numb = try vm.dstk.pop();
    vm.data[addr] = numb;
}

pub fn allotImpl(vm: *VirtualStackMachine) !void {
    const d = @bitCast(isize, try vm.dstk.pop());
    const n = @bitCast(isize, vm.dend) + d;
    vm.dend = @bitCast(usize, n); // check...
}
