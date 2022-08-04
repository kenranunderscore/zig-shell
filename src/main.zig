const std = @import("std");

pub fn main() anyerror!void {
    std.log.info("foo", .{});
    try lex("echo");
}

const TokenTag = enum { and_if, word };

const Token = union(TokenTag) {
    and_if: void,
    word: []const u8,
};

fn lex(input: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    std.log.info("{s}", .{input});

    var tokens = std.ArrayList(Token).init(allocator);
    for (input) |_| {
        try tokens.append(Token{ .word = "abc" });
    }

    for (tokens.items) |t| {
        std.log.info("Token: {}", .{t});
    }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
