const WordInlets = @This();

const pd = @import("pd");
const std = @import("std");
const Inlet = @import("inlet.zig").Inlet;

const Word = pd.Word;
const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;

owner: *pd.Object,
vec: []Word,
cap: usize,

pub fn init(gpa: Allocator, owner: *pd.Object, av: []const pd.Atom) pd.Oom!WordInlets {
	const vec = try gpa.alloc(Word, av.len);
	for (vec, av) |*w, *a| {
		w.float = a.getFloat() orelse 0;
		_ = try owner.inletFloat(&w.float);
	}
	return .{
		.owner = owner,
		.cap = vec.len,
		.vec = vec,
	};
}

pub fn deinit(self: *WordInlets, gpa: Allocator) void {
	gpa.free(self.vec.ptr[0..self.cap]);
}

pub fn print(self: *const WordInlets, writer: *Writer) Writer.Error!void {
	try writer.print("(len={}/{}) ", .{ self.vec.len, self.cap });
}

fn growCapacity(current: usize, minimum: usize) usize {
	var new = current;
	while (true) {
		new +|= new / 2 + 8;
		if (new >= minimum) {
			return new;
		}
	}
}

pub fn resize(self: *WordInlets, gpa: Allocator, size: usize) pd.Oom!void {
	if (self.cap < size) {
		const n = growCapacity(self.cap, size);
		const vec = try gpa.realloc(self.vec.ptr[0..self.cap], n);
		@memset(vec[self.cap..vec.len], .{ .float = 0 });
		self.vec.ptr = vec.ptr;
		self.cap = vec.len;

		// re-associate inlets with float slots
		var i: u32 = 0;
		var inlet: ?*Inlet = @ptrCast(@alignCast(self.owner.inlets));
		while (inlet) |in| : ({ inlet = in.next; i += 1; }) {
			in.un.floatslot = &self.vec.ptr[i].float;
		}
	}
	self.vec.len = size;
}
