const std = @import("std");
const pd = @import("pd");
const rt = @import("root");
const tg = @import("toggle.zig");

pub var s_open: *pd.Symbol = undefined;
pub var s_play: *pd.Symbol = undefined;
pub var dict = std.AutoHashMap(*pd.Symbol, *const fn(*rt.Self) pd.Atom).init(pd.mem);
pub const blank = pd.Atom{ .type = .symbol, .w = .{.symbol = pd.s.bang} };

pub fn fmtTime(ms: i64) !pd.Atom {
	var i: usize = 0;
	var buf: [32:0]u8 = undefined;
	const hr = @as(f64, @floatFromInt(ms)) / (60 * 60 * 1000);
	const mn = (hr - @trunc(hr)) * 60;
	const sc = (mn - @trunc(mn)) * 60;
	if (hr >= 1) {
		const res = try std.fmt.bufPrint(&buf, "{}", .{ @as(i32, @intFromFloat(hr)) });
		i = res.len;
	}
	const slice = try std.fmt.bufPrint(buf[i..], "{d:0>2}:{d:0>2}", .{
		@as(u8, @intFromFloat(mn)), @as(u8, @intFromFloat(sc)) });
	buf[slice.len] = '\x00';
	return .{ .type = .symbol, .w = .{ .symbol = pd.symbol(&buf) } };
}

pub const Player = extern struct {
	const Self = @This();

	obj: pd.Object,
	o_meta: *pd.Outlet,
	open: bool,
	play: bool,

	fn err(self: ?*Self, e: anyerror) void {
		pd.post.err(self, "%s", @errorName(e).ptr);
	}

	pub fn print(self: *Self, av: []const pd.Atom) !void {
		var ac = av.len;
		for (av) |*a| {
			ac -= 1;
			if (a.type == .symbol) {
				const n = std.mem.len(a.w.symbol.name);
				var sym = a.w.symbol.name[0..n];
				while (true) {
					var pct = std.mem.indexOf(u8, sym, "%") orelse break;
					const end = (std.mem.indexOf(u8, sym[pct+1..], "%") orelse break)
						+ pct + 1;
					if (pct > 0) { // print what comes before placeholder
						const buf = try pd.mem.allocSentinel(u8, pct, 0);
						defer pd.mem.free(buf);
						@memcpy(buf[0..pct], sym[0..pct]);
						pd.post.start("%s", buf.ptr);
						sym = sym[pct..];
					}
					pct += 1;
					const len = end - pct;
					const buf = try pd.mem.allocSentinel(u8, len, 0);
					defer pd.mem.free(buf);
					@memcpy(buf[0..len], sym[1..1+len]);
					const meta = if (dict.get(pd.symbol(@ptrCast(buf.ptr)))) |func|
						func(@ptrCast(self)) else blank;
					switch (meta.type) {
						.float => pd.post.start("%g", meta.w.float),
						else => {
							const s: *pd.Symbol = meta.w.symbol;
							pd.post.start("%s", if (s == pd.s.bang) "" else s.name);
						},
					}
					sym = sym[len+2..];
				}
				pd.post.start("%s%s", sym.ptr, (if (ac > 0) " " else "").ptr);
			} else if (a.type == .float) {
				pd.post.start("%g%s", a.w.float, (if (ac > 0) " " else "").ptr);
			}
		}
		pd.post.end();
	}

	fn trySend(self: *Self, s: *pd.Symbol) !void {
		if (!self.open) {
			return error.NoFileOpened;
		}
		var meta = [1]pd.Atom{if (dict.get(s)) |func| func(@ptrCast(self)) else blank};
		self.o_meta.anything(s, meta.len, &meta);
	}

	fn send(self: *Self, s: *pd.Symbol) void {
		self.trySend(s) catch |e| self.err(e);
	}

	fn anything(self: *Self, s: *pd.Symbol, _: c_uint, _: [*]const pd.Atom) void {
		self.send(s);
	}

	fn tryPlay(self: *Self, av: []const pd.Atom) !void {
		if (!self.open) {
			return error.NoFileOpened;
		}
		if (tg.toggle(&self.play, av)) {
			var state = [1]pd.Atom{.{ .type = .float,
				.w = .{.float = @floatFromInt(@intFromBool(self.play))} }};
			self.o_meta.anything(s_play, state.len, &state);
		}
	}

	fn setPlay(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		self.tryPlay(av[0..ac]) catch |e| self.err(e);
	}

	fn bang(self: *Self) void {
		self.setPlay(s_play, 0, &[0]pd.Atom{});
	}

	pub fn new(cl: *pd.Class, nch: u8) ?*Self {
		const self: *Self = @ptrCast(cl.new() orelse return null);
		const obj = &self.obj;
		for (0..nch) |_| {
			_ = obj.outlet(pd.s.signal).?;
		}
		self.o_meta = obj.outlet(null).?;
		self.open = false;
		self.play = false;
		return self;
	}

	pub fn class(s: *pd.Symbol, newm: pd.NewMethod, frem: pd.Method, size: usize)
	*pd.Class {
		s_open = pd.symbol("open");
		s_play = pd.symbol("play");

		const cls = pd.class(s, newm, frem, size, .{}, &.{ .gimme }).?;
		cls.addBang(@ptrCast(&bang));
		cls.addAnything(@ptrCast(&anything));
		cls.addMethod(@ptrCast(&send), pd.symbol("send"), &.{ .symbol });
		cls.addMethod(@ptrCast(&setPlay), s_play, &.{ .gimme });
		return cls;
	}
};
