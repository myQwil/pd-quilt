//! Playlist reader.

const pd = @import("pd");
const std = @import("std");
const tx = @import("trax/trax.zig");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Meta = tx.Meta;
const Float = pd.Float;
const Symbol = pd.Symbol;

const gpa = pd.gpa;
const io = std.Io.Threaded.global_single_threaded.io();

out_val: *pd.Outlet,
out_idx: *pd.Outlet,
plist: tx.Playlist = .{},
langs: []*Symbol = &.{},

const name = "plist";
var class: *pd.Class = undefined;
pub const Box = pd.Box(pd.Object, @This());

inline fn err(p: *const Pd, e: anyerror) void {
	pd.post.err(p, name ++ ": %s", .{ @errorName(e).ptr });
}

fn readC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	const self = Box.state(p);
	self.plist.replace(gpa, io, av[0..ac]) catch |e| err(p, e);
}

fn appendC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	const self = Box.state(p);
	self.plist.appendArgs(gpa, io, av[0..ac]) catch |e| err(p, e);
}

fn bangC(p: *Pd) callconv(.c) void {
	const self = Box.state(p);
	for (0..self.plist.tbl.items.len) |i| {
		self.out_idx.float(@floatFromInt(i));
		self.out_val.symbol(.gen(self.plist.get(i)));
	}
}

fn indexFromFloat(f: Float, len: usize) error{IndexOutOfBounds}!u32 {
	const i: i32 = @trunc(f);
	if (i < 0 or len <= i) {
		return error.IndexOutOfBounds;
	}
	return @bitCast(i);
}

fn floatC(p: *Pd, f: Float) callconv(.c) void {
	const self = Box.state(p);
	const i = indexFromFloat(f, self.plist.tbl.items.len) catch return;
	self.out_idx.float(@floatFromInt(i));
	self.out_val.symbol(.gen(self.plist.get(i)));
}

fn getC(p: *Pd, f: Float, s: *Symbol) callconv(.c) void {
	const self = Box.state(p);
	const i = indexFromFloat(f, self.plist.tbl.items.len) catch return;
	var hm = Meta.fromPath(gpa, io, self.plist.get(i)) catch |e| return err(p, e);
	defer hm.deinit(gpa);

	if (hm.get(s, self.langs)) |pile| {
		self.out_idx.float(@floatFromInt(i));
		pile.send(gpa, self.out_val, s) catch |e| err(p, e);
	}
}

fn dumpC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	dump(p, av[0..ac]) catch |e| err(p, e);
}
inline fn dump(p: *Pd, av: []const Atom) !void {
	const self = Box.state(p);
	const f = try pd.floatArg(0, av);
	const i = indexFromFloat(f, self.plist.tbl.items.len) catch return;
	var meta: Meta = if (pd.floatArg(1, av)) |g| blk: {
		var chaps: tx.Chapters = try .fromPath(gpa, io, self.plist.get(i));
		defer chaps.deinit(gpa);
		const j = indexFromFloat(g, chaps.tbl.items.len) catch return;
		pd.post.log(p, .normal, "at %g:", .{ chaps.tbl.items[j].time });
		break :blk try .fromPath(gpa, io, chaps.get(j));
	} else |_| try .fromPath(gpa, io, self.plist.get(i));
	defer meta.deinit(gpa);

	const langs: []const *Symbol = self.langs;
	var iter = meta.data.iterator();
	while (iter.next()) |kv| {
		kv.value_ptr.get(langs).print(p, kv.key_ptr.*.name);
	}
}

fn langsC(p: *Pd, _: *Symbol, ac: c_uint, args: [*]const Atom) callconv(.c) void {
	const self = Box.state(p);
	tx.langReplace(&self.langs, gpa, args[0..ac]) catch |e| err(p, e);
}

fn createC() callconv(.c) ?*Pd {
	return pd.wrap(*Pd, create(), name);
}
inline fn create() pd.Oom!*Pd {
	const obj: *pd.Object = @ptrCast(try class.pd());
	const self = Box.state(&obj.g.pd);
	errdefer obj.g.pd.destroy();

	self.* = .{
		.out_val = try .create(obj, pd.s.symbol()),
		.out_idx = try .create(obj, pd.s.float()),
	};
	return &obj.g.pd;
}

fn destroyC(p: *Pd) callconv(.c) void {
	const self = Box.state(p);
	self.plist.deinit(gpa);
	gpa.free(self.langs);
}

inline fn setup() pd.Class.Error!void {
	class = try .create(name, &.{}, createC, destroyC, @sizeOf(Box), .{});
	class.addBang(bangC);
	class.addFloat(floatC);
	class.addMethod(&.{ .gimme }, dumpC, .gen("dump"));
	class.addMethod(&.{ .gimme }, appendC, .gen("append"));
	class.addMethod(&.{ .gimme }, langsC, .gen("langs"));
	class.addMethod(&.{ .gimme }, readC, .gen("read"));
	class.addMethod(&.{ .float, .symbol }, getC, .gen("get"));
}

export fn plist_setup() void {
	_ = pd.wrap(void, setup(), @src().fn_name);
}
