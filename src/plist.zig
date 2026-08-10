//! Playlist reader.

const pd = @import("pd");
const tx = @import("trax.zig");
const std = @import("std");

const Pd = pd.Pd;
const Meta = tx.Meta;
const Float = pd.Float;
const Symbol = pd.Symbol;

const gpa = pd.gpa;
const io = std.Io.Threaded.global_single_threaded.io();

const PList = extern struct {
	obj: pd.Object,
	out_val: *pd.Outlet,
	out_idx: *pd.Outlet,
	plist: tx.Playlist = .{},
	langs: tx.LangSet = .{},

	const name = "plist";
	var class: *pd.Class = undefined;
	pub const parentPtr = pd.parentPtr(PList);

	inline fn err(self: *const PList, e: anyerror) void {
		pd.post.err(self, name ++ ": %s", .{ @errorName(e).ptr });
	}

	fn readC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const pd.Atom) callconv(.c) void {
		const self = parentPtr(p);
		self.plist.replaceWith(gpa, io, av[0..ac]) catch |e| self.err(e);
	}

	fn appendC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const pd.Atom) callconv(.c) void {
		const self = parentPtr(p);
		self.plist.append(gpa, io, av[0..ac]) catch |e| self.err(e);
	}

	fn bangC(p: *Pd) callconv(.c) void {
		const self = parentPtr(p);
		for (0..self.plist.len) |i| {
			self.out_idx.float(@floatFromInt(i));
			self.out_val.symbol(self.plist.ptr[i]);
		}
	}

	fn indexFromFloat(f: Float, len: usize) ?u32 {
		const i: i32 = @intFromFloat(f);
		if (i < 0 or len <= i) {
			return null;
		}
		return @bitCast(i);
	}

	fn floatC(p: *Pd, f: Float) callconv(.c) void {
		const self = parentPtr(p);
		const i = indexFromFloat(f, self.plist.len) orelse return;
		self.out_idx.float(@floatFromInt(i));
		self.out_val.symbol(self.plist.ptr[i]);
	}

	fn getC(p: *Pd, f: Float, s: *Symbol) callconv(.c) void {
		const self = parentPtr(p);
		const i = indexFromFloat(f, self.plist.len) orelse return;
		var hm = (Meta.fromPath(gpa, io, self.plist.ptr[i].name)
			catch |e| return self.err(e)) orelse return;
		defer hm.deinit(gpa);

		if (hm.get(s, self.langs.slice())) |arena| {
			self.out_idx.float(@floatFromInt(i));
			arena.send(gpa, self.out_val, s) catch |e| self.err(e);
		}
	}

	fn dumpC(p: *Pd, f: Float) callconv(.c) void {
		const self = parentPtr(p);
		const i = indexFromFloat(f, self.plist.len) orelse return;
		var hm = (Meta.fromPath(gpa, io, self.plist.ptr[i].name)
			catch |e| return self.err(e)) orelse return;
		defer hm.deinit(gpa);

		const langs: []*Symbol = self.langs.slice();
		var iter = hm.map.iterator();
		while (iter.next()) |kv| {
			kv.value_ptr.get(langs).print(&self.obj, kv.key_ptr.*.name);
		}
	}

	fn langsC(p: *Pd, _: *Symbol, ac: c_uint, args: [*]const pd.Atom) callconv(.c) void {
		const self = parentPtr(p);
		self.langs.replaceWith(gpa, args[0..ac]) catch |e| self.err(e);
	}

	fn initC() callconv(.c) ?*Pd {
		return pd.wrap(*Pd, init(), name);
	}
	inline fn init() pd.Oom!*Pd {
		const self: *PList = try pd.gpa.create(PList);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		self.* = .{
			.obj = self.obj,
			.out_val = try .init(obj, pd.s.symbol()),
			.out_idx = try .init(obj, pd.s.float()),
		};
		return &obj.g.pd;
	}

	fn deinitC(p: *Pd) callconv(.c) void {
		const self = parentPtr(p);
		self.plist.deinit(gpa);
		self.langs.deinit(gpa);
	}

	inline fn setup() pd.Class.Error!void {
		class = try .init(PList, name, &.{}, initC, deinitC, .{});
		class.addBang(bangC);
		class.addFloat(floatC);
		class.addMethod(&.{ .float }, dumpC, .gen("dump"));
		class.addMethod(&.{ .gimme }, appendC, .gen("append"));
		class.addMethod(&.{ .gimme }, langsC, .gen("langs"));
		class.addMethod(&.{ .gimme }, readC, .gen("read"));
		class.addMethod(&.{ .float, .symbol }, getC, .gen("get"));
	}
};

export fn plist_setup() void {
	_ = pd.wrap(void, PList.setup(), @src().fn_name);
}
