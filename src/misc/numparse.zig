const std = @import("std");
const Float = @import("pd").Float;

inline fn isDigit(c: u8) bool {
	return '0' <= c and c <= '9';
}

pub fn iParse(buf: []const u8, len: ?*usize) std.fmt.ParseIntError!i32 {
	var s = buf;
	if (s.len > 0 and (s[0] == '-' or s[0] == '+')) {
		s = s[1..];
	}
	while (s.len > 0 and isDigit(s[0])) : (s = s[1..]) {}
	const used = buf.len - s.len;
	if (len) |l| {
		l.* = used;
	}
	return std.fmt.parseInt(i32, buf[0..used], 10);
}

test iParse {
	for ([_]struct{ str: []const u8, num: std.fmt.ParseIntError!i32, len: usize }{
		.{ .str = "123", .num = 123, .len = 3 },
		.{ .str = "-456abc", .num = -456, .len = 4 },
		.{ .str = "-abc", .num = error.InvalidCharacter, .len = 1 },
		.{ .str = "99999999999999999999abc", .num = error.Overflow, .len = 20 },
	}) |case| {
		var len: usize = 0;
		const num = iParse(case.str, &len);
		try std.testing.expectEqual(case.num, num);
		try std.testing.expectEqual(case.len, len);
	}
}

pub fn fParse(buf: []const u8, len: ?*usize) std.fmt.ParseFloatError!Float {
	var s = buf;
	if (s.len > 0 and (s[0] == '-' or s[0] == '+')) {
		s = s[1..];
	}
	while (s.len > 0 and isDigit(s[0])) : (s = s[1..]) {}
	if (s.len > 0 and s[0] == '.') {
		s = s[1..];
		while (s.len > 0 and isDigit(s[0])) : (s = s[1..]) {}
	}
	const used = buf.len - s.len;
		if (len) |l| {
		l.* = used;
	}
	return std.fmt.parseFloat(Float, buf[0..used]);
}

test fParse {
	for ([_]struct{ str: []const u8, num: std.fmt.ParseFloatError!Float, len: usize }{
		.{ .str = "123.456", .num = 123.456, .len = 7 },
		.{ .str = "-654.321", .num = -654.321, .len = 8 },
		.{ .str = "-.123", .num = -0.123, .len = 5 },
		.{ .str = "456.abc", .num = 456, .len = 4 },
		.{ .str = "-.abc", .num = error.InvalidCharacter, .len = 2 },
	}) |case| {
		var len: usize = 0;
		const num = fParse(case.str, &len);
		try std.testing.expectEqual(case.num, num);
		try std.testing.expectEqual(case.len, len);
	}
}
