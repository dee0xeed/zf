
const std = @import("std");
const VirtualStackMachine = @import("machine.zig").VirtualStackMachine;

pub fn jumpImpl(self: *VirtualStackMachine) !void {
    self.cptr = self.code[self.cptr];
}

pub fn jifzImpl(self: *VirtualStackMachine) !void {
    const tods = try self.dstk.pop();
    if (0 == tods) {
        self.cptr = self.code[self.cptr];
    } else {
        self.cptr += 1;
    }
}

pub fn callImpl(self: *VirtualStackMachine) !void {
    try self.rstk.push(self.cptr);
    self.cptr = self.current_word.cpos.?;
}

pub fn returnImpl(self: *VirtualStackMachine) !void {
    self.cptr = try self.rstk.pop();
}

// DO I LOOP
// https://stackoverflow.com/questions/6949434/how-to-implement-loop-in-a-forth-like-language-interpreter-written-in-c

pub fn doImpl(self: *VirtualStackMachine) !void {
    const index = try self.dstk.pop();
    const limit = try self.dstk.pop();
    try self.cstk.push(limit);
    try self.cstk.push(index);
}

pub fn indexImpl(self: *VirtualStackMachine) !void {
    const index = self.cstk.mem[self.cstk.top];
    try self.dstk.push(index);
}

pub fn loopImpl(self: *VirtualStackMachine) !void {
    self.cstk.mem[self.cstk.top] += 1;
    if (self.cstk.mem[self.cstk.top] == self.cstk.mem[self.cstk.top - 1]) {
        // end loop
        _ = try self.cstk.pop();
        _ = try self.cstk.pop();
        self.cptr += 1;
    } else {
        // go to the beginning of the loop
        self.cptr = self.code[self.cptr];
    }
}

pub fn litImpl(self: *VirtualStackMachine) !void {
    const code = self.code[self.cptr];
    try self.dstk.push(code);
    self.cptr += 1; // step over the literal
}

pub fn dupImpl(self: *VirtualStackMachine) !void {
    const x = try self.dstk.pop();
    try self.dstk.push(x);
    try self.dstk.push(x);
}

pub fn dropImpl(self: *VirtualStackMachine) !void {
    _ = try self.dstk.pop();
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
