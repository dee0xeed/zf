
const std = @import("std");
const VirtualStackMachine = @import("machine.zig").VirtualStackMachine;

pub fn compIf(vm: *VirtualStackMachine) !void {
    const wn = vm.dict.getWordNumber("jifz").?;
    try vm.compileWord(wn);
    try vm.dstk.push(vm.cend);
    vm.cend += 1;
}

pub fn compElse(vm: *VirtualStackMachine) !void {
    const orig = try vm.dstk.pop();
    const wn = vm.dict.getWordNumber("jump").?;
    try vm.compileWord(wn);
    try vm.dstk.push(vm.cend);
    vm.cend += 1;
    vm.code[orig] = vm.cend;
}

pub fn compThen(vm: *VirtualStackMachine) !void {
    // resolve `if`/`else` forward reference
    const orig = try vm.dstk.pop();
    vm.code[orig] = vm.cend;
}

pub fn compDo(vm: *VirtualStackMachine) !void {
    const wn = vm.dict.getWordNumber("doRT").?;
    try vm.compileWord(wn);
    try vm.dstk.push(vm.cend);
}

pub fn compIndex(vm: *VirtualStackMachine) !void {
    const wn = vm.dict.getWordNumber("index").?;
    try vm.compileWord(wn);
}

pub fn compLoop(vm: *VirtualStackMachine) !void {
    const wn = vm.dict.getWordNumber("loopRT").?;
    try vm.compileWord(wn);
    const bwref = try vm.dstk.pop();
    vm.code[vm.cend] = bwref;
    vm.cend += 1;
}

pub fn compBegin(vm: *VirtualStackMachine) !void {
    try vm.dstk.push(vm.cend);
}

pub fn compAgain(vm: *VirtualStackMachine) !void {
    const wn = vm.dict.getWordNumber("jump").?;
    try vm.compileWord(wn);
    const bwref = try vm.dstk.pop();
    vm.code[vm.cend] = bwref;
    vm.cend += 1;
}

pub fn compUntil(vm: *VirtualStackMachine) !void {
    const wn = vm.dict.getWordNumber("jifz").?;
    try vm.compileWord(wn);
    const bwref = try vm.dstk.pop();
    vm.code[vm.cend] = bwref;
    vm.cend += 1;
}

pub fn leaveCompileMode(vm: *VirtualStackMachine) !void {
    const wn = vm.dict.getWordNumber("return").?;
    try vm.compileWord(wn);
    vm.mode = .interpreting;
}

pub fn commentImpl(vm: *VirtualStackMachine) !void {
    _ = vm;
    while (true) {
        var b: [1]u8 = undefined;
        _ = try std.os.read(0, b[0..]);
        if (std.mem.eql(u8, b[0..], ")"))
            break;
    }
}
