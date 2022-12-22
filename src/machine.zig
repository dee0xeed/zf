
const std = @import("std");
const Stack = @import("stack.zig").Stack;
const ct = @import("compile-time.zig");
const rt = @import("run-time.zig");
const wordFnPtr = *const fn(*VirtualStackMachine) anyerror!void;

pub const Word = struct {
    const MAX_WORD_LEN = 64;
    buff: [MAX_WORD_LEN]u8 = undefined,
    name: []const u8,
    func: wordFnPtr,
    cpos: ?usize = null,  // location in the code, null for builtins
    hidd: bool = false,   // is hidden (not intended to use directly)
    comp: bool = false,   // compile time only, "compiling word"
};

pub const Dict = struct {

    const cap: usize = 256;
    const mask: usize = ~ (cap - 1);
    const Error = error {
        DictionaryIsFull,
    };

    words: [cap]Word = undefined, // words[0] is reserved / unused
    nwords: usize = 0,

    pub fn addWord(self: *Dict, word: Word) !*Word {
        self.nwords += 1;
        if (self.nwords == cap)
            return Error.DictionaryIsFull;

        self.words[self.nwords] = word;
        for (word.name) |b, k| {
            self.words[self.nwords].buff[k] = b;
        }
        self.words[self.nwords].name = self.words[self.nwords].buff[0..word.name.len];
        return &self.words[self.nwords];
    }

    pub fn findWord(self: *Dict, name: []const u8) ?*Word {
        var i: usize = self.nwords;
        while (i > 0) : (i -= 1) {
            if (std.mem.eql(u8, name, self.words[i].name)) {
                if (true == self.words[i].hidd)
                    break;
                return &self.words[i];
            }
        }
        return null;
    }

    pub fn getWordNumber(self: *Dict, name: []const u8) ?usize {
        var i: usize = self.nwords;
        while (i > 0) : (i -= 1)
            if (std.mem.eql(u8, name, self.words[i].name))
                return i | mask;
        return null;
    }
};

pub const VirtualStackMachine = struct {

    const cap = 2048;

    const Error = error {
        WordNumberOutOfRange,
        CodeSpaceIsFull,
        ColonInsideWordDefinition,
        UndefinedWord,
        WordIsCompileOnly,
        IllegalWordName,
    };

    const Mode = enum {
        interpreting,
        compiling,
    };

    stop: bool = false,
    dict: Dict,
    nwords: usize = 0,
    dstk: Stack,                    // data stack
    rstk: Stack,                    // return stack
    cstk: Stack,                    // control stack
    code: [cap]usize = undefined,
    cptr: usize = 0,                // "instruction pointer"/"program counter"
    cend: usize = 0,                // first free code cell
    ibuf: [256]u8 = undefined,      // input buffer
    bcnt: usize = 0,
    need_prompt: bool = true,
    mode: Mode = .interpreting,
    current_word: *Word = undefined,

    fn dotImpl(vm: *VirtualStackMachine) !void {
        const n = try vm.dstk.pop();
        const i = @bitCast(isize, n);
        std.debug.print("{} ", .{i});
    }

    fn crImpl(self: *VirtualStackMachine) !void {
        _ = self;
        _ = try std.os.write(1, "\n");
    }

    fn promImpl(self: *VirtualStackMachine) !void {
        if (self.need_prompt) {
            if (.compiling == self.mode) {
                _ = try std.os.write(1, "zf(c)> ");
            } else {
                _ = try std.os.write(1, "zf> ");
            }
            self.need_prompt = false;
        }
    }

    fn readWord(self: *VirtualStackMachine) !void {

        var byte: [1]u8 = undefined;
        var cnt: usize = 0;
        var res: usize = 0;

        byte[0] = ' ';
        while (' ' == byte[0]) {
            res = try std.os.read(0, byte[0..]);
            if (0 == res) {
                try self.dstk.push(0);
                return;
            }
        }

        while ('\n' != byte[0]) {
            self.ibuf[cnt] = byte[0];
            cnt += 1;
            res = try std.os.read(0, byte[0..]);
            if (0 == res) {
                try self.dstk.push(0);
                return;
            }
            if (' ' == byte[0]) break;
        }

        if ('\n' == byte[0])
            self.need_prompt = true;

        self.bcnt = cnt;
        // flag for the following 'jifz' instruction
        try self.dstk.push(1);
    }

    fn drain() !void {
        var n: u32 = 0;
        var b: [1]u8 = undefined;
        std.debug.print("discarded input: '", .{});
        while (true) {
            _ = std.os.linux.ioctl(0, std.os.linux.T.FIONREAD, @ptrToInt(&n));
            if (0 == n) break;
            _ = try std.os.read(0, b[0..]);
            _ = try std.os.write(1, b[0..]);
        }
        std.debug.print("'\n", .{});
    }

    // add a word to the code
    pub fn compileWord(self: *VirtualStackMachine, wn: usize) !void {
        if (cap == self.cend)
            return Error.CodeSpaceIsFull;
        self.code[self.cend] = wn;
        self.cend += 1;
    }

    fn compile(self: *VirtualStackMachine) !void {

        // string? TODO...
        // if ('"' == ) {}

        if (0 == self.bcnt)
            return;

        const name = self.ibuf[0..self.bcnt];

        if (std.mem.eql(u8, name, ":")) {
            std.debug.print("'{s}' inside word definition\n", .{name});
            return Error.ColonInsideWordDefinition;
        }

        const wnum = self.dict.getWordNumber(name);
        if (wnum) |wn| {
            const word = &self.dict.words[wn & ~Dict.mask];
            if (true == word.comp) {
                try word.func(self);
            } else {
                try self.compileWord(wn);
            }
            return;
        }

        // may be number?
        const number = std.fmt.parseInt(isize, name, 10) catch {
            std.debug.print("word '{s}' is not defined\n", .{name});
            return Error.UndefinedWord;
        };

        // compile number literal
        const wn = self.dict.getWordNumber("lit").?;
        try self.compileWord(wn);
        try self.compileWord(@bitCast(usize, number));
    }

    fn execWord(self: *VirtualStackMachine) !void {

        if (.compiling == self.mode) {
            //try compile(self);
            try self.compile();
            return;
        }

        // string? TODO...

        if (0 == self.bcnt)
            return;

        const name = self.ibuf[0..self.bcnt];
        var word = self.dict.findWord(name);
        if (word) |w| {
            if (true == w.comp) {
                std.debug.print("word '{s}' is compile-only\n", .{name});
                return Error.WordIsCompileOnly;
            }
            self.current_word = w;
            try w.func(self);
            return;
        }

        // number?
        const number = std.fmt.parseInt(isize, name, 10) catch {
            std.debug.print("word '{s}' is not defined\n", .{name});
            return Error.UndefinedWord;
        };

        try self.dstk.push(@bitCast(usize, number));
    }

    fn sayGoodbye(self: *VirtualStackMachine) !void {
        self.stop = true;
    }

    fn dumpDict(self: *VirtualStackMachine) !void {
        for (self.dict.words) |w, k| {
            if ((false == w.hidd) and (w.name.len > 0))
                std.debug.print("{s} ", .{w.name});
            if (k == self.dict.nwords) break;
        }
        std.debug.print("\n", .{});
    }

    fn dumpDataStack(self: *VirtualStackMachine) !void {
        self.dstk.dump();
    }

    fn dumpReturnStack(self: *VirtualStackMachine) !void {
        self.rstk.dump();
    }

    fn dumpControlStack(self: *VirtualStackMachine) !void {
        self.cstk.dump();
    }

    fn dumpCode(self: *VirtualStackMachine) !void {
        var k: usize = 0;
        while (k < self.cend) : (k += 1)
            std.debug.print("code[{}] = 0x{x:0>16}\n", .{k, self.code[k]});
    }

    fn enterCompileMode(self: *VirtualStackMachine) !void {
        try self.readWord();
        _ = try self.dstk.pop(); // check for zero
        const name = self.ibuf[0..self.bcnt];

        if (
            std.mem.eql(u8, name, ";") or
            std.mem.eql(u8, name, ":") or
            std.mem.eql(u8, name, "(") or
            std.mem.eql(u8, name, ")")
        ) {
            std.debug.print("word can not be named '{s}'\n", .{name});
            return Error.IllegalWordName;
        }
        // check for a number also...

        const word = Word {
            .name = name,
            .func = rt.callImpl,
            .cpos = self.cend,
            .hidd = false,
            .comp = false,
        };
        _ = try self.dict.addWord(word);
        self.mode = .compiling;
    }

    pub fn init() !VirtualStackMachine {

        var vm = VirtualStackMachine {
            .dict = Dict{},
            .dstk = Stack{.name = "dstk"},
            .rstk = Stack{.name = "rstk"},
            .cstk = Stack{.name = "cstk"},
        };

        const builtins: []const Word = &[_]Word {

            // hidden
            .{.name = "prom", .func = &promImpl, .hidd = true},
            .{.name = "read", .func = &readWord, .hidd = true},
            .{.name = "exec", .func = &execWord, .hidd = true},

            .{.name = "jump",   .func = &rt.jumpImpl, .hidd = true},
            .{.name = "jifz",   .func = &rt.jifzImpl, .hidd = true},
            .{.name = "return", .func = &rt.returnImpl, .hidd = true},
            .{.name = "lit",    .func = &rt.litImpl,  .hidd = true},
            .{.name = "doRT",   .func = &rt.doImpl, .hidd = true},
            .{.name = "loopRT", .func = &rt.loopImpl, .hidd = true},
            .{.name = "index",  .func = &rt.indexImpl, .hidd = true},

            // visible (interpretable)
            .{.name = "bye",   .func = &sayGoodbye},
            .{.name = ".",     .func = &dotImpl},
            .{.name = "cr",    .func = &crImpl},
            .{.name = ".dict", .func = &dumpDict},
            .{.name = ".dstk", .func = &dumpDataStack},
            .{.name = ".rstk", .func = &dumpReturnStack},
            .{.name = ".cstk", .func = &dumpControlStack},
            .{.name = ".code", .func = &dumpCode},
            .{.name = "dup",   .func = &rt.dupImpl},
            .{.name = "drop",  .func = &rt.dropImpl},
            .{.name = "+",     .func = &rt.addImpl},
            .{.name = "1+",    .func = &rt.incImpl},
            .{.name = "-",     .func = &rt.subImpl},
            .{.name = "1-",    .func = &rt.decImpl},
            .{.name = "*",     .func = &rt.mulImpl},
            .{.name = "/",     .func = &rt.divImpl},
            .{.name = "mod",   .func = &rt.modImpl},
            .{.name = "=",     .func = &rt.eqlImpl},
            .{.name = "<>",    .func = &rt.neqImpl},
            .{.name = ">",     .func = &rt.gtImpl},
            .{.name = "<",     .func = &rt.ltImpl},
            .{.name = "0=",    .func = &rt.eqzImpl},
            .{.name = "0<>",   .func = &rt.nezImpl},
            .{.name = "0>",    .func = &rt.gtzImpl},
            .{.name = "0<",    .func = &rt.ltzImpl},
            .{.name = "max",   .func = &rt.maxImpl},
            .{.name = "min",   .func = &rt.minImpl},

            // defining words
            .{.name = ":",     .func = &enterCompileMode},
//            .{.name = "var", .func = &},
//            .{.name = "val", .func = &},
//            .{.name = "create", .func = &},

            // compiling words
            .{.name = ";",    .func = &ct.leaveCompileMode, .comp = true},
            .{.name = "if",   .func = &ct.compIf, .comp = true},
            .{.name = "else", .func = &ct.compElse, .comp = true},
            .{.name = "then", .func = &ct.compThen, .comp = true},
            .{.name = "do",   .func = &ct.compDo, .comp = true},
            .{.name = "iter",   .func = &ct.compDo, .comp = true},
            .{.name = "i",    .func = &ct.compIndex, .comp = true},
//            .{.name = "break", .func = &ct.breakImpl, .comp = true},
//            .{.name = "leave", .func = &ct.breakImpl, .comp = true},
            .{.name = "loop", .func = &ct.compLoop, .comp = true},
            .{.name = "next", .func = &ct.compLoop, .comp = true},
            .{.name = "begin", .func = &ct.compBegin, .comp = true},
            .{.name = "again", .func = &ct.compAgain, .comp = true},
            .{.name = "until", .func = &ct.compUntil, .comp = true},
            .{.name = "(",  .func = &ct.commentImpl, .comp = true},
        };

        for (builtins) |w|
            _ = try vm.dict.addWord(w);
        vm.nwords = vm.dict.nwords;

        // construct (i.e. "compile") processing loop by hand
        vm.code[0] = vm.dict.getWordNumber("prom").?;
        vm.code[1] = vm.dict.getWordNumber("read").?;
        vm.code[2] = vm.dict.getWordNumber("jifz").?;
        vm.code[3] = 7;
        vm.code[4] = vm.dict.getWordNumber("exec").?;
        vm.code[5] = vm.dict.getWordNumber("jump").?;
        vm.code[6] = 0;
        vm.code[7] = vm.dict.getWordNumber("bye").?;
        vm.cend = 8;
        return vm;
    }

    fn reset(self: *VirtualStackMachine) !void {
        try drain();
        self.need_prompt = true;
        self.dstk.top = 0;
        self.rstk.top = 0;
        self.cstk.top = 0;
        self.cend = 8;
        self.cptr = 0;
        self.mode = .interpreting;
        self.dict.nwords = self.nwords;
        std.debug.print("machine reset\n", .{});
    }

    pub fn run(self: *VirtualStackMachine) !void {

        while (false == self.stop) {

            var wnum = self.code[self.cptr];
            wnum &= ~Dict.mask;
            if ((0 == wnum) or (wnum > self.dict.nwords)) {
                std.debug.print("wnum = 0x{x:0>16}\n", .{wnum});
                return Error.WordNumberOutOfRange;
            }

            self.current_word = &self.dict.words[wnum];
            self.cptr += 1;
            self.current_word.func(self) catch |err| {
                //switch (err) {}
                std.debug.print("{}\n", .{err});
                //try reset(self);
                try self.reset();
            };
        }
    }
};
