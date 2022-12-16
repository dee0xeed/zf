
const std = @import("std");

pub const Stack = struct {

    const cap = 32;
    const Error = error {
        StackUnderFlow,
        StackOverFlow,
    };

    name: []const u8,
    mem: [cap]usize = undefined,
    top: usize = 0,

    pub fn push(self: *Stack, item: usize) !void {
        if (self.top == cap - 1) {
            std.debug.print("{s} overflow\n", .{self.name});
            return Error.StackOverFlow;
        }
        self.top += 1;
        self.mem[self.top] = item;
    }

    pub fn pop(self: *Stack) !usize {
        if (0 == self.top) {
            std.debug.print("{s} underflow\n", .{self.name});
            return Error.StackUnderFlow;
        }
        const item = self.mem[self.top];
        self.top -= 1;
        return item;
    }

    pub fn dump(self: *Stack) void {
        var k = self.top;
        while (k > 0) : (k -= 1) {
            std.debug.print("{s}[{}] = 0x{x:0>16}", .{self.name, k, self.mem[k]});
            if (k == self.top)
                std.debug.print(" <- top", .{});
            std.debug.print("\n", .{});
        }
    }
};
