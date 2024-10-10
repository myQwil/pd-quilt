/// Archive reader interface.
pub const Reader = struct {
	const Self = @This();

	ptr: *anyopaque,
	vtable: *const VTable,

	pub const VTable = struct {
		count: *const fn (ctx: *anyopaque) usize,
		size: *const fn (ctx: *anyopaque) usize,
		open: *const fn (ctx: *anyopaque, path: [*:0]const u8, skip: bool) anyerror!void,
		read: *const fn (ctx: *anyopaque, p: *anyopaque) anyerror!void,
		next: *const fn (ctx: *anyopaque) anyerror!bool,
		close: *const fn (ctx: *anyopaque) void,
		entryName: *const fn (ctx: *anyopaque) [*:0]const u8,
		entrySize: *const fn (ctx: *anyopaque) usize,
	};

	pub fn count(self: Self) usize { return self.vtable.count(self.ptr); }
	pub fn size(self: Self) usize { return self.vtable.size(self.ptr); }
	pub fn open(self: Self, path: [*:0]const u8, skip: bool) !void
	{ try self.vtable.open(self.ptr, path, skip); }
	pub fn read(self: Self, p: *anyopaque) !void
	{ try self.vtable.read(self.ptr, p); }
	pub fn next(self: Self) !bool { return self.vtable.next(self.ptr); }
	pub fn close(self: Self) void { self.vtable.close(self.ptr); }
	pub fn entryName(self: Self) [*:0]const u8 { return self.vtable.entryName(self.ptr); }
	pub fn entrySize(self: Self) usize { return self.vtable.entrySize(self.ptr); }
};

const RarReader = struct {
	const rar = @import("unrar");
	const Self = @This();

	head: rar.Header,
	archive: ?*rar.Archive,
	bptr: *anyopaque,
	count: usize, // number of items in archive
	size: usize, // total size in bytes

	fn cb(_: rar.CallbackMsg, udata: usize, p1: usize, p2: usize) callconv(.C) c_int {
		const bptr: *[*]u8 = @ptrFromInt(udata);
		const addr: [*]u8 = @ptrFromInt(p1);
		@memcpy(bptr.*[0..p2], addr[0..p2]);
		bptr.* += p2;
		return 0;
	}

	fn getCount(ctx: *anyopaque) usize {
		const self: *Self = @ptrCast(@alignCast(ctx));
		return self.count;
	}

	fn getSize(ctx: *anyopaque) usize {
		const self: *Self = @ptrCast(@alignCast(ctx));
		return self.size;
	}

	fn next(ctx: *anyopaque) rar.Error!bool {
		const self: *Self = @ptrCast(@alignCast(ctx));
		return if (self.archive) |a| try self.head.read(a) else false;
	}

	fn close(ctx: *anyopaque) void {
		const self: *Self = @ptrCast(@alignCast(ctx));
		if (self.archive) |a| {
			a.close() catch {};
			self.archive = null;
			self.count = 0;
			self.size = 0;
		}
	}

	fn entryName(ctx: *anyopaque) [*:0]const u8 {
		const self: *Self = @ptrCast(@alignCast(ctx));
		return &self.head.file_name;
	}

	fn entrySize(ctx: *anyopaque) usize {
		const self: *Self = @ptrCast(@alignCast(ctx));
		return self.head.unp_size;
	}

	fn restart(self: *Self, data: *rar.OpenData) rar.Error!void {
		if (self.archive) |a|
			try a.close();
		const a = try data.open();
		a.setCallback(cb, @intFromPtr(&self.bptr));
		self.archive = a;
	}

	fn open(ctx: *anyopaque, path: [*:0]const u8, skip: bool) rar.Error!void {
		const self: *Self = @ptrCast(@alignCast(ctx));
		var data = rar.OpenData{ .arc_name = path, .open_mode = .list };

		// determine space needed for the unpacked size and file count.
		try self.restart(&data);
		const a = self.archive.?;
		while (try self.head.read(a)) {
			try a.process(.skip, null, null);
			self.count += 1;
			self.size += self.head.unp_size;
		}

		// prepare for extraction
		data.open_mode = if (skip) .list else .extract;
		try self.restart(&data);
	}

	fn read(ctx: *anyopaque, p: *anyopaque) rar.Error!void {
		const self: *Self = @ptrCast(@alignCast(ctx));
		self.bptr = p;
		if (self.archive) |a| {
			try a.process(.read, null, null);
		}
	}

	const table = Reader.VTable{
		.count = getCount,
		.size = getSize,
		.open = open,
		.read = read,
		.next = next,
		.close = close,
		.entryName = entryName,
		.entrySize = entrySize,
	};

	var inst = Self{
		.head = .{}, .archive = null, .bptr = undefined, .count = 0, .size = 0 };
	const reader = Reader{
		.ptr = &inst,
		.vtable = &table,
	};
};

pub fn fourChar(h: [4]u8) u32 {
	return @as(*const u32, @ptrCast(@alignCast(&h))).*;
}

const Type = struct {
	head: u32,
	reader: *const Reader,
};

pub const types = [_]Type {
	.{ .head = fourChar(.{'R', 'a', 'r', '!'}), .reader = &RarReader.reader },
};
