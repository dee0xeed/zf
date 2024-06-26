
const std = @import("std");
const rt = @import("run-time.zig");
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
    // resolve `jifz` forward reference
    vm.code[orig] = vm.cend;
}

pub fn compThen(vm: *VirtualStackMachine) !void {
    const orig = try vm.dstk.pop();
    // resolve `jifz` (in if) or `jump` (in else) forward reference
    vm.code[orig] = vm.cend;
}

pub fn compDo(vm: *VirtualStackMachine) !void {
    //const wn = vm.dict.getWordNumber("do-rt").?; // "native"
    const wn = vm.dict.getWordNumber("iter-impl").?; // "forth"
    try vm.appendText(wn, .word_number);
    // 
    try vm.dstk.push(vm.cend);
}

pub fn compLoop(vm: *VirtualStackMachine) !void {
    const wn = vm.dict.getWordNumber("loop").?;
    try vm.appendText(wn, .word_number);
    const bwref = try vm.dstk.pop();
    // backward reference to begin
    try vm.appendText(bwref, .jump_location);
}

pub fn compBegin(vm: *VirtualStackMachine) !void {
    try vm.dstk.push(vm.cend);
}

pub fn compAgain(vm: *VirtualStackMachine) !void {
    const wn = vm.dict.getWordNumber("jump").?;
    try vm.appendText(wn, .word_number);
    const bwref = try vm.dstk.pop();
    // backward reference to the beginning 
    try vm.appendText(bwref, .jump_location);
}

pub fn compUntil(vm: *VirtualStackMachine) !void {
    const wn = vm.dict.getWordNumber("jifz").?;
    try vm.appendText(wn, .word_number);
    const bwref = try vm.dstk.pop();
    // backward reference to the beginning
    try vm.appendText(bwref, .jump_location);
}

// adding new defining word
pub fn compDoes(self: *VirtualStackMachine) !void {
    var wn = self.dict.getWordNumber("does").?;
    try self.appendText(wn, .word_number);
    wn = self.dict.getWordNumber("ret").?;
    try self.appendText(wn, .word_number);
}

// adding a word (variable) with that new defining word
pub fn execDoes(self: *VirtualStackMachine) !void {
    // last word (i.e. the one being added now)
    var w = &self.dict.words[self.dict.nwords];
    w.exec = rt.cmdAddrCall; // :)
    // right after the 'does, ret' compiled by compDoes()
    w.cpos = self.cptr + 1;
}

pub fn compRet(vm: *VirtualStackMachine) !void {
    const wn = vm.dict.getWordNumber("ret").?;
    try vm.appendText(wn, .word_number);
    vm.mode = .interpreting;
    const w = &vm.dict.words[vm.dict.nwords];
    std.debug.print("word {s: ^11} compiled @ 0x{x:0>4}\n", .{w.name, w.cpos.?});
}

pub fn compComment(vm: *VirtualStackMachine) !void {
    while (true) {
        var b: [1]u8 = undefined;
        _ = try std.posix.read(vm.fd, b[0..]);
        if (std.mem.eql(u8, b[0..], ")"))
            break;
    }
}

pub fn compBackSlashComment(vm: *VirtualStackMachine) !void {
    while (true) {
        var b: [1]u8 = undefined;
        _ = try std.posix.read(vm.fd, b[0..]);
        if (0x0A == b[0])
            break;
    }
}

pub fn postpone(vm: *VirtualStackMachine) !void {
    try vm.readWord();
    _ = try vm.dstk.pop(); // check for zero
    const name = vm.ibuf[0..vm.bcnt];
//    std.debug.print("(postpone) w = '{s}'\n", .{name});
    const wn = vm.dict.getWordNumber(name) orelse
        return VirtualStackMachine.Error.UndefinedWord;
    const w = &vm.dict.words[wn];
    const this = &vm.dict.words[vm.dict.nwords];
    if (true == w.comp) {
        // this.comp = true; 
        this.exec = w.exec;
    } else {
//        ??? what?..
    }
}
