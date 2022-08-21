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
    eof,
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
    eof: void,
};

const LexerError = error{
    MissingDelimiter,
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
    is_initial: bool,

    pub fn init(input: []const u8) !Lexer {
        return if (input.len == 0) error.EmptyInput else Lexer{
            .input = input,
            .index = 0,
            .is_initial = true,
        };
    }

    fn currentChar(self: Lexer) u8 {
        return self.input[self.index];
    }

    fn peek(self: Lexer) ?u8 {
        return if (self.index + 1 >= self.input.len) null else self.input[self.index + 1];
    }

    // TODO(Johannes): add forceAdvance
    fn advance(self: *Lexer) !void {
        if (self.index + 1 >= self.input.len)
            return error.EOF;
        self.index += 1;
    }

    fn readUntil(self: *Lexer, symbol: u8) LexerError![]const u8 {
        // consume leading symbol
        self.advance() catch return error.MissingDelimiter;

        const start_index = self.index;
        while (self.currentChar() != symbol) {
            self.advance() catch return error.MissingDelimiter;
        }

        return self.input[start_index..self.index];
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
        if (self.peek()) |c| {
            if (c == '<') {
                self.advance() catch unreachable;
                if (self.peek()) |d| {
                    if (d == '-') {
                        self.advance() catch unreachable;
                        return .dlessdash;
                    }
                }
                return .dless;
            }
        }
        return .less;
    }

    fn readGreater(self: *Lexer) Token {
        if (self.peek()) |c| {
            if (c == '>') {
                self.advance() catch unreachable;
                return .dgreater;
            }
        }
        return .greater;
    }

    fn readWord(self: *Lexer) Token {
        const start_index = self.index;

        while (true) {
            if (self.peek()) |c| {
                if (isValidWordChar(c)) {
                    self.advance() catch unreachable;
                } else break;
            } else break;
        }

        const content = self.input[start_index .. self.index + 1];
        return if (keywords.get(content)) |v|
            Token{ .keyword = v }
        else
            Token{ .word = content };
    }

    pub fn next(self: *Lexer) LexerError!Token {
        if (self.is_initial) {
            self.is_initial = false;
        } else {
            self.advance() catch return .eof;
        }

        while (self.currentChar() == ' ') {
            self.advance() catch return .eof;
        }

        const c = self.currentChar();
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
            const token = try self.next();
            try tokens.append(token);
            if (token == .eof) break;
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
    var lexer = try Lexer.init("<");
    const token = try lexer.next();
    try expect(token == .less);
}

test "double less" {
    var lexer = try Lexer.init("<<");
    const token = try lexer.next();
    try expect(token == .dless);
}

test "double less dash" {
    var lexer = try Lexer.init("<<-");
    const token = try lexer.next();
    try expect(token == .dlessdash);
}

test "greater" {
    var lexer = try Lexer.init(">");
    const token = try lexer.next();
    try expect(token == .greater);
}

test "left parenthesis" {
    var lexer = try Lexer.init("(");
    const token = try lexer.next();
    try expect(token == .lparen);
}

test "right parenthesis" {
    var lexer = try Lexer.init(")");
    const token = try lexer.next();
    try expect(token == .rparen);
}

test "double greater" {
    var lexer = try Lexer.init(">>");
    const token = try lexer.next();
    try expect(token == .dgreater);
}

test "empty single quotes" {
    var lexer = try Lexer.init("''");
    const token = try lexer.next();
    switch (token) {
        .single_quoted => |str| try expect(std.mem.eql(u8, str, "")),
        else => unreachable,
    }
}

test "single quotes with content" {
    var lexer = try Lexer.init("'foo bar'");
    const token = try lexer.next();
    switch (token) {
        .single_quoted => |str| try expect(std.mem.eql(u8, str, "foo bar")),
        else => unreachable,
    }
}

test "empty double quotes" {
    var lexer = try Lexer.init("\"\"");
    const token = try lexer.next();
    switch (token) {
        .double_quoted => |str| try expect(std.mem.eql(u8, str, "")),
        else => unreachable,
    }
}

test "double quotes with content" {
    var lexer = try Lexer.init("\"foo bar\"");
    const token = try lexer.next();
    switch (token) {
        .double_quoted => |str| try expect(std.mem.eql(u8, str, "foo bar")),
        else => unreachable,
    }
}

test "whitespace before name is ignored" {
    var lexer = try Lexer.init(" a");
    const token = try lexer.next();
    switch (token) {
        .word => |str| try expect(std.mem.eql(u8, str, "a")),
        else => unreachable,
    }
}

test "whitespace after name is ignored" {
    var lexer = try Lexer.init("a ");
    const token = try lexer.next();
    switch (token) {
        .word => |str| try expect(std.mem.eql(u8, str, "a")),
        else => unreachable,
    }
}

test "whitespace is ignored" {
    var lexer = try Lexer.init(">");
    const tokens = try lexer.allTokens(std.testing.allocator);
    defer tokens.deinit();
    const expected = &[_]Token{ .greater, .eof };
    try std.testing.expectEqualSlices(Token, expected, tokens.items);
}

test "reading names that are not keywords" {
    var lexer = try Lexer.init("foo bar");
    const token = try lexer.next();
    switch (token) {
        .word => |str| try expect(std.mem.eql(u8, str, "foo")),
        else => unreachable,
    }
}

test "whitespace-only string returns .eof" {
    var lexer = try Lexer.init("    ");
    const token = try lexer.next();
    try expect(token.eof == {});
}

test "reading keywords" {
    var lexer =
        try Lexer.init("case esac for in do done if then else elif fi until while");
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

test "lexer initialization fails if input is empty" {
    try std.testing.expectError(error.EmptyInput, Lexer.init(""));
}

test "undelimited (empty) string leads to error" {
    var lexer = try Lexer.init("\"");
    try std.testing.expectError(error.MissingDelimiter, lexer.next());
}

test "undelimited non-empty string leads to error" {
    var lexer = try Lexer.init("\"abcpa def");
    try std.testing.expectError(error.MissingDelimiter, lexer.next());
}
