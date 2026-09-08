const powi = @import("std").math.powi;
const Float = @import("pd").Float;

inline fn getDigit(c: u8) ?u8 {
	return if ('0' <= c and c <= '9') c - '0' else null;
}

/// Simple string-to-float converter
pub fn fParse(str: [*:0]const u8, end_index: ?*usize) ?Float {
	var s = str;
	var no_digits: bool = true;
	if (s[0] == '-' or s[0] == '+') {
		s += 1;
	}

	// integer digits
	var acc: u64 = 0;
	while (getDigit(s[0])) |d| : (s += 1) {
		acc = acc *| 10 +| d;
		no_digits = false;
	}

	// fractional digits
	const exp_offset: usize = if (s[0] == '.') blk: {
		s += 1;
		const start = s;
		while (getDigit(s[0])) |d| : (s += 1) {
			acc = acc *| 10 +| d;
			no_digits = false;
		}
		break :blk s - start;
	} else 0;

	if (no_digits) {
		return null;
	}

	const f: f64 = blk: {
		const a: f64 = @floatFromInt(acc);
		const scale: f64 = @floatFromInt(powi(usize, 10, exp_offset) catch return null);
		break :blk a / scale;
	};
	if (end_index) |end| {
		end.* = s - str;
	}
	return @floatCast(if (str[0] == '-') -f else f);
}

/// Simple string-to-int converter
pub fn iParse(str: [*:0]const u8, end_index: ?*usize) ?i32 {
	var s = str;
	var no_digits: bool = true;
	if (s[0] == '-' or s[0] == '+') {
		s += 1;
	}

	var num: i32 = 0;
	while (getDigit(s[0])) |d| : (s += 1) {
		num = num *| 10 +| d;
		no_digits = false;
	}

	if (no_digits) {
		return null;
	}
	if (end_index) |end| {
		end.* = s - str;
	}
	return if (str[0] == '-') -num else num;
}
