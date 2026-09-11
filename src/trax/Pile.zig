//! A list of strings and floats that stores all values
//! in a single buffer for fast deallocation.
const Pile = @This();

const pd = @import("pd");
const std = @import("std");
const tx = @import("trax.zig");
const wr = @import("../misc/write.zig");

const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;
const Outlet = pd.Outlet;
const Writer = std.Io.Writer;
const Allocator = std.mem.Allocator;

const Oom = Allocator.Error;
const WriteError = Writer.Error;

/// byte array
buf: tx.Buffer = .empty,
/// ending offsets and types of each item
tbl: std.ArrayList(Entry) = .empty,

const Enum = enum(u1) { float, string };
const Entry = packed struct(u32) {
	end: @Int(.unsigned, @bitSizeOf(u32) - @bitSizeOf(Enum)),
	typ: Enum,
};

pub fn deinit(self: *Pile, gpa: Allocator) void {
	self.buf.deinit(gpa);
	self.tbl.deinit(gpa);
}

pub fn erase(self: *Pile) void {
	self.buf.items.len = 0;
	self.tbl.items.len = 0;
}

pub fn append(self: *Pile, gpa: Allocator, str: []const u8) Oom!void {
	if (std.fmt.parseFloat(Float, str)) |f| {
		try self.buf.appendSlice(gpa, std.mem.asBytes(&f));
		try self.tbl.append(gpa, .{ .typ = .float, .end = @truncate(self.buf.items.len) });
	} else |_| {
		_ = try tx.appendSliceZ(&self.buf, gpa, str);
		try self.tbl.append(gpa, .{ .typ = .string, .end = @truncate(self.buf.items.len) });
	}
}

const Union = union(Enum) {
	float: Float,
	string: [:0]const u8,

	pub fn asAtom(self: Union) Atom {
		return switch (self) {
			.float => |f| .float(f),
			.string => |s| .symbol(.gen(s)),
		};
	}

	pub fn print(self: Union) void {
		switch (self) {
			.float => |f| pd.post.start("%g", .{ f }),
			.string => |s| pd.post.start(s, .{}),
		}
	}

	pub fn write(self: Union, w: *Writer) WriteError!void {
		switch (self) {
			.float => |f| try wr.fmtG(w, f),
			.string => |s| try w.writeAll(s),
		}
	}
};

pub fn get(self: *const Pile, index: usize) Union {
	std.debug.assert(index < self.tbl.items.len);
	const start = if (index == 0) 0 else self.tbl.items[index - 1].end;
	return switch (self.tbl.items[index].typ) {
		.float => blk: {
			const bytes = self.buf.items[start..][0..@sizeOf(Float)];
			break :blk .{ .float = std.mem.bytesToValue(Float, bytes) };
		},
		.string => .{
			.string = self.buf.items[start .. self.tbl.items[index].end - 1 :0],
		},
	};
}

fn doSend(self: *const Pile, outlet: *Outlet, key: *Symbol, atoms: []Atom) void {
	for (0..self.tbl.items.len) |i| {
		atoms[i] = self.get(i).asAtom();
	}
	outlet.anything(key, atoms[0..self.tbl.items.len]);
}

pub fn send(
	self: *const Pile,
	gpa: Allocator,
	outlet: *Outlet,
	key: *Symbol,
) Oom!void {
	var arr: [8]Atom = undefined;
	if (self.tbl.items.len > arr.len) {
		const atoms = try gpa.alloc(Atom, self.tbl.items.len);
		defer gpa.free(atoms);
		self.doSend(outlet, key, atoms);
	} else {
		self.doSend(outlet, key, &arr);
	}
}

pub fn print(self: *const Pile, p: *pd.Pd, key: [*:0]const u8) void {
	pd.post.start("%s:", .{ key });
	if (self.tbl.items.len > 1) {
		for (0..self.tbl.items.len) |i| {
			pd.post.start("\n  ", .{});
			self.get(i).print();
		}
	} else if (self.tbl.items.len > 0) {
		pd.post.start(" ", .{});
		self.get(0).print();
	}
	pd.post.log(p, .normal, "", .{});
}

pub fn write(self: *const Pile, w: *Writer) WriteError!void {
	if (self.tbl.items.len <= 0) {
		return;
	}
	try self.get(0).write(w);
	for (1..self.tbl.items.len) |i| {
		try w.writeByte('/');
		try self.get(i).write(w);
	}
}

const one = struct {
	var entry: Entry = .{ .end = 0, .typ = .float };
	var pile: Pile = .{ .tbl = .{ .items = (&entry)[0..1], .capacity = 0 }};
	var float: Float = 0;
};

pub fn float(f: Float) *const Pile {
	one.float = f;
	one.pile.buf.items = @constCast(std.mem.asBytes(&one.float));
	one.entry = .{ .typ = .float, .end = @truncate(one.pile.buf.items.len) };
	return &one.pile;
}

pub fn string(str: [:0]const u8) *const Pile {
	one.pile.buf.items.len = str.len + 1;
	one.pile.buf.items.ptr = @constCast(str.ptr);
	one.entry = .{ .typ = .string, .end = @truncate(one.pile.buf.items.len) };
	return &one.pile;
}

pub fn parse(str: [:0]const u8) *const Pile {
	return if (std.fmt.parseFloat(Float, str)) |f| .float(f) else |_| .string(str);
}
