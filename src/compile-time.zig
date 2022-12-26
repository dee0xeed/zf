
const std = @import("std");
const VirtualStackMachine = @import("machine.zig").VirtualStackMachine;
const UNRESOLVED: usize = 0xFFFFFFFFFFFFFFFF;

pub fn compIf(vm: *VirtualStackMachine) !void {
    const wn = vm.dict.getWordNumber("jifz").?;
    try vm.appendText(wn, .word_number);
    try vm.dstk.push(vm.cend);
    try vm.appendText(UNRESOLVED, .jump_location);
}

pub fn compElse(vm: *VirtualStackMachine) !void {
    const orig = try vm.dstk.pop();
    const wn = vm.dict.getWordNumber("jump").?;
    try vm.appendText(wn, .word_number);
    try vm.dstk.push(vm.cend);
    try vm.appendText(UNRESOLVED, .jump_location);
    // resolve `if` forward reference
    vm.code[orig] = vm.cend;
}

pub fn compThen(vm: *VirtualStackMachine) !void {
    // resolve `if`/`else` forward reference
    const orig = try vm.dstk.pop();
    vm.code[orig] = vm.cend;
}

pub fn compDo(vm: *VirtualStackMachine) !void {
    const wn = vm.dict.getWordNumber("do-rt").?;
    try vm.appendText(wn, .word_number);
    try vm.dstk.push(vm.cend);
}

pub fn compIndex(vm: *VirtualStackMachine) !void {
    const wn = vm.dict.getWordNumber("index").?;
    try vm.appendText(wn, .word_number);
}

pub fn compLoop(vm: *VirtualStackMachine) !void {
    const wn = vm.dict.getWordNumber("loop-rt").?;
    try vm.appendText(wn, .word_number);
    const bwref = try vm.dstk.pop();
    try vm.appendText(bwref, .jump_location);
//    vm.code[vm.cend] = bwref;
//    vm.meta[vm.cend] = .jump_location;
//    vm.cend += 1;
}

pub fn compBegin(vm: *VirtualStackMachine) !void {
    try vm.dstk.push(vm.cend);
}

pub fn compAgain(vm: *VirtualStackMachine) !void {
    const wn = vm.dict.getWordNumber("jump").?;
    try vm.appendText(wn, .word_number);
    const bwref = try vm.dstk.pop();
    try vm.appendText(bwref, .jump_location);
//    vm.code[vm.cend] = bwref;
//    vm.meta[vm.cend] = .jump_location;
//    vm.cend += 1;
}

pub fn compUntil(vm: *VirtualStackMachine) !void {
    const wn = vm.dict.getWordNumber("jifz").?;
    try vm.appendText(wn, .word_number);
    const bwref = try vm.dstk.pop();
    try vm.appendText(bwref, .jump_location);
    //vm.code[vm.cend] = bwref;
    //vm.meta[vm.cend] = .jump_location;
    //vm.cend += 1;
}

pub fn leaveCompileMode(vm: *VirtualStackMachine) !void {
    const wn = vm.dict.getWordNumber("return").?;
    try vm.appendText(wn, .word_number);
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
