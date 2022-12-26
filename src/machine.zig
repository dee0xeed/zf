
const std = @import("std");
const os = std.os;
const mem = std.mem;
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
    dpos: ?usize = null,  // for variables, location in the data segment
};

pub const Dict = struct {

    const cap: usize = 256;
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
            if (mem.eql(u8, name, self.words[i].name)) {
                if (true == self.words[i].hidd)
                    break;
                return &self.words[i];
            }
        }
        return null;
    }

    pub fn findWordByDpos(self: *Dict, dpos: usize) ?*Word {
        var i: usize = 1;
        while (i <= self.nwords) : (i += 1) {
            if (self.words[i].dpos) |dp| {
                if (dp == dpos)
                    return &self.words[i];
            }
        }
        return null;
    }

    pub fn getWordNumber(self: *Dict, name: []const u8) ?usize {
        var i: usize = self.nwords;
        while (i > 0) : (i -= 1)
            if (mem.eql(u8, name, self.words[i].name))
                return i;
        return null;
    }
};

pub const VirtualStackMachine = struct {

    const CODE_CAP = 2048;
    const DATA_CAP = 2048;

    const Error = error {
        WordNumberOutOfRange,
        CodeSpaceIsFull,
        ColonInsideWordDefinition,
        UndefinedWord,
        WordIsCompileOnly,
        IllegalWordName,
        DataSpaceFull,
    };

    const Mode = enum {
        interpreting,
        compiling,
    };

    const Meta = enum {
        word_number,
        jump_location,
        numb_literal,
    };

    stop: bool = false,
    dict: Dict,
    dstk: Stack,                        // data stack
    rstk: Stack,                        // return stack
    code: [CODE_CAP]usize = undefined,  //
    meta: [CODE_CAP]Meta = undefined,   //
    cptr: usize = 0,                    // "instruction pointer"/"program counter"
    cend: usize = 0,                    // first free code cell
    data: [DATA_CAP]usize = undefined,  //
    dend: usize = 0,                    // first free data cell (`HERE`)
    ibuf: [256]u8 = undefined,          // input buffer
    bcnt: usize = 0,
    need_prompt: bool = true,
    mode: Mode = .interpreting,
    current_word: *Word = undefined,
    fd: i32 = 0,

    fn dotImpl(vm: *VirtualStackMachine) !void {
        const n = try vm.dstk.pop();
        const i = @bitCast(isize, n);
        std.debug.print("{} ", .{i});
    }

    fn crImpl(self: *VirtualStackMachine) !void {
        _ = self;
        _ = try os.write(1, "\n");
    }

    fn promImpl(self: *VirtualStackMachine) !void {
        if (self.need_prompt) {
            if (.compiling == self.mode) {
                _ = try os.write(1, "zf(c)> ");
            } else {
                _ = try os.write(1, "zf> ");
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
            res = try os.read(self.fd, byte[0..]);
            if (0 == res) {
                try self.dstk.push(0);
                return;
            }
        }

        while ('\n' != byte[0]) {
            self.ibuf[cnt] = byte[0];
            cnt += 1;
            res = try os.read(self.fd, byte[0..]);
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

    fn drain(self: *VirtualStackMachine) !void {
        var n: u32 = 0;
        var b: [1]u8 = undefined;
        std.debug.print("discarded input: '", .{});
        while (true) {
            _ = os.linux.ioctl(0, os.linux.T.FIONREAD, @ptrToInt(&n));
            if (0 == n) break;
            _ = try os.read(self.fd, b[0..]);
            _ = try os.write(1, b[0..]);
        }
        std.debug.print("'\n", .{});
    }

    pub fn appendText(self: *VirtualStackMachine, val: usize, meta: Meta) !void {
        if (CODE_CAP == self.cend)
            return Error.CodeSpaceIsFull;
        self.code[self.cend] = val;
        self.meta[self.cend] = meta;
        self.cend += 1;
    }

    fn compile(self: *VirtualStackMachine, name: []const u8) !void {

        // string? TODO...
        // if ('"' == ) {}
        // const name = self.ibuf[0..self.bcnt];
        // std.debug.print("compiling '{s}'\n", .{name});

        if (mem.eql(u8, name, ":")) {
            std.debug.print("'{s}' inside word definition\n", .{name});
            return Error.ColonInsideWordDefinition;
        }

        const wnum = self.dict.getWordNumber(name);
        if (wnum) |wn| {
            const word = &self.dict.words[wn];
            if (true == word.comp) {
                try word.func(self);
            } else {
                try self.appendText(wn, .word_number);
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
        try self.appendText(wn, .word_number);
        try self.appendText(@bitCast(usize, number), .numb_literal);
    }

    fn execute(self: *VirtualStackMachine, name: []const u8) !void {

        // string? TODO...
        //const name = self.ibuf[0..self.bcnt];

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

    fn procWord(self: *VirtualStackMachine) !void {

        if (0 == self.bcnt)
            return;

        const name = self.ibuf[0..self.bcnt];

        if (.compiling == self.mode) {
            try self.compile(name);
        } else {
            try self.execute(name);
        }
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

    fn dumpCode(self: *VirtualStackMachine) !void {
        var k: usize = 0;
        while (k < self.cend) : (k += 1) {
            const code = self.code[k];
            std.debug.print("text[{x:0>4}] = {x:0>16} ", .{k, code});
            switch (self.meta[k]) {
            .word_number => {
                const word = &self.dict.words[code];
                std.debug.print("'{s}'", .{word.name});
            },
            .jump_location => std.debug.print("(-->{x})", .{code}),
            .numb_literal => std.debug.print("({d})", .{code}),
            }
            std.debug.print("\n", .{});
        }
    }

    fn dumpData(self: *VirtualStackMachine) !void {
        var k: usize = 0;
        while (k < self.dend) : (k += 1) {
            var name: []const u8 = "-";
            if (self.dict.findWordByDpos(k)) |w|
                name = w.name;
            std.debug.print("data[{}] = 0x{x:0>16} ('{s}')\n", .{k, self.data[k], name});
        }
    }

    fn enterCompileMode(self: *VirtualStackMachine) !void {
        try self.readWord();
        _ = try self.dstk.pop(); // check for zero
        const name = self.ibuf[0..self.bcnt];

        if (
            mem.eql(u8, name, ";") or
            mem.eql(u8, name, ":") or
            mem.eql(u8, name, "(") or
            mem.eql(u8, name, ")")
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

    fn makeAddrWord(self: *VirtualStackMachine) !void {
        try self.readWord();
        _ = try self.dstk.pop(); // check for zero
        const name = self.ibuf[0..self.bcnt];
        const word = Word {
            .name = name,
            .func = rt.addrImpl,
            .cpos = self.cend,
            .hidd = false,
            .comp = false,
            .dpos = self.dend,
        };
        _ = try self.dict.addWord(word);
    }

    pub fn init() !VirtualStackMachine {

        var vm = VirtualStackMachine {
            .dict = Dict{},
            .dstk = Stack{.name = "dstk"},
            .rstk = Stack{.name = "rstk"},
        };

        const builtins: []const Word = &[_]Word {

            // "instruction set"
            .{.name = "jump",   .func = &rt.jumpImpl, .hidd = true},
            .{.name = "jifz",   .func = &rt.jifzImpl, .hidd = true},
            .{.name = "return", .func = &rt.returnImpl, .hidd = true},
            .{.name = "lit",    .func = &rt.litImpl,  .hidd = true},
            .{.name = "loop-rt", .func = &rt.loopImpl, .hidd = true}, // ...
            .{.name = "dup",   .func = &rt.dupImpl},
            .{.name = "drop",  .func = &rt.dropImpl},
            .{.name = "swap",  .func = &rt.swapImpl},
            .{.name = "rot",   .func = &rt.rotImpl},
            .{.name = ">r",    .func = &rt.pushImpl},
            .{.name = "r>",    .func = &rt.popImpl},
            .{.name = "and",   .func = &rt.andImpl},
            .{.name = "or",    .func = &rt.orImpl},
            .{.name = "xor",   .func = &rt.xorImpl},
            .{.name = "inv",   .func = &rt.invertImpl},
            .{.name = "+",     .func = &rt.addImpl},
            .{.name = "-",     .func = &rt.subImpl},
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
            .{.name = "!",     .func = &rt.storeImpl},
            .{.name = "@",     .func = &rt.loadImpl},

            // shell
            .{.name = "prom",  .func = &promImpl, .hidd = true},
            .{.name = "read",  .func = &readWord, .hidd = true},
            .{.name = "proc",  .func = &procWord, .hidd = true},
            .{.name = "bye",   .func = &sayGoodbye},
            .{.name = ".",     .func = &dotImpl},
            .{.name = "cr",    .func = &crImpl},
            .{.name = ".dict", .func = &dumpDict},
            .{.name = ".dstk", .func = &dumpDataStack},
            .{.name = ".rstk", .func = &dumpReturnStack},
            .{.name = ".text", .func = &dumpCode},
            .{.name = ".data", .func = &dumpData},

            // ???
            .{.name = "allot", .func = &rt.allotImpl},

            // defining words
            .{.name = "create", .func = &makeAddrWord},
            .{.name = ":",     .func = &enterCompileMode},
//            .{.name = "val", .func = &},

            // compiling words
            .{.name = ";",    .func = &ct.leaveCompileMode, .comp = true},
            .{.name = "if",   .func = &ct.compIf, .comp = true},
            .{.name = "else", .func = &ct.compElse, .comp = true},
            .{.name = "then", .func = &ct.compThen, .comp = true},
            .{.name = "do",   .func = &ct.compDo, .comp = true},
            .{.name = "iter",   .func = &ct.compDo, .comp = true},
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

        // construct (i.e. "compile") processing loop by hand
        vm.code[0] = vm.dict.getWordNumber("prom").?;
        vm.code[1] = vm.dict.getWordNumber("read").?;
        vm.code[2] = vm.dict.getWordNumber("jifz").?;
        vm.code[3] = 7;
        vm.code[4] = vm.dict.getWordNumber("proc").?;
        vm.code[5] = vm.dict.getWordNumber("jump").?;
        vm.code[6] = 0;
        vm.code[7] = vm.dict.getWordNumber("bye").?;
        vm.cend = 8;

        vm.meta[0] = .word_number;
        vm.meta[1] = .word_number;
        vm.meta[2] = .word_number;
        vm.meta[3] = .jump_location;
        vm.meta[4] = .word_number;
        vm.meta[5] = .word_number;
        vm.meta[6] = .jump_location;
        vm.meta[7] = .word_number;

        return vm;
    }

    fn reset(self: *VirtualStackMachine) !void {
        try self.drain();
        self.need_prompt = true;
        self.dstk.top = 0;
        self.rstk.top = 0;
        self.cend = 8;
        self.dend = 0;
        self.cptr = 0;
        self.mode = .interpreting;
        std.debug.print("machine reset\n", .{});
    }

    pub fn loadWords(self: *VirtualStackMachine, file: []const u8) !void {
        self.fd = try os.open(file, os.O.RDONLY, 0);
        try self.run();
        os.close(self.fd);
        self.fd = 0;
    }

    pub fn run(self: *VirtualStackMachine) !void {

        self.need_prompt = true;
        self.stop = false;
        self.cptr = 0;
        self.dstk.top = 0;
        self.rstk.top = 0;
        self.mode = .interpreting;

        while (false == self.stop) {

            var wnum = self.code[self.cptr];
            if ((0 == wnum) or (wnum > self.dict.nwords)) {
                std.debug.print("wnum = 0x{x:0>16}\n", .{wnum});
                return Error.WordNumberOutOfRange;
            }

            self.current_word = &self.dict.words[wnum];
            self.cptr += 1;
            self.current_word.func(self) catch |err| {
                //switch (err) {}
                std.debug.print("{}\n", .{err});
                // try self.reset();
            };
        }
    }
};
