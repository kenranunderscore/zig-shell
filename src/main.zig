const std = @import("std");

const TokenKind = enum {
    less,
    lessgreat,
    dless,
    dlessdash,
    greater,
    dgreater,
    lparen,
    rparen,
    single_quoted,
};

const Token = union(TokenKind) {
    less: void,
    lessgreat: void,
    dless: void,
    dlessdash: void,
    greater: void,
    dgreater: void,
    lparen: void,
    rparen: void,
    single_quoted: []const u8,
};

const Lexer = struct {
    input: []const u8,
    index: u32,

    pub fn init(input: []const u8) Lexer {
        return Lexer{
            .input = input,
            .index = 0,
        };
    }

    fn current_char(self: Lexer) !u8 {
        if (self.index >= self.input.len)
            return error.EndOfInput;
        return self.input[self.index];
    }

    fn advance(self: *Lexer) void {
        self.index += 1;
    }

    fn read_single_quoted(self: *Lexer) !Token {
        // consume leading '
        self.advance();

        const start_index = self.index;
        while ((try self.current_char()) != '\'') : (self.advance()) {}
        const end_index = self.index;

        // advance once more to consume the closing '
        self.advance();

        return Token{ .single_quoted = self.input[start_index..end_index] };
    }

    fn read_less(self: *Lexer) Token {
        self.advance();

        if (self.index < self.input.len and (self.current_char() catch unreachable) == '<') {
            self.advance();
            return .dless;
        } else {
            return .less;
        }
    }

    pub fn next(self: *Lexer) !?Token {
        const c = self.current_char() catch return null;
        return switch (c) {
            '(' => .lparen,
            ')' => .rparen,
            '<' => self.read_less(),
            '\'' => try self.read_single_quoted(),
            else => unreachable,
        };
    }

    pub fn all_tokens(self: *Lexer, allocator: std.mem.Allocator) !std.ArrayList(Token) {
        var tokens = std.ArrayList(Token).init(allocator);
        while (true) {
            const t = try self.next();
            if (t != null) {
                try tokens.append(t.?);
            } else break;
        }

        return tokens;
    }
};

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var lexer = Lexer.init("'a'<<''");
    var x = lexer.all_tokens(allocator);
    std.log.info("result: {any}", .{x});
}

const expect = std.testing.expect;

test "less" {
    var lexer = Lexer.init("<");
    const token = try lexer.next();
    try expect(token.? == .less);
}

test "empty single quotes" {
    var lexer = Lexer.init("''");
    const token = try lexer.next();
    switch (token.?) {
        .single_quoted => |str| try expect(std.mem.eql(u8, str, "")),
        else => unreachable,
    }
}

test "single quotes with content" {
    var lexer = Lexer.init("'foo bar'");
    const token = try lexer.next();
    switch (token.?) {
        .single_quoted => |str| try expect(std.mem.eql(u8, str, "foo bar")),
        else => unreachable,
    }
}
