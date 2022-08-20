const std = @import("std");
const l = @import("lexer.zig");
const Lexer = l.Lexer;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var lexer = Lexer.init("  >   abc def  ");
    var x = try lexer.allTokens(allocator);
    l.printTokens(x);
}

test {
    _ = l;
}
