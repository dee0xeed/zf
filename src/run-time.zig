
const std = @import("std");
const VirtualStackMachine = @import("machine.zig").VirtualStackMachine;

pub fn cmdJump(vm: *VirtualStackMachine) !void {
    vm.cptr = vm.code[vm.cptr];
}

pub fn cmdJifz(vm: *VirtualStackMachine) !void {
    const tods = try vm.dstk.pop();
    if (0 == tods) {
        vm.cptr = vm.code[vm.cptr];
    } else {
        vm.cptr += 1;
    }
}

pub fn cmdCall(vm: *VirtualStackMachine) !void {
    try vm.rstk.push(vm.cptr);
    vm.cptr = vm.current_word.cpos.?;
}

pub fn cmdRet(vm: *VirtualStackMachine) !void {
    vm.cptr = try vm.rstk.pop();
}

pub fn cmdLoop(vm: *VirtualStackMachine) !void {
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

pub fn cmdLit(vm: *VirtualStackMachine) !void {
    const code = vm.code[vm.cptr];
    try vm.dstk.push(code);
    vm.cptr += 1; // step over the literal
}

pub fn cmdDup(vm: *VirtualStackMachine) !void {
    const x = try vm.dstk.pop();
    try vm.dstk.push(x);
    try vm.dstk.push(x);
}

pub fn cmdDrop(vm: *VirtualStackMachine) !void {
    _ = try vm.dstk.pop();
}

pub fn cmdSwap(vm: *VirtualStackMachine) !void {
    const a = try vm.dstk.pop();
    const b = try vm.dstk.pop();
    try vm.dstk.push(a);
    try vm.dstk.push(b);
}

// >R
pub fn cmdPush(vm: *VirtualStackMachine) !void {
    const a = try vm.dstk.pop();
    try vm.rstk.push(a);
}

// R>
pub fn cmdPop(vm: *VirtualStackMachine) !void {
    const a = try vm.rstk.pop();
    try vm.dstk.push(a);
}

pub fn cmdAnd(vm: *VirtualStackMachine) !void {
    const rhs = try vm.dstk.pop();
    const lhs = try vm.dstk.pop();
    const res = lhs & rhs;
    try vm.dstk.push(res);
}

pub fn cmdOr(vm: *VirtualStackMachine) !void {
    const rhs = try vm.dstk.pop();
    const lhs = try vm.dstk.pop();
    const res = lhs | rhs;
    try vm.dstk.push(res);
}

pub fn cmdXor(vm: *VirtualStackMachine) !void {
    const rhs = try vm.dstk.pop();
    const lhs = try vm.dstk.pop();
    const res = lhs ^ rhs;
    try vm.dstk.push(res);
}

pub fn cmdInv(vm: *VirtualStackMachine) !void {
    const n = try vm.dstk.pop();
    try vm.dstk.push(~n);
}

pub fn cmdAdd(vm: *VirtualStackMachine) !void {
    const rhs = try vm.dstk.pop();
    const lhs = try vm.dstk.pop();
    const res = @bitCast(isize, lhs) + @bitCast(isize, rhs);
    try vm.dstk.push(@bitCast(usize, res));
}

pub fn cmdSub(vm: *VirtualStackMachine) !void {
    const rhs = try vm.dstk.pop();
    const lhs = try vm.dstk.pop();
    const res = @bitCast(isize, lhs) - @bitCast(isize, rhs);
    try vm.dstk.push(@bitCast(usize, res));
}

pub fn cmdMul(vm: *VirtualStackMachine) !void {
    const rhs = try vm.dstk.pop();
    const lhs = try vm.dstk.pop();
    const res = @bitCast(isize, lhs) * @bitCast(isize, rhs);
    try vm.dstk.push(@bitCast(usize, res));
}

pub fn cmdDiv(vm: *VirtualStackMachine) !void {
    const rhs = try vm.dstk.pop();
    const lhs = try vm.dstk.pop();
    const res = @divTrunc(@bitCast(isize, lhs), @bitCast(isize, rhs));
    try vm.dstk.push(@bitCast(usize, res));
}

pub fn cmdMod(vm: *VirtualStackMachine) !void {
    const rhs = try vm.dstk.pop();
    const lhs = try vm.dstk.pop();
    const res = @mod(@bitCast(isize, lhs), @bitCast(isize, rhs));
    try vm.dstk.push(@bitCast(usize, res));
}

pub fn cmdEql(vm: *VirtualStackMachine) !void {
    const rhs = try vm.dstk.pop();
    const lhs = try vm.dstk.pop();
    const res: bool = (lhs == rhs);
    try vm.dstk.push(@bitCast(usize, -@intCast(isize, @boolToInt(res))));
}

pub fn cmdGt(vm: *VirtualStackMachine) !void {
    const rhs = try vm.dstk.pop();
    const lhs = try vm.dstk.pop();
    const res = @bitCast(isize, lhs) > @bitCast(isize, rhs);
    try vm.dstk.push(@bitCast(usize, -@intCast(isize, @boolToInt(res))));
}

pub fn cmdLt(vm: *VirtualStackMachine) !void {
    const rhs = try vm.dstk.pop();
    const lhs = try vm.dstk.pop();
    const res = @bitCast(isize, lhs) < @bitCast(isize, rhs);
    try vm.dstk.push(@bitCast(usize, -@intCast(isize, @boolToInt(res))));
}

// word.func for 'simple' vars
pub fn cmdAddr(vm: *VirtualStackMachine) !void {
    const addr = vm.current_word.dpos.?;
    try vm.dstk.push(addr);
}

// word.func for vars with `does>`
pub fn cmdAddrCall(vm: *VirtualStackMachine) !void {
    try cmdAddr(vm);
    try cmdCall(vm);
}

pub fn cmdFetch(vm: *VirtualStackMachine) !void {
    const addr = try vm.dstk.pop();
    const numb = vm.data[addr];
    try vm.dstk.push(numb);
}

pub fn cmdStore(vm: *VirtualStackMachine) !void {
    const addr = try vm.dstk.pop();
    const numb = try vm.dstk.pop();
    vm.data[addr] = numb;
}
