const strlen = @import("std").mem.len;
pub const Callback = ?*const fn (*anyopaque, **f32) callconv(.C) c_long;
const success = 0;
const err_offset = 1;

pub const Error = error {
	MallocFailed,
	BadState,
	BadData,
	BadDataPtr,
	NoPrivate,
	BadRatio,
	BadProcPtr,
	ShiftBits,
	FilterLen,
	BadConverter,
	BadChannelCount,
	SincBadBufferLen,
	SizeIncompatibility,
	BadPrivPtr,
	BadSincState,
	DataOverlap,
	BadCallback,
	BadMode,
	NullCallback,
	NoVariableRatio,
	SincPrepareDataBadLen,
	BadInternalState,
};

fn toError(err: u16) Error {
	const start = @intFromError(Error.MallocFailed);
	return @errorCast(@errorFromInt(start + err - err_offset));
}

pub const Converter = enum(c_uint) {
	const Self = @This();

	sinc_best,
	sinc_medium,
	sinc_fast,
	zero_order_hold,
	linear,

	const lo = @intFromEnum(Self.sinc_best);
	const hi = @intFromEnum(Self.linear);
	pub fn expectValid(i: i32) !void {
		if (i < lo or hi < i)
			return Error.BadConverter;
	}
};

pub const Data = extern struct {
	const Self = @This();

	in: [*]const f32,     // set by caller, pointer to the input data samples
	out: [*]f32,          // set by caller, pointer to the output data samples
	in_frames: c_long,    // set by caller, number of input frames
	out_frames: c_long,   // set by caller, max number of output frames
	in_frames_used: c_long, // number of input frames consumed
	out_frames_gen: c_long, // number of output frames generated
	end: c_int,           // set by caller, 0 if more input data is available
	ratio: f64,           // set by caller, output_sample_rate / input_sample_rate

	extern fn src_simple(*Self, conv: Converter, chans: c_int) c_int;
	pub fn simple(self: *Self, conv: Converter, chans: u32) Error!void {
		const result = src_simple(self, conv, @intCast(chans));
		return if (result == success) {} else toError(@intCast(result));
	}
};

pub const State = opaque {
	const Self = @This();

	extern fn src_new(conv: Converter, chans: c_int, err: *c_int) ?*State;
	pub fn new(conv: Converter, chans: u32) Error!*State {
		var result: c_int = undefined;
		const state = src_new(conv, @intCast(chans), &result);
		return if (state) |s| s else toError(@intCast(result));
	}

	extern fn src_clone(*Self, err: *c_int) ?*Self;
	pub fn clone(self: *Self) Error!*Self {
		var result: c_int = undefined;
		const cln = src_clone(self, &result);
		return if (cln) |s| s else toError(@intCast(result));
	}

	extern fn src_callback_new( // initilisation for callback based API
		func: Callback, conv: Converter, chans: c_int, err: *c_int, cb_data: ?*anyopaque,
	) ?*Self;
	pub fn callbackNew(
		func: Callback, conv: Converter, chans: u32, cb_data: ?*anyopaque,
	) Error!*Self {
		var result: c_int = 0;
		const self = src_callback_new(func, conv, chans, &result, cb_data);
		return if (self) |s| s else toError(@intCast(result));
	}

	extern fn src_delete(*Self) ?*Self;
	pub fn delete(self: *Self) void {
		_ = src_delete(self);
	}

	extern fn src_process(*Self, data: *Data) c_int;
	pub fn process(self: *Self, data: *Data) Error!void {
		const result = src_process(self, data);
		return if (result == success) {} else toError(@intCast(result));
	}

	extern fn src_callback_read(*Self, ratio: f64, frames: c_long, data: *f32) c_long;
	pub fn callbackRead(
		self: *Self, ratio: f64, frames: c_long, data: *f32,
	) Error!usize {
		const result = src_callback_read(self, ratio, frames, data);
		return if (result >= 0) @intCast(result) else toError(@intCast(-frames));
	}

	extern fn src_set_ratio(*Self, new_ratio: f64) c_int;
	pub fn setRatio(self: *Self, new_ratio: f64) Error!void {
		const result = src_set_ratio(self, new_ratio);
		return if (result == success) {} else toError(@intCast(result));
	}

	extern fn src_get_channels(*Self) c_int;
	pub fn getChannels(self: *Self) Error!void {
		const result = src_get_channels(self);
		return if (result >= 0) {} else toError(@intCast(result));
	}

	extern fn src_reset(*Self) c_int;
	pub fn reset(self: *Self) Error!void {
		const result = src_reset(self);
		return if (result == success) {} else toError(@intCast(result));
	}

	extern fn src_error(*Self) c_int;
	pub fn getError(self: *Self) Error {
		return toError(@intCast(src_error(self)));
	}
};

extern fn src_get_name(conv: Converter) ?[*:0]const u8;
pub fn getName(conv: Converter) ?[]const u8 {
	const str = src_get_name(conv);
	return if (str) |s| s[0..strlen(s)] else null;
}

extern fn src_get_description(conv: Converter) ?[*:0]const u8;
pub fn getDescription(conv: Converter) ?[]const u8 {
	const str = src_get_description(conv);
	return if (str) |s| s[0..strlen(s)] else null;
}

extern fn src_get_version() [*:0]const u8;
pub fn getVersion() []const u8 {
	const s = src_get_version();
	return s[0..strlen(s)];
}

extern fn src_strerror(err: c_int) ?[*:0]const u8;
pub fn strError(err: Error) ?[]const u8 {
	const str = src_strerror(@intFromError(err));
	return if (str) |s| s[0..strlen(s)] else null;
}

extern fn src_is_valid_ratio(ratio: f64) c_int;
pub fn isValidRatio(ratio: f64) bool {
	return (src_is_valid_ratio(ratio) != 0);
}

extern fn src_short_to_float_array(in: [*]const c_short, out: [*]f32, len: c_int) void;
pub fn shortToFloat(in: [*]const i16, out: []f32) void {
	src_short_to_float_array(in, out.ptr, @intCast(out.len));
}

extern fn src_float_to_short_array(in: [*]const f32, out: [*]c_short, len: c_int) void;
pub fn floatToShort(in: [*]const f32, out: []i16) void {
	src_float_to_short_array(in, out.ptr, @intCast(out.len));
}

extern fn src_int_to_float_array(in: [*]const c_int, out: [*]f32, len: c_int) void;
pub fn intToFloat(in: [*]const i32, out: []f32) void {
	src_int_to_float_array(in, out.ptr, @intCast(out.len));
}

extern fn src_float_to_int_array(in: [*]const f32, out: [*]c_int, len: c_int) void;
pub fn floatToInt(in: [*]const f32, out: []i32) void {
	src_float_to_int_array(in, out.ptr, @intCast(out.len));
}

