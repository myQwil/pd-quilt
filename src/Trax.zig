const Trax = @This();
const std = @import("std");
const pd = @import("pd");

/// list of entries/traxs
list: std.ArrayListUnmanaged(Union) = .{},
/// global metadata
meta: MetaHashMap = .{},

const Symbol = pd.Symbol;
pub const StringHashMap = std.StringHashMapUnmanaged(void);
pub const MetaHashMap = std.AutoArrayHashMapUnmanaged(*Symbol, *Symbol);

const Union = union(enum) {
	media: Media,
	trax: Trax,
};

const Media = struct {
	/// path to the file
	file: *Symbol,
	/// file metadata
	meta: MetaHashMap = .{},
};

const gpa = pd.gpa;
const io = std.Io.Threaded.global_single_threaded.ioBasic();

pub inline fn isTrax(filename: []const u8) bool {
	return std.mem.endsWith(u8, filename, ".trax");
}

/// Print message and skip, do not fail completely by returning error.
inline fn err(len: usize, e: anyerror, s: [*]const u8) void {
	pd.post.err(null, "%u:%s: \"%s\"", .{ len, @errorName(e).ptr, s });
}

pub fn trimRange(
	s: []const u8,
	exclude_begin: []const u8,
	exclude_end: []const u8,
) struct { usize, usize } {
	var a: usize = 0;
	var z: usize = s.len;
	while (a < z and std.mem.findScalar(u8, exclude_begin, s[a]) != null) : (a += 1) {}
	while (z > a and std.mem.findScalar(u8, exclude_end, s[z - 1]) != null) : (z -= 1) {}
	return .{ a, z };
}
pub fn trimStart(s: []const u8, exclude: []const u8) usize {
    var a: usize = 0;
    while (a < s.len and std.mem.findScalar(u8, exclude, s[a]) != null) : (a += 1) {}
    return a;
}

pub fn trimEnd(s: []const u8, exclude: []const u8) usize {
	var z: usize = s.len;
	while (z > 0 and std.mem.findScalar(u8, exclude, s[z - 1]) != null) : (z -= 1) {}
	return z;
}

fn resolveZ(paths: []const []const u8) ![:0]u8 {
	var res = try std.fs.path.resolve(gpa, paths);
	errdefer gpa.free(res);
	if (gpa.resize(res, res.len + 1)) {
		res.len += 1;
	} else {
		res = try gpa.realloc(res, res.len + 1);
	}
	res[res.len - 1] = 0;
	return res[0..res.len - 1 :0];
}

pub fn deinit(self: *Trax) void {
	for (self.list.items) |*item| switch (item.*) {
		.media => |*m| m.meta.deinit(gpa),
		.trax  => |*t| t.deinit(),
	};
	self.list.deinit(gpa);
	self.meta.deinit(gpa);
}

const TraverseMode = enum {
	normal,
	include,
};

pub fn traverse(
	self: *Trax,
	parents: *StringHashMap,
	file_path: []const u8,
	mode: TraverseMode,
) !void {
	if (parents.contains(file_path)) {
		if (mode == .normal) {
			err(self.list.items.len, error.InfiniteRecursion, file_path.ptr);
		}
		return;
	}
	try parents.put(gpa, file_path, {});
	defer _ = parents.remove(file_path);

	const file = std.Io.Dir.cwd().openFile(io, file_path, .{ .mode = .read_only })
		catch |e| return err(self.list.items.len, e, file_path.ptr);
	defer file.close(io);

	var buf: [std.fs.max_path_bytes:0]u8 = undefined;
	var r = file.reader(io, &buf);
	const base_dir = std.fs.path.dirname(file_path) orelse ".";
	while (r.interface.takeDelimiterExclusive('\n')) |line| {
		defer _ = r.interface.take(1) catch {};

		const line_start = r.interface.seek - line.len;
		const trim = trimRange(line, " \t", "\r");
		var begin = line_start + trim[0];
		const end = line_start + trim[1];

		// empty or comment
		if (begin >= end or buf[begin] == '#') {
			continue;
		}

		// command
		if (buf[begin] == '!') {
			begin += 1;
			if (std.mem.startsWith(u8, buf[begin..end], "include")) {
				begin += 7;
				begin += trimStart(buf[begin..end], " \t");
				if (begin >= end or buf[begin] != '@') {
					err(self.list.items.len, error.IncludeSyntaxError, file_path.ptr);
					continue;
				}
				const trimmed = buf[begin + 1 .. end];
				const resolved = if (std.fs.path.isAbsolute(trimmed))
					try resolveZ(&.{ trimmed })
				else try resolveZ(&.{ base_dir, trimmed });
				defer gpa.free(resolved);
				try self.traverse(parents, resolved, .include);
			}
			continue;
		}

		// file path
		if (buf[begin] == '@') {
			if (mode == .include) {
				break;
			}
			const trimmed = buf[begin + 1 .. end];
			const resolved = if (std.fs.path.isAbsolute(trimmed))
				try resolveZ(&.{ trimmed })
			else try resolveZ(&.{ base_dir, trimmed });
			defer gpa.free(resolved);

			if (isTrax(resolved)) {
				var trax: Trax = .{};
				try trax.traverse(parents, resolved, .normal);
				try self.list.append(gpa, .{ .trax = trax });
			} else {
				try self.list.append(gpa, .{ .media = .{ .file = .gen(resolved.ptr) } });
			}
			continue;
		}

		// key=value
		const eql = std.mem.findScalar(u8, buf[begin..end], '=') orelse continue;
		const kend = trimEnd(buf[begin..][0..eql], " \t");
		buf[end] = 0;
		buf[begin + kend] = 0;
		const key = buf[begin..][0..kend :0];
		const val = buf[begin + eql + 1 .. end :0];
		if (self.list.items.len == 0) {
			try self.meta.put(gpa, .gen(key), .gen(val));
		} else switch (self.list.items[self.list.items.len - 1]) {
			inline else => |*v| try v.meta.put(gpa, .gen(key), .gen(val)),
		}
	} else |e| if (e != error.EndOfStream) {
		return e;
	}
}
