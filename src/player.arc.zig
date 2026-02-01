const std = @import("std");
const Allocator = std.mem.Allocator;

const io = std.Io.Threaded.global_single_threaded.ioBasic();

const Entry = struct {
	name: [:0]const u8,
	size: usize,
};

pub const ArcReader = struct {
	ptr: *anyopaque,
	vtable: *const VTable,
	allocator: Allocator,
	count: usize,
	size: usize,

	const VTable = struct {
		next: *const fn (*anyopaque, []u8) anyerror!?Entry,
		close: *const fn (*anyopaque, Allocator) void,
	};

	pub fn next(self: *ArcReader, buf: []u8) !?Entry {
		return self.vtable.next(self.ptr, buf);
	}

	pub fn close(self: *ArcReader) void {
		self.vtable.close(self.ptr, self.allocator);
	}
};

const RarReader = struct {
	head: rar.Header = .{},
	archive: *rar.Archive,
	buf_ptr: [*]u8 = undefined,
	buf_len: usize = undefined,

	const rar = @import("unrar");
	pub const signature: u32 = @bitCast([4]u8{'R', 'a', 'r', '!'});

	const vtable: ArcReader.VTable = .{
		.next = @ptrCast(&next),
		.close = @ptrCast(&close),
	};

	fn cb(_: rar.CallbackMsg, udata: usize, p1: usize, p2: usize) callconv(.c) c_uint {
		const self: *RarReader = @ptrFromInt(udata);
		if (self.buf_len < p2) {
			return @intFromEnum(rar.ErrorCode.small_buf);
		}

		const addr: [*]u8 = @ptrFromInt(p1);
		@memcpy(self.buf_ptr[0..p2], addr[0..p2]);
		self.buf_ptr += p2;
		self.buf_len -= p2;
		return 0;
	}

	pub fn init(allocator: Allocator, path: [:0]const u8) !ArcReader {
		var size: usize = 0;
		var count: usize = 0;

		const self = try allocator.create(RarReader);
		self.* = .{ .archive = blk: {
			var head: rar.Header = .{};
			var data: rar.OpenData = .{ .arc_name = path.ptr, .open_mode = .list };
			{
				// determine space needed for the unpacked size and file count.
				const archive = try data.open();
				defer archive.close() catch {};
				while (try head.read(archive)) {
					try archive.processFile(.skip, null, null);
					size += head.unp_size;
					count += 1;
				}
			}
			// prepare for extraction
			data.open_mode = .extract;
			const archive = try data.open();
			archive.setCallback(cb, @intFromPtr(self));
			break :blk archive;
		}};
		return .{
			.ptr = self,
			.vtable = &vtable,
			.allocator = allocator,
			.count = count,
			.size = size,
		};
	}

	fn next(self: *RarReader, buf: []u8) !?Entry {
		if (!try self.head.read(self.archive)) {
			return null;
		}
		// if prev entry was not a music emu file, buf_ptr returns to prev position
		self.buf_ptr = buf.ptr;
		self.buf_len = buf.len;
		try self.archive.processFile(.read, null, null);
		return .{
			.name = std.mem.sliceTo(&self.head.file_name, 0),
			.size = self.head.unp_size,
		};
	}

	fn close(self: *RarReader, allocator: Allocator) void {
		self.archive.close() catch {};
		allocator.destroy(self);
	}
};

const ZipReader = struct {
	reader: std.Io.File.Reader,
	iterator: std.zip.Iterator,
	filename: [std.fs.max_path_bytes:0]u8 = undefined,
	allocator: Allocator,

	pub const signature: u32 = @bitCast([4]u8{'P', 'K', 0x3, 0x4});
	const gz_signature: u24 = @bitCast([3]u8{0x1f, 0x8b, 0x08});
	const Decompress = std.compress.flate.Decompress;
	const Header = std.zip.LocalFileHeader;

	var buf_read: [4096]u8 = undefined;
	var buf_flate: [std.compress.flate.max_window_len]u8 = undefined;

	const vtable: ArcReader.VTable = .{
		.next = @ptrCast(&next),
		.close = @ptrCast(&close),
	};

	pub fn init(allocator: Allocator, path: [:0]const u8) !ArcReader {
		const file = try std.Io.Dir.cwd().openFile(io, path, .{ .mode = .read_only });
		errdefer file.close(io);

		const self = try allocator.create(ZipReader);
		errdefer allocator.destroy(self);
		self.* = .{
			.reader = .init(file, io, &buf_read),
			.iterator = try .init(&self.reader),
			.allocator = allocator,
		};
		const r = &self.reader;
		const iterator = &self.iterator;

		// determine space needed for the unpacked size and file count.
		var size: usize = 0;
		var count: usize = 0;
		while (try iterator.next()) |entry| {
			if (entry.uncompressed_size == 0) { // directory, ignore
				continue;
			}
			try r.seekTo(entry.file_offset);
			const start = entry.file_offset + @sizeOf(Header) + entry.filename_len
				+ (try r.interface.takeStruct(Header, .little)).extra_len;
			try r.seekTo(start);

			count += 1;
			size += switch (entry.compression_method) {
				.store => blk: {
					// might be a gzipped file
					const sig: u24 = @bitCast((try r.interface.take(3))[0..3].*);
					if (sig != gz_signature) {
						break :blk entry.compressed_size;
					}
					try r.seekTo(start + entry.compressed_size - 4);
					break :blk try r.interface.takeInt(u32, .little);
				},
				.deflate => blk: {
					var flate: Decompress = .init(&r.interface, .raw, &buf_flate);
					const sig: u24 = @bitCast((try flate.reader.take(3))[0..3].*);
					if (sig != gz_signature) {
						break :blk entry.uncompressed_size;
					}
					// gzip puts uncompressed size in the footer, decompress the whole file
					const buf = try allocator.alloc(u8, entry.uncompressed_size - 3);
					defer allocator.free(buf);
					try flate.reader.readSliceAll(buf);
					break :blk @as(u32, @bitCast(buf[buf.len - 4..][0..4].*));
				},
				_ => return error.UnsupportedCompressionMethod,
			};
		}
		// prepare for extraction
		iterator.cd_record_index = 0;
		iterator.cd_record_offset = 0;

		return .{
			.ptr = self,
			.vtable = &vtable,
			.allocator = allocator,
			.count = count,
			.size = size,
		};
	}

	fn next(self: *ZipReader, buf: []u8) !?Entry {
		const entry = try self.iterator.next() orelse return null;
		if (entry.filename_len > std.fs.max_path_bytes) {
			return error.FilePathTooLong;
		}
		var r = &self.reader;

		// get local file header and file name
		try r.seekTo(entry.file_offset);
		const n = entry.filename_len;
		const start = entry.file_offset + @sizeOf(Header) + n
			+ (try r.interface.takeStruct(Header, .little)).extra_len;
		try r.interface.readSliceAll(self.filename[0..n]);
		self.filename[n] = 0;

		// read data into buffer
		try r.seekTo(start);
		const size = switch (entry.compression_method) {
			.store => blk: {
				// might be a gzipped file
				const sig: u24 = @bitCast((try r.interface.take(3))[0..3].*);
				if (sig != gz_signature) {
					try r.interface.readSliceAll(buf[0..entry.compressed_size]);
					break :blk entry.compressed_size;
				}
				try r.seekTo(start + entry.compressed_size - 4);
				const size = try r.interface.takeInt(u32, .little);

				try r.seekTo(start);
				var gzip: Decompress = .init(&r.interface, .gzip, &buf_flate);
				try gzip.reader.readSliceAll(buf[0..size]);
				break :blk size;
			},
			.deflate => blk: {
				var flate: Decompress = .init(&r.interface, .raw, &buf_flate);
				try flate.reader.readSliceAll(buf[0..entry.uncompressed_size]);
				const sig: u24 = @bitCast(buf[0..3].*);
				if (sig != gz_signature) {
					break :blk entry.uncompressed_size;
				}
				const temp = try self.allocator.alloc(u8, entry.uncompressed_size);
				defer self.allocator.free(temp);
				@memcpy(temp, buf[0..entry.uncompressed_size]);

				var buf_stream: std.Io.Reader = .fixed(temp);
				var gzip: Decompress = .init(&buf_stream, .gzip, &buf_flate);
				const size: u32 = @bitCast(buf[entry.uncompressed_size - 4 ..][0..4].*);
				try gzip.reader.readSliceAll(buf[0..size]);
				break :blk size;
			},
			_ => return error.UnsupportedCompressionMethod,
		};
		return .{
			.name = self.filename[0..n :0],
			.size = size,
		};
	}

	fn close(self: *ZipReader, allocator: Allocator) void {
		self.reader.file.close(io);
		allocator.destroy(self);
	}
};

pub const types = [_]type {
	RarReader,
	ZipReader,
};
