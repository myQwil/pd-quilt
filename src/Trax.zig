const Trax = @This();
const std = @import("std");
const pd = @import("pd");

/// list of entries/traxs
list: std.ArrayList(Union) = .empty,
/// top-level metadata
meta: MetaHashMap = .init(gpa),

const Symbol = pd.Symbol;
pub const StringHashMap = std.StringHashMap(void);
pub const MetaHashMap = std.AutoArrayHashMap(*Symbol, *Symbol);

const Union = union(enum) {
	media: Media,
	trax: Trax,
};

const Media = struct {
	/// path to the file
	file: *Symbol,
	/// file metadata
	meta: MetaHashMap = .init(gpa),
};

pub const ext = ".trax";

const gpa = pd.gpa;
const io = std.Io.Threaded.global_single_threaded.ioBasic();

pub inline fn isTrax(filename: []const u8) bool {
	return std.mem.endsWith(u8, filename, ext);
}

/// Print message and skip, do not fail completely by returning error.
inline fn err(len: usize, e: anyerror, s: [*:0]const u8) void {
	pd.post.err(null, "%u:%s: \"%s\"", .{ len, @errorName(e).ptr, s });
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

inline fn getResolved(trimmed: []const u8, base_dir: []const u8) ![:0]u8 {
	return if (std.fs.path.isAbsolute(trimmed))
		try resolveZ(&.{ trimmed })
	else
		try resolveZ(&.{ base_dir, trimmed });
}

pub fn deinit(self: *Trax) void {
	for (self.list.items) |*item| switch (item.*) {
		.media => |*m| m.meta.deinit(),
		.trax  => |*t| t.deinit(),
	};
	self.list.deinit(gpa);
	self.meta.deinit();
}

const TraverseMode = enum {
	/// read the entire playlist
	normal,
	/// read only the top-level metadata
	include,
};

pub fn traverse(
	self: *Trax,
	parents: *StringHashMap,
	file_path: [:0]const u8,
	mode: TraverseMode,
) !void {
	if (parents.contains(file_path)) {
		if (mode == .normal) {
			err(self.list.items.len, error.InfiniteRecursion, file_path.ptr);
		}
		return;
	}
	try parents.put(file_path, {});
	defer _ = parents.remove(file_path);

	const file = std.Io.Dir.cwd().openFile(io, file_path, .{ .mode = .read_only })
		catch |e| return err(self.list.items.len, e, file_path.ptr);
	defer file.close(io);

	var buf: [std.fs.max_path_bytes:0]u8 = undefined;
	var r = file.reader(io, &buf);
	const base_dir = std.fs.path.dirname(file_path) orelse ".";
	while (r.interface.takeDelimiterExclusive('\n')) |line| {
		defer _ = r.interface.take(1) catch {};

		const trim: [2]usize = blk: {
			const line_start = r.interface.seek - line.len;
			const tstart: usize = trimStart(line, " \t");
			const tend: usize = tstart + trimEnd(line[tstart..], "\r");
			break :blk .{ line_start + tstart, line_start + tend };
		};

		// empty or comment
		if (trim[0] >= trim[1] or buf[trim[0]] == '#') {
			continue;
		}

		// !include @path
		if (std.mem.startsWith(u8, buf[trim[0]..trim[1]], "!include")) {
			const arg = blk: {
				const arg = trim[0] + 8;
				break :blk arg + trimStart(buf[arg..trim[1]], " \t");
			};
			if (arg >= trim[1] or buf[arg] != '@') {
				err(self.list.items.len, error.IncludeSyntaxError, file_path.ptr);
				continue;
			}
			const resolved = try getResolved(buf[arg + 1 .. trim[1]], base_dir);
			defer gpa.free(resolved);
			try self.traverse(parents, resolved, .include);
			continue;
		}

		// @path
		if (buf[trim[0]] == '@') {
			if (mode == .include) {
				break;
			}
			const resolved = try getResolved(buf[trim[0] + 1 .. trim[1]], base_dir);
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
		const eql = std.mem.findScalar(u8, buf[trim[0]..trim[1]], '=') orelse continue;
		const kend = trimEnd(buf[trim[0]..][0..eql], " \t");
		buf[trim[1]] = 0;
		buf[trim[0] + kend] = 0;
		const key = buf[trim[0]..][0..kend :0];
		const val = buf[trim[0] + eql + 1 .. trim[1] :0];
		if (self.list.items.len == 0) {
			try self.meta.put(.gen(key), .gen(val));
		} else switch (self.list.items[self.list.items.len - 1]) {
			inline else => |*v| try v.meta.put(.gen(key), .gen(val)),
		}
	} else |e| if (e != error.EndOfStream) {
		return e;
	}
}

pub fn trackPath(path: []const u8) !?[:0]const u8 {
	const txdir = ext ++ "/";
	const dot = std.mem.findScalarLast(u8, path, '.') orelse path.len;
	var trx_path = try gpa.alloc(u8, dot + txdir.len + ext.len + 1);

	// first try `dir/.trax/file.trax`, then `dir/file.trax`
	var i: usize = 0;
	if (std.fs.path.dirname(path)) |dir| {
		@memcpy(trx_path[0..dir.len], dir);
		trx_path[dir.len] = '/';
		i += dir.len + 1;
	}
	const base = path[i..dot];
	@memcpy(trx_path[i..][0..txdir.len], txdir);
	i += txdir.len;
	@memcpy(trx_path[i..][0..base.len], base);
	i += base.len;
	@memcpy(trx_path[i..][0..ext.len], ext);
	i += ext.len;
	std.Io.Dir.cwd().access(io, trx_path[0..i], .{ .read = true }) catch {
		@memcpy(trx_path[0..dot], path[0..dot]);
		@memcpy(trx_path[dot..][0..ext.len], ext);
		i = dot + ext.len;
		std.Io.Dir.cwd().access(io, trx_path[0..i], .{ .read = true }) catch {
			gpa.free(trx_path);
			return null;
		};
	};
	trx_path[i] = 0;

	std.debug.assert(i + 1 <= trx_path.len);
	trx_path = gpa.realloc(trx_path, i + 1) catch unreachable;
	return trx_path[0..i :0];
}
