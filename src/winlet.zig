const pd = @import("pd");
const std = @import("std");
const Inlet = @import("inlet.zig").Inlet;
const Word = pd.Word;

/// Returns a capacity larger than minimum that grows super-linearly.
fn growCapacity(current: usize, minimum: usize) usize {
	var new = current;
	while (true) {
		new +|= new / 2 + 8;
		if (new >= minimum) {
			return new;
		}
	}
}

pub const WordInlets = extern struct {
	owner: *pd.Object,
	ptr: [*]Word,
	cap: usize,
	len: usize,

	pub fn init(owner: *pd.Object, av: []const pd.Atom) !WordInlets {
		const vec = try pd.mem.alloc(Word, av.len);
		for (vec, av) |*w, *a| {
			w.float = a.getFloat() orelse 0;
			_ = try owner.inletFloat(&w.float);
		}
		return .{
			.owner = owner,
			.ptr = vec.ptr,
			.cap = vec.len,
			.len = vec.len,
		};
	}

	pub fn deinit(self: *WordInlets) void {
		pd.mem.free(self.ptr[0..self.cap]);
	}

	pub fn items(self: *const WordInlets) []Word {
		return self.ptr[0..self.len];
	}

	pub fn print(self: *const WordInlets, writer: *std.Io.Writer) !void {
		try writer.print("(len={}/{}) ", .{ self.len, self.cap });
	}

	pub fn resize(self: *WordInlets, size: usize) !void {
		if (self.cap < size) {
			const n = growCapacity(self.cap, size);
			const vec = try pd.mem.realloc(self.ptr[0..self.cap], n);
			@memset(vec[self.cap..vec.len], .{ .float = 0 });
			self.ptr = vec.ptr;
			self.cap = vec.len;

			// re-associate inlets with float slots
			var i: u32 = 0;
			var inlet: ?*Inlet = @ptrCast(@alignCast(self.owner.inlets));
			while (inlet) |in| : ({ inlet = in.next; i += 1; }) {
				in.un.floatslot = &self.ptr[i].float;
			}
		}
		self.len = size;
	}
};
