const std = @import("std");
const pd = @import("pd");
const bf = @import("bitfloat.zig");

const UnFloat = bf.UnFloat;
const Float = pd.Float;
const FBig = f128;
const UInt = u32;

const lead = 2;
const int_bits = @bitSizeOf(UInt);
const mant_digits = std.math.floatMantissaBits(Float) + 1;
const ldbl_mant_dig = std.math.floatMantissaBits(FBig) + 1;
const ldbl_max_exp = std.math.floatExponentMax(FBig) + 1;
const inf_exp = (1 << std.math.floatExponentBits(Float)) - 1;

const dgt = struct {
	/// Character for exponent notation.
	const exp: u8 = '@';

	/// index-to-character table
	const char = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz?!";

	/// character-to-index table
	const idx = blk: {
		const largest = 'z';
		var arr = [_]?u6{null} ** (largest + 1);
		for (0..char.len) |i| {
			arr[char[i]] = i;
		}
		break :blk arr;
	};

	const default_prec: [char.len + 1]u16 = if (@bitSizeOf(Float) == 32) .{
		0, 0, 24, 11, 12, 8, 9, 7, 8, 6, 6, 6, 6, 6, 6, 5, 6,
		5, 5, 5, 5, 5, 5, 5, 5, 4, 5, 4, 4, 4, 4, 4, 5,
		4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 3, 4, 3, 4, 4, 4,
		4, 4, 4, 4, 4, 4, 3, 3, 3, 4, 3, 3, 3, 3, 3, 4,
	// I haven't yet worked out what the 64-bit defaults should be
	} else [_]u16{0} ** (char.len + 1);
};

pub fn getBase(s: []const u8) u16 {
	const b = std.fmt.parseInt(u32, s, 10) catch 10;
	return @min(@max(2, b), dgt.char.len);
}

/// Simple string-to-number converter
pub fn parseFloat(s: [*:0]const u8, base: u16) !Float {
	var i: usize = 0;
	var no_digits: bool = true;
	if (s[0] == '-' or s[0] == '+') {
		i += 1;
	}

	// integer digits
	var acc: u64 = 0;
	while (dgt.idx[s[i]]) |d| : (i += 1) {
		acc = acc *| base +| d;
		no_digits = false;
	}

	// fractional digits
	const exp_offset: usize = if (s[i] == '.') blk: {
		i += 1;
		const start: usize = i;
		while (dgt.idx[s[i]]) |d| : (i += 1) {
			acc = acc *| base +| d;
			no_digits = false;
		}
		break :blk i - start;
	} else 0;

	if (no_digits) {
		return error.NoDigitsParsed;
	}

	const f: f64 = blk: {
		const a: f64 = @floatFromInt(acc);
		const scale: f64 = @floatFromInt(try std.math.powi(usize, base, exp_offset));
		break :blk a / scale;
	};
	return @floatCast(if (s[0] == '-') -f else f);
}

test parseFloat {
	const eps = std.math.floatEps(Float);
	try std.testing.expect(@abs(try parseFloat("B.", 12) - 11) < eps);
	try std.testing.expect(@abs(try parseFloat(".4", 12) - 1.0 / 3.0) < eps);
	try std.testing.expect(@abs(try parseFloat("B.4", 12) - 34.0 / 3.0) < eps);
	try std.testing.expect(@abs(try parseFloat("!!.!", 64) - 0x3ffffp0 / 64.0) < eps);
	try std.testing.expect(@abs(try parseFloat("1.0101", 2) - 1.3125) < eps);
	try std.testing.expect(@abs(try parseFloat("+123.456", 10) - 123.456) < eps);
	try std.testing.expect(@abs(try parseFloat("-123.456", 10) + 123.456) < eps);
}

const big_len = blk: {
	const rad: Rad = .init(dgt.char.len, 0);
	const dps = rad.dps;
	const bps = rad.bps;
	const sd = dps - 1;
	const sb = bps - 1;
	break :blk
		// mantissa expansion
		@divTrunc(ldbl_mant_dig + sb, bps) + 1 +
		// exponent expansion
		@divTrunc(ldbl_max_exp + ldbl_mant_dig + @as(u32, sb + sd), dps);
};

fn precision(request: u16, base: u16) u16 {
	const log2_base: f64 = @log2(@as(f64, @floatFromInt(base)));
	const max: u16 = @intFromFloat(@ceil(mant_digits / log2_base));
	const req = if (request == 0) dgt.default_prec[base] else request;
	return if (req == 0) max else @min(req, max);
}

test precision {
	try std.testing.expectEqual(precision(32, 2), 24);
	try std.testing.expectEqual(precision(5, 2), 5);
	try std.testing.expectEqual(precision(0, 10), 6);
	try std.testing.expectEqual(precision(0, 32), 5);
}

/// Returns the difference between two values.
inline fn diff(lhs: anytype, rhs: anytype) isize {
	comptime if (@TypeOf(lhs) != @TypeOf(rhs)) {
		@compileError("types do not match");
	};
	const swap: bool = switch (@typeInfo(@TypeOf(lhs))) {
		.pointer => @intFromPtr(lhs) < @intFromPtr(rhs),
		else => lhs < rhs,
	};
	return if (swap)
		-@as(isize, @intCast(rhs - lhs))
	else @as(isize, @intCast(lhs - rhs));
}

test diff {
	const lhs: [*]u8 = @ptrFromInt(1 << (@bitSizeOf(usize) - 1));
	const rhs = lhs - 1;
	try std.testing.expectEqual(diff(lhs, rhs), 1);
	try std.testing.expectEqual(diff(rhs, lhs), -1);
}

/// Returns an offset from `base` by `n` elements.
inline fn offset(base: anytype, n: isize) @TypeOf(base) {
	// we can't add a negative to unsigned, but we can subtract a positive.
	return if (n < 0)
		base - @as(usize, @intCast(-n))
	else base + @as(usize, @intCast(n));
}

test offset {
	const ptr: [*]u8 = @ptrFromInt(1 << (@bitSizeOf(usize) - 1));
	try std.testing.expectEqual(offset(ptr, 1), ptr + 1);
	try std.testing.expectEqual(offset(ptr, -1), ptr - 1);
}

pub const Rad = extern struct {
	/// current value
	value: Float = 0,
	/// largest base power inside of int bits
	pwr: UInt,
	/// digits per slot
	dps: u16,
	/// bits per slot
	bps: u16,
	/// current radix
	base: u16,
	/// precision
	prec: u16,
	/// character limit. zero means auto.
	width: u16 = 0,
	/// base-2: sign(1) + mantissa(24) + decimal-point(1)
	/// + e-notation(1) + e-sign(1) + exponent(7)
	buf: [@bitSizeOf(Float) + 3 :0]u8 = blk: {
		var tmp: [@bitSizeOf(Float) + 3 :0]u8 = undefined;
		@memcpy(tmp[0..2], "0\x00");
		break :blk tmp;
	},
	/// the amount of buffered bytes
	end: u16 = 1,
	resize: bool = false,

	pub fn init(base: u16, prec: u16) Rad {
		const b: u16 = @min(@max(2, base), dgt.char.len);
		const log2_base: f64 = @log2(@as(f64, @floatFromInt(b)));

		const fdps: f64 = blk: {
			const d = int_bits / log2_base;
			const fd = @floor(d);
			break :blk if (d == fd) fd - 1 else fd;
		};
		const udps: u16 = @intFromFloat(fdps);

		return .{
			.base = b,
			.dps = udps,
			.bps = @intFromFloat(fdps * log2_base),
			.pwr = std.math.powi(UInt, b, udps) catch unreachable,
			.prec = precision(prec, b),
		};
	}

	pub fn reset(self: *Rad) void {
		const rad: Rad = .init(self.base, self.prec);
		self.base = rad.base;
		self.prec = rad.prec;
		self.dps = rad.dps;
		self.bps = rad.bps;
		self.pwr = rad.pwr;
	}

	pub fn setPrecision(self: *Rad, f: Float) void {
		self.prec = precision(@intFromFloat(@max(0, f)), self.base);
	}

	fn fmtU(u: usize, s: [*]u8, base: u16) [*]u8 {
		var v = u;
		var str = s;
		while (v != 0) : (v /= base) {
			str -= 1;
			str[0] = dgt.char[v % base];
		}
		return str;
	}

	/// based on musl-libc: `src/stdio/vfprintf.c`
	pub fn write(self: *Rad) !void {
		var w: std.Io.Writer = .fixed(&self.buf);
		const uf: UnFloat = .{ .f = self.value };
		if (uf.b.exponent == inf_exp) {
			try w.print("{s}{s}", .{
				if (uf.b.sign != 0) "-" else "",
				if (uf.b.mantissa != 0) "nan" else "inf",
			});
			self.buf[w.end] = 0;
			self.resize = if (self.end == w.end) false else blk: {
				self.end = @intCast(w.end);
				break :blk true;
			};
			return;
		}

		const base = self.base;
		const pwr = self.pwr;
		const dps = self.dps;
		const bps = self.bps;
		const sd = dps - 1;
		const sb = bps - 1;

		var big: [big_len]u32 = undefined;
		var buf: [31 + ldbl_mant_dig / 4]u8 = undefined;
		var ebuf0: [3 * @sizeOf(UInt)]u8 = undefined;

		const neg: bool = (uf.b.sign != 0);
		var y: FBig = if (neg) -self.value else self.value;
		var p: i32 = if (self.width != 0 and self.prec >= self.width)
			self.width - uf.b.sign
		else self.prec;

		var e2: i32 = blk: {
			const frexp = std.math.frexp(y);
			y = frexp.significand * 2;
			break :blk frexp.exponent;
		};
		if (y != 0) {
			y *= @floatFromInt(@as(usize, 1) << @as(u6, @intCast(sb)));
			e2 -= bps;
		}

		var d: [*]u32 = undefined;
		var a: [*]u32 = &big;
		a += if (e2 < 0) 0 else big.len - ldbl_mant_dig - 1;
		const r: [*]u32 = a;
		var z: [*]u32 = a;

		var size: usize =
			// mantissa expansion
			@divTrunc(ldbl_mant_dig + sb, bps) + 1 +
			// exponent expansion
			@divTrunc(ldbl_max_exp + ldbl_mant_dig + @as(u32, sb + sd), dps);

		while (true) {
			z[0] = @intFromFloat(y);
			y = @as(FBig, @floatFromInt(pwr)) * (y - @as(FBig, @floatFromInt(z[0])));
			z += 1;
			size -= 1;
			if (y == 0 or size == 0) {
				break;
			}
		}

		while (e2 > 0) {
			var carry: u32 = 0;
			const sh = @min(bps, e2);
			const sh6: u6 = @intCast(sh);
			d = z - 1;
			while (@intFromPtr(d) >= @intFromPtr(a)) : (d -= 1) {
				const u: u64 = (@as(u64, d[0]) << sh6) + carry;
				carry = @intCast(u / pwr);
				d[0] = @intCast(u % pwr);
			}
			if (carry != 0) {
				a -= 1;
				a[0] = carry;
			}
			while (@intFromPtr(z) > @intFromPtr(a) and (z - 1)[0] == 0) : (z -= 1) {}
			e2 -= sh;
		}

		while (e2 < 0) {
			var carry: u32 = 0;
			const sh = @min(dps, -e2);
			const sh5: u5 = @intCast(sh);
			const need: i32 = 1 + @divTrunc(p + ldbl_mant_dig / 3 + sd, dps);
			d = a;
			while (@intFromPtr(d) < @intFromPtr(z)) : (d += 1) {
				const rm: u32 = d[0] & ((@as(u32, 1) << sh5) - 1);
				d[0] = (d[0] >> sh5) + carry;
				carry = (pwr >> sh5) * rm;
			}
			if (a[0] == 0) {
				a += 1;
			}
			if (carry != 0) {
				z[0] = carry;
				z += 1;
			}
			// Avoid (slow!) computation past requested precision
			if (diff(z, a) > need) {
				z = offset(a, need);
			}
			e2 += sh;
		}

		var i: u64 = undefined;
		var j: i32 = undefined;
		var e: i32 = undefined;

		if (@intFromPtr(a) < @intFromPtr(z)) {
			i = base;
			e = @intCast(dps * diff(r, a));
			while (a[0] >= @as(u32, @truncate(i))) : ({ i *= base; e += 1; }) {}
		} else {
			e = 0;
		}

		// Perform rounding: j is precision after the radix (possibly neg)
		j = p - e - 1;
		if (j < dps * diff(z, r + 1)) {
			const di: i32 = dps;
			d = offset(r, 1 + @divTrunc(j + di * ldbl_max_exp, di) - ldbl_max_exp);
			j = @mod(j + di * ldbl_max_exp, di) + 1;
			i = base;
			while (j < dps) : ({ i *= base; j += 1; }) {}
			const u: u32 = d[0] % @as(u32, @intCast(i));
			// Are there any significant digits past j?
			if (u != 0 or d + 1 != z) {
				var round: FBig = 2 / std.math.floatEps(FBig);
				if (
					(d[0] / i & 1 != 0) or
					(i == pwr and @intFromPtr(d) > @intFromPtr(a) and ((d - 1)[0] & 1 != 0))
				) {
					round += 2;
				}
				var small: FBig = if (u < i / 2)
					0x0.8p0
				else if (u == i / 2 and d + 1 == z)
					0x1.0p0
				else
					0x1.8p0;
				if (neg) {
					round = -round;
					small = -small;
				}
				d[0] -= u;
				// Decide whether to round by probing round+small
				if (round + small != round) {
					d[0] += @as(u32, @intCast(i));
					while (d[0] > pwr - 1) {
						d[0] = 0;
						d -= 1;
						if (@intFromPtr(d) < @intFromPtr(a)) {
							a -= 1;
							a[0] = 0;
						}
						d[0] += 1;
					}
					i = base;
					e = @intCast(dps * diff(r, a));
					while (a[0] >= i) : ({ i *= base; e += 1; }) {}
				}
			}
			if (@intFromPtr(z) > @intFromPtr(d) + 1) {
				z = d + 1;
			}
		}

		while (@intFromPtr(z) > @intFromPtr(a) and (z - 1)[0] == 0) : (z -= 1) {}

		var t: u8 = 'g';
		if (p == 0) {
			p += 1;
		}
		if (p > e and e >= -4) {
			t -= 1;
			p -= e + 1;
		} else {
			t -= 2;
			p -= 1;
		}

		// Count trailing zeros in last place
		if (@intFromPtr(z) > @intFromPtr(a) and (z - 1)[0] != 0) {
			i = base;
			j = 0;
			while ((z - 1)[0] % i == 0) : ({ i *= base; j += 1; }) {}
		} else {
			j = dps;
		}

		if (neg) {
			try w.writeByte('-');
		}

		var odec: ?[*]u8 = null;
		var onxt: ?[*]u8 = null;
		const b: [*]u8 = &buf;
		var ebuf: [*]u8 = &ebuf0;

		if ((t | 32) == 'f') {
			p = @min(@max(0, dps * diff(z, r + 1) - j), p);
			if (@intFromPtr(a) > @intFromPtr(r)) {
				a = r;
			}
			d = a;
			while (@intFromPtr(d) <= @intFromPtr(r)) : (d += 1) {
				var s = fmtU(d[0], b + dps, base);
				if (d != a) {
					while (@intFromPtr(s) > @intFromPtr(b)) {
						s -= 1;
						s[0] = '0';
					}
				} else if (s == b + dps) {
					s -= 1;
					s[0] = '0';
				}
				_ = try w.write(s[0 .. b + dps - s]);
			}
			if (p != 0) {
				odec = w.buffer.ptr + w.end;
				try w.writeByte('.');
			}
			while (@intFromPtr(d) < @intFromPtr(z) and p > 0) : ({ d += 1; p -= dps; }) {
				var s = fmtU(d[0], b + dps, base);
				while (@intFromPtr(s) > @intFromPtr(b)) : ({ s -= 1; s[0] = '0'; }) {}
				const len = @min(dps, p);
				_ = try w.write(s[0..@intCast(len)]);
			}
		} else {
			p = @min(@max(0, dps * diff(z, r + 1) + e - j), p);
			const erad = base;
			var estr = fmtU(@intCast(if (e < 0) -e else e), ebuf, erad);
			while (diff(ebuf, estr) < lead) : ({ estr -= 1; estr[0] = '0'; }) {}
			estr -= 1;
			estr[0] = if (e < 0) '-' else '+';
			estr -= 1;
			estr[0] = dgt.exp;

			if (@intFromPtr(z) <= @intFromPtr(a)) {
				z = a + 1;
			}
			d = a;
			while (@intFromPtr(d) < @intFromPtr(z) and p >= 0) : (d += 1) {
				var s = fmtU(d[0], b + dps, base);
				if (s == b + dps) {
					s -= 1;
					s[0] = '0';
				}
				if (d != a) {
					while (@intFromPtr(s) > @intFromPtr(b)) : ({ s -= 1; s[0] = '0'; }) {}
				} else {
					try w.writeByte(s[0]);
					s += 1;
					if (p > 0) {
						odec = w.buffer.ptr + w.end;
						try w.writeByte('.');
					}
				}
				const l = b + dps - s;
				_ = try w.write(s[0..@min(l, @as(usize, @intCast(p)))]);
				p -= @intCast(l);
			}
			onxt = w.buffer.ptr + w.end;
			_ = try w.write(estr[0 .. ebuf - estr]);
		}
		self.buf[w.end] = 0;

		// reduce if too big for number box width
		if (self.width > 0 and w.end > self.width) {
			const dec = odec orelse w.buffer.ptr + w.end;
			var nxt = onxt orelse w.buffer.ptr + w.end;
			const reduce: isize = diff(@as(u16, @intCast(w.end)), self.width);
			if (diff(nxt, dec) >= reduce) {
				var s1: [*]u8 = nxt - @as(usize, @intCast(reduce));
				ebuf = w.buffer.ptr + w.end;
				while (@intFromPtr(nxt) < @intFromPtr(ebuf)) : ({ s1 += 1; nxt += 1; }) {
					s1[0] = nxt[0];
				}
				s1[0] = 0;
				w.end = s1 - &self.buf;
			} else {
				@memcpy(self.buf[self.width - 1 .. self.width + 1], ">\x00");
			}
		}
		if (w.end < 3) {
			w.end = 3;
		}
		self.resize = if (self.end == w.end) false else blk: {
			self.end = @intCast(w.end);
			break :blk true;
		};
	}
};
