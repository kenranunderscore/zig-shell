const std = @import("std");

pub const TokenKind = enum {
    less,
    lessgreat,
    dless,
    dlessdash,
    greater,
    dgreater,
    lparen,
    rparen,
    single_quoted,
    double_quoted,
    word,
    keyword,
};

pub const Keyword = enum {
    case,
    esac,
    @"for",
    in,
    do,
    done,
    @"if",
    @"then",
    @"else",
    @"elif",
    @"fi",
    until,
    @"while",
};

pub const Token = union(TokenKind) {
    less: void,
    lessgreat: void,
    dless: void,
    dlessdash: void,
    greater: void,
    dgreater: void,
    lparen: void,
    rparen: void,
    single_quoted: []const u8,
    double_quoted: []const u8,
    word: []const u8,
    keyword: Keyword,
};

const LexerError = error{
    UnexpectedEndOfInput,
};

fn isValidWordChar(c: u8) bool {
    return switch (c) {
        'a'...'z', 'A'...'Z', '_', '0'...'9' => true,
        else => false,
    };
}

const keywords = std.ComptimeStringMap(Keyword, .{
    .{ "case", .case },
    .{ "esac", .esac },
    .{ "for", .@"for" },
    .{ "in", .in },
    .{ "do", .do },
    .{ "done", .done },
    .{ "if", .@"if" },
    .{ "then", .@"then" },
    .{ "else", .@"else" },
    .{ "elif", .@"elif" },
    .{ "fi", .@"fi" },
    .{ "until", .until },
    .{ "while", .@"while" },
});

pub const Lexer = struct {
    input: []const u8,
    index: u32,

    pub fn init(input: []const u8) Lexer {
        return Lexer{
            .input = input,
            .index = 0,
        };
    }

    fn currentChar(self: Lexer) LexerError!u8 {
        if (self.index >= self.input.len)
            return error.UnexpectedEndOfInput;
        return self.input[self.index];
    }

    fn advance(self: *Lexer) void {
        self.index += 1;
    }

    fn readUntil(self: *Lexer, symbol: u8) LexerError![]const u8 {
        // consume leading symbol
        self.advance();

        const start_index = self.index;
        while ((try self.currentChar()) != symbol) : (self.advance()) {}
        const end_index = self.index;

        // advance once more to consume the closing symbol
        self.advance();

        return self.input[start_index..end_index];
    }

    fn readSingleQuoted(self: *Lexer) LexerError!Token {
        const content = try self.readUntil('\'');
        return Token{ .single_quoted = content };
    }

    fn readDoubleQuoted(self: *Lexer) LexerError!Token {
        const content = try self.readUntil('\"');
        return Token{ .double_quoted = content };
    }

    /// TODO: find common abstraction for read_less and read_greater
    fn readLess(self: *Lexer) Token {
        self.advance();

        if (self.index < self.input.len and (self.currentChar() catch unreachable) == '<') {
            self.advance();

            if (self.index < self.input.len and (self.currentChar() catch unreachable) == '-') {
                return .dlessdash;
            }

            return .dless;
        }

        return .less;
    }

    fn readGreater(self: *Lexer) Token {
        self.advance();

        if (self.index < self.input.len and (self.currentChar() catch unreachable) == '>') {
            self.advance();
            return .dgreater;
        }

        return .greater;
    }

    fn readWord(self: *Lexer) Token {
        const start_index = self.index;
        var c = self.currentChar() catch unreachable;

        while (true) {
            self.advance();
            c = self.currentChar() catch break;
            if (!isValidWordChar(c)) break;
        }

        const content = self.input[start_index..self.index];
        return if (keywords.get(content)) |v|
            Token{ .keyword = v }
        else
            Token{ .word = content };
    }

    pub fn next(self: *Lexer) LexerError!?Token {
        while ((self.currentChar() catch return null) == ' ') : (self.advance()) {}

        const c = self.currentChar() catch return null;
        return switch (c) {
            '(' => .lparen,
            ')' => .rparen,
            '<' => self.readLess(),
            '>' => self.readGreater(),
            '\'' => try self.readSingleQuoted(),
            '\"' => try self.readDoubleQuoted(),
            'a'...'z', 'A'...'Z', '_' => self.readWord(),
            else => unreachable,
        };
    }

    pub fn allTokens(self: *Lexer, allocator: std.mem.Allocator) !std.ArrayList(Token) {
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

pub fn printToken(token: Token) void {
    switch (token) {
        .word => |s| std.log.info("WORD: {s}", .{s}),
        .single_quoted => |s| std.log.info("SQUOTE: {s}", .{s}),
        else => std.log.info("other: {any}", .{token}),
    }
}

pub fn printTokens(tokens: std.ArrayList(Token)) void {
    for (tokens.items) |t| {
        printToken(t);
    }
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

test "empty double quotes" {
    var lexer = Lexer.init("\"\"");
    const token = try lexer.next();
    switch (token.?) {
        .double_quoted => |str| try expect(std.mem.eql(u8, str, "")),
        else => unreachable,
    }
}

test "double quotes with content" {
    var lexer = Lexer.init("\"foo bar\"");
    const token = try lexer.next();
    switch (token.?) {
        .double_quoted => |str| try expect(std.mem.eql(u8, str, "foo bar")),
        else => unreachable,
    }
}

test "whitespace is ignored" {
    var lexer = Lexer.init(" >>  <  ");
    const tokens = try lexer.allTokens(std.testing.allocator);
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
    var lexer =
        Lexer.init("case esac for in do done if then else elif fi until while");
    const tokens = try lexer.allTokens(std.testing.allocator);
    defer tokens.deinit();

    const expected_keywords = &[_]Keyword{
        .case,
        .esac,
        .@"for",
        .in,
        .do,
        .done,
        .@"if",
        .@"then",
        .@"else",
        .@"elif",
        .@"fi",
        .until,
        .@"while",
    };

    var i: usize = 0;
    while (i < expected_keywords.len) : (i += 1) {
        switch (tokens.items[i]) {
            .keyword => |kw| try expect(kw == expected_keywords[i]),
            else => unreachable,
        }
    }
}
