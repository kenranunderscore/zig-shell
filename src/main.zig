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
    word,
    keyword,
};

const Keyword = enum {
    case,
    esac,
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
    word: []const u8,
    keyword: Keyword,
};

const LexerError = error{
    UnexpectedEndOfInput,
};

fn is_valid_word_char(c: u8) bool {
    return switch (c) {
        'a'...'z', 'A'...'Z', '_', '0'...'9' => true,
        else => false,
    };
}

const keywords = std.ComptimeStringMap(Keyword, .{
    .{ "case", .case },
    .{ "esac", .esac },
});

const Lexer = struct {
    input: []const u8,
    index: u32,

    pub fn init(input: []const u8) Lexer {
        return Lexer{
            .input = input,
            .index = 0,
        };
    }

    fn current_char(self: Lexer) LexerError!u8 {
        if (self.index >= self.input.len)
            return error.UnexpectedEndOfInput;
        return self.input[self.index];
    }

    fn advance(self: *Lexer) void {
        self.index += 1;
    }

    fn read_single_quoted(self: *Lexer) LexerError!Token {
        // consume leading '
        self.advance();

        const start_index = self.index;
        while ((try self.current_char()) != '\'') : (self.advance()) {}
        const end_index = self.index;

        // advance once more to consume the closing '
        self.advance();

        return Token{ .single_quoted = self.input[start_index..end_index] };
    }

    /// TODO: find common abstraction for read_less and read_greater
    fn read_less(self: *Lexer) Token {
        self.advance();

        if (self.index < self.input.len and (self.current_char() catch unreachable) == '<') {
            self.advance();

            if (self.index < self.input.len and (self.current_char() catch unreachable) == '-') {
                return .dlessdash;
            }

            return .dless;
        }

        return .less;
    }

    fn read_greater(self: *Lexer) Token {
        self.advance();

        if (self.index < self.input.len and (self.current_char() catch unreachable) == '>') {
            self.advance();
            return .dgreater;
        }

        return .greater;
    }

    fn read_word(self: *Lexer) Token {
        const start_index = self.index;
        var c = self.current_char() catch unreachable;

        while (true) {
            self.advance();
            c = self.current_char() catch break;
            if (!is_valid_word_char(c)) break;
        }

        const content = self.input[start_index..self.index];
        return if (keywords.get(content)) |v|
            Token{ .keyword = v }
        else
            Token{ .word = content };
    }

    pub fn next(self: *Lexer) LexerError!?Token {
        while ((self.current_char() catch return null) == ' ') : (self.advance()) {}

        const c = self.current_char() catch return null;
        return switch (c) {
            '(' => .lparen,
            ')' => .rparen,
            '<' => self.read_less(),
            '>' => self.read_greater(),
            '\'' => try self.read_single_quoted(),
            ' ' => try self.next(),
            'a'...'z', 'A'...'Z', '_' => self.read_word(),
            else => unreachable,
        };
    }

    pub fn all_tokens(self: *Lexer, allocator: std.mem.Allocator) !std.ArrayList(Token) {
        var tokens = std.ArrayList(Token).init(allocator);
        while (true) {
            const maybe_token = try self.next();
            if (maybe_token) |token| {
                try tokens.append(token);
            } else break;
        }

        return tokens;
    }
};

fn print_token(token: Token) void {
    switch (token) {
        .word => |s| std.log.info("WORD: {s}", .{s}),
        .single_quoted => |s| std.log.info("SQUOTE: {s}", .{s}),
        else => std.log.info("other: {any}", .{token}),
    }
}

fn print_tokens(tokens: std.ArrayList(Token)) void {
    for (tokens.items) |t| {
        print_token(t);
    }
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var lexer = Lexer.init("  >   abc def  ");
    var x = try lexer.all_tokens(allocator);
    print_tokens(x);
}

const expect = std.testing.expect;

test "less" {
    var lexer = Lexer.init("<");
    const token = try lexer.next();
    try expect(token.? == .less);
}

test "double less" {
    var lexer = Lexer.init("<<");
    const token = try lexer.next();
    try expect(token.? == .dless);
}

test "double less dash" {
    var lexer = Lexer.init("<<-");
    const token = try lexer.next();
    try expect(token.? == .dlessdash);
}

test "greater" {
    var lexer = Lexer.init(">");
    const token = try lexer.next();
    try expect(token.? == .greater);
}

test "left parenthesis" {
    var lexer = Lexer.init("(");
    const token = try lexer.next();
    try expect(token.? == .lparen);
}

test "right parenthesis" {
    var lexer = Lexer.init(")");
    const token = try lexer.next();
    try expect(token.? == .rparen);
}

test "double greater" {
    var lexer = Lexer.init(">>");
    const token = try lexer.next();
    try expect(token.? == .dgreater);
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

test "whitespace is ignored" {
    var lexer = Lexer.init(" >>  <  ");
    const tokens = try lexer.all_tokens(std.testing.allocator);
    defer tokens.deinit();
    const expected = &[_]Token{ .dgreater, .less };
    try std.testing.expectEqualSlices(Token, expected, tokens.items);
}

test "reading names that are not keywords" {
    var lexer = Lexer.init("foo bar");
    const token = try lexer.next();
    switch (token.?) {
        .word => |str| try expect(std.mem.eql(u8, str, "foo")),
        else => unreachable,
    }
}

test "reading keywords" {
    var lexer = Lexer.init("case");
    const token = try lexer.next();
    switch (token.?) {
        // NOTE: expecting a different value here leads to the
        // expectEqualSlices above leaking some unexpectedeof error
        // here???
        .keyword => |kw| try expect(kw == .case),
        else => unreachable,
    }
}
