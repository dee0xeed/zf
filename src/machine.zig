
const std = @import("std");
const os = std.os;
const mem = std.mem;
const Stack = @import("stack.zig").Stack;
const ct = @import("compile-time.zig");
const rt = @import("run-time.zig");
const mm = @import("memory.zig");
const wordFnPtr = *const fn(*VirtualStackMachine) anyerror!void;

pub const Word = struct {
    const MAX_WORD_LEN = 64;
    buff: [MAX_WORD_LEN]u8 = undefined,
    name: []const u8,
    exec: wordFnPtr,        // implementation
    cpos: ?usize = null,    // location in the code segment, null for builtins
    hidd: bool = false,     // is hidden (not intended to be used directly)
    comp: bool = false,     // compile time only, "compiling word"
    dpos: ?usize = null,    // for variables, location in the data segment
};

pub const Dict = struct {

    const cap: usize = 1024;
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

    const CODE_CAP = 32384;
    const DATA_CAP = 32384;

    pub const Error = error {
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
                if (0 == self.fd)
                    _ = try os.write(1, "zf(c)> ");
            } else {
                _ = try os.write(1, "zf> ");
            }
            self.need_prompt = false;
        }
    }

    pub fn readWord(self: *VirtualStackMachine) !void {

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
            if (' ' == byte[0])
                break;
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
            if (0 == n)
                break;
            _ = try os.read(self.fd, b[0..]);
            if (b[0] != '\n')
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
        //std.debug.print("compiling '{s}'\n", .{name});

        if (mem.eql(u8, name, ":")) {
            std.debug.print("'{s}' inside word definition\n", .{name});
            return Error.ColonInsideWordDefinition;
        }

        const wnum = self.dict.getWordNumber(name);
        if (wnum) |wn| {
            const word = &self.dict.words[wn];
            if (true == word.comp) {
                // specific compilation behavior
                try word.exec(self);
            } else {
                // default compilation behavior
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
            try w.exec(self);
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
        // std.debug.print("processing '{s}'\n", .{name});

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
            std.debug.print("a word can not be named '{s}'\n", .{name});
            return Error.IllegalWordName;
        }
        // check for a number also...

        const word = Word {
            .name = name,
            .exec = rt.cmdCall,
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
            .exec = rt.cmdAddr,
            .cpos = self.cend,
            .hidd = false,
            .comp = false,
            .dpos = self.dend,
        };
        _ = try self.dict.addWord(word);
    }

    // "execution token" is just the number of a word
    fn tick(self: *VirtualStackMachine) !void {
        try self.readWord();
        _ = try self.dstk.pop(); // check for zero
        const name = self.ibuf[0..self.bcnt];
        const wn = self.dict.getWordNumber(name)
            orelse return Error.UndefinedWord;
        try self.dstk.push(wn);
    }

    fn exec(self: *VirtualStackMachine) !void {
        const wn = try self.dstk.pop();
        self.current_word = &self.dict.words[wn]; // :(
        try self.dict.words[wn].exec(self);
    }

    fn immediate(self: *VirtualStackMachine) !void {
        var w = &self.dict.words[self.dict.nwords];
        w.comp = true;
    }

    pub fn init() !VirtualStackMachine {

        var vm = VirtualStackMachine {
            .dict = Dict{},
            .dstk = Stack{.name = "dstk"},
            .rstk = Stack{.name = "rstk"},
        };

        const builtins: []const Word = &[_]Word {

            // "instruction set"
            .{.name = "jump", .exec = &rt.cmdJump, .hidd = true},
            .{.name = "jifz", .exec = &rt.cmdJifz, .hidd = true},
            .{.name = "ret",  .exec = &rt.cmdRet,  .hidd = true},
            .{.name = "loop", .exec = &rt.cmdLoop, .hidd = true},
            .{.name = "lit",  .exec = &rt.cmdLit,  .hidd = true},
            .{.name = "dup",  .exec = &rt.cmdDup               },
            .{.name = "drop", .exec = &rt.cmdDrop              },
            .{.name = "swap", .exec = &rt.cmdSwap              },
            .{.name = ">r",   .exec = &rt.cmdPush              },
            .{.name = "r>",   .exec = &rt.cmdPop               },
            .{.name = "and",  .exec = &rt.cmdAnd               },
            .{.name = "or",   .exec = &rt.cmdOr                },
            .{.name = "xor",  .exec = &rt.cmdXor               },
            .{.name = "inv",  .exec = &rt.cmdInv               },
            .{.name = "+",    .exec = &rt.cmdAdd               },
            .{.name = "-",    .exec = &rt.cmdSub               },
            .{.name = "*",    .exec = &rt.cmdMul               },
            .{.name = "/",    .exec = &rt.cmdDiv               },
            .{.name = "mod",  .exec = &rt.cmdMod               },
            .{.name = "=",    .exec = &rt.cmdEql               },
            .{.name = ">",    .exec = &rt.cmdGt                },
            .{.name = "<",    .exec = &rt.cmdLt                },
            .{.name = "!",    .exec = &rt.cmdStore             },
            .{.name = "@",    .exec = &rt.cmdFetch             },
            // NOTE: some "instructions" are not here:
            // cmdCall - word.exec for 'usual' words
            // cmdAddr - word.exec for words-variables
            // cmdAddrCall - word.exec for words-variables with `does>`

            // shell
            .{.name = "prom",  .exec = &promImpl, .hidd = true},
            .{.name = "read",  .exec = &readWord, .hidd = true},
            .{.name = "proc",  .exec = &procWord, .hidd = true},
            .{.name = "bye",   .exec = &sayGoodbye},
            .{.name = ".",     .exec = &dotImpl},
            .{.name = "cr",    .exec = &crImpl},
            .{.name = ".dict", .exec = &dumpDict},
            .{.name = ".dstk", .exec = &dumpDataStack},
            .{.name = ".rstk", .exec = &dumpReturnStack},
            .{.name = ".text", .exec = &dumpCode},
            .{.name = ".data", .exec = &dumpData},

            // memory management (data segment)
            .{.name = "here",  .exec = &mm.here},
            .{.name = "allot", .exec = &mm.allot},

            // defining words (dictionary management)
            .{.name = "create", .exec = &makeAddrWord},
            .{.name = "does>", .exec = &ct.compDoes, .comp = true},
            .{.name = "does", .exec = &ct.execDoes},
            .{.name = "'", .exec = &tick},
            .{.name = "exec", .exec = &exec},
            .{.name = "immediate", .exec = &immediate},
            .{.name = ":",     .exec = &enterCompileMode},
//            .{.name = "val", .exec = &},

            // compiling words
            .{.name = ";",     .exec = &ct.compRet, .comp = true},
            .{.name = "postpone", .exec = &ct.postpone, .comp = true},
            .{.name = "if",    .exec = &ct.compIf, .comp = true},
            .{.name = "else",  .exec = &ct.compElse, .comp = true},
            .{.name = "then",  .exec = &ct.compThen, .comp = true},
            .{.name = "iter",  .exec = &ct.compDo, .comp = true}, // do
//            .{.name = "break", .exec = &ct.breakImpl, .comp = true},
            .{.name = "next",  .exec = &ct.compLoop, .comp = true}, // loop
            .{.name = "begin", .exec = &ct.compBegin, .comp = true},
            .{.name = "again", .exec = &ct.compAgain, .comp = true},
            .{.name = "until", .exec = &ct.compUntil, .comp = true},
            .{.name = "(",  .exec = &ct.compComment, .comp = true},
            .{.name = "\\",  .exec = &ct.compBackSlashComment},
        };

        for (builtins) |w|
            _ = try vm.dict.addWord(w);

        // compile processing loop
        try vm.appendText(vm.dict.getWordNumber("prom").?, .word_number);
        try vm.appendText(vm.dict.getWordNumber("read").?, .word_number);
        try vm.appendText(vm.dict.getWordNumber("jifz").?, .word_number);
        try vm.appendText(7, .jump_location); // --> `bye`
        try vm.appendText(vm.dict.getWordNumber("proc").?, .word_number);
        try vm.appendText(vm.dict.getWordNumber("jump").?, .word_number);
        try vm.appendText(0, .jump_location); // --> `prom`
        try vm.appendText(vm.dict.getWordNumber("bye").?, .word_number);

        return vm;
    }

    fn reset(self: *VirtualStackMachine) void {
        self.need_prompt = true;
        self.dstk.top = 0;
        self.rstk.top = 0;
        self.cptr = 0;
    }

    pub fn loadWords(self: *VirtualStackMachine, file: []const u8) !void {
        std.debug.print("loading words from {s}...\n", .{file});
        self.fd = try os.open(file, os.O.RDONLY, 0);
        try self.run();
        os.close(self.fd);
        self.fd = 0; // switch to stdin
    }

    pub fn run(self: *VirtualStackMachine) !void {

        self.reset();
        self.stop = false;
        self.mode = .interpreting;

        while (false == self.stop) {

            var wnum = self.code[self.cptr];

            if ((0 == wnum) or (wnum > self.dict.nwords)) {
                std.debug.print("wnum = 0x{x:0>16}\n", .{wnum});
                return Error.WordNumberOutOfRange;
            }

            self.current_word = &self.dict.words[wnum];
            self.cptr += 1;
            self.current_word.exec(self) catch |err| {
                try self.drain();
                if (.interpreting == self.mode) {
                    std.debug.print("{}\n", .{err});
                    self.reset();
                } else {
                    return err;
                }
            };
        }
    }
};
