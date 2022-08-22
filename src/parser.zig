const std = @import("std");
const l = @import("lexer.zig");
const Token = l.Token;
const TokenKind = l.TokenKind;
const Lexer = l.Lexer;

const Tree = struct {
    left: ?*Tree,
    right: ?*Tree,
};

pub const Parser = struct {
    lexer: *Lexer,
    lookahead: Token,

    pub fn init(lexer: *Lexer) !Parser {
        return Parser{
            .lexer = lexer,
            .lookahead = try lexer.next(),
        };
    }

    // TODO: not public?
    pub fn match(self: *Parser, token: TokenKind) !void {
        if (self.lookahead != token) {
            return error.TokenMismatch;
        }

        self.lookahead = try self.lexer.next();
    }

    pub fn functionDefinition(self: *Parser) !?*Tree {
        try self.match(.word);
        try self.match(.lparen);
        try self.match(.rparen);
        if (self.lookahead == .word) {
            try self.cmdSuffix();
        }
    }
};

test "FOOBAR" {
    var lexer = try Lexer.init("foo() {}");
    var parser = try Parser.init(&lexer);
    try parser.match(.less);
    try parser.match(.word);
    try parser.match(.eof);
}
