const std = @import("std");
const pd = @import("pd");
const ru = @import("rubber");
const pr = @import("player.zig");
const Inlet = @import("inlet.zig").Inlet;

const Pd = pd.Pd;
const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;
const Allocator = std.mem.Allocator;

var s_delay: *Symbol = undefined;

pub const Rubber = extern struct {
	state: *ru.State,
	tempo: *Float,

	pub inline fn init(
		gpa: Allocator,
		obj: *pd.Object,
		channels: u8,
		av: []const Atom,
	) pd.Oom!Rubber {
		const in3: *Inlet = @ptrCast(@alignCast(try obj.inletSignal(1.0)));
		return .{
			.tempo = &in3.un.floatsignalvalue,
			.state = try .init(
				@intFromFloat(pd.sampleRate()), channels, 1, 1, try parseOptions(gpa, av)),
		};
	}

	pub inline fn deinit(self: *Rubber) void {
		self.state.deinit();
	}

	pub inline fn reset(self: *Rubber) void {
		self.state.reset();
	}

	pub fn processStartPad(
		self: *Rubber,
		planar: [*][*]pd.Sample,
		channels: u8,
		frames: u8,
	) void {
		for (planar[0..channels]) |ch| {
			@memset(ch[0..frames], 0);
		}
		var pad = self.state.getPreferredStartPad();
		while (pad > 0) {
			const len: u32 = @min(frames, pad);
			self.state.process(planar, len, false);
			pad -= len;
		}
	}
};

const FieldSetFunc = fn(*ru.Options, *Symbol) void;
var dict: std.AutoHashMap(*Symbol, *const FieldSetFunc) = undefined;
pub fn freeDict() void {
	dict.deinit();
}

fn parseOptions(gpa: Allocator, av: []const Atom) pd.Oom!ru.Options {
	var options: ru.Options = .{ .process = .realtime, .engine = .finer };
	for (av) |a| {
		if (a.getSymbol()) |s| {
			const name = std.mem.sliceTo(s.name, 0);
			const eql = std.mem.findScalar(u8, name, '=') orelse continue;
			const str = try gpa.dupeSentinel(u8, name, 0);
			defer gpa.free(str);

			str[eql] = 0;
			const key: *Symbol = .gen(str[0..eql :0]);
			if (dict.get(key)) |set| {
				set(&options, .gen(str[eql+1.. :0]));
			} else {
				pd.post.err(null, "rubberband: option `%s` not recognized", .{ key.name });
			}
		}
	}
	return options;
}

fn getEnum(T: type, s: *Symbol) ?T {
	return inline for (@typeInfo(T).@"enum".fields) |field| {
		const field_symbol: *Symbol = .gen(field.name);
		if (field_symbol == s) {
			break @enumFromInt(field.value);
		}
	} else blk: {
		pd.post.err(null, "%s: value `%s` not recognized", .{ @typeName(T).ptr, s.name });
		break :blk null;
	};
}

fn FieldSetter(comptime name: []const u8) type { return struct {
	fn set(options: *ru.Options, s: *Symbol) void {
		if (getEnum(@TypeOf(@field(options, name)), s)) |value| {
			@field(options, name) = value;
		}
	}
};}

pub fn Impl(Self: type) type { return struct {
	const parentPtr = Self.parentPtr;

	fn transientsC(p: *Pd, s: *Symbol) callconv(.c) void {
		if (getEnum(ru.Options.Transients, s)) |value| {
			const rubber: *Rubber = &parentPtr(p).rubber;
			rubber.state.setTransientsOption(value);
		}
	}

	fn detectorC(p: *Pd, s: *Symbol) callconv(.c) void {
		if (getEnum(ru.Options.Detector, s)) |value| {
			const rubber: *Rubber = &parentPtr(p).rubber;
			rubber.state.setDetectorOption(value);
		}
	}

	fn formantC(p: *Pd, s: *Symbol) callconv(.c) void {
		if (getEnum(ru.Options.Formant, s)) |value| {
			const rubber: *Rubber = &parentPtr(p).rubber;
			rubber.state.setFormantOption(value);
		}
	}

	fn phaseC(p: *Pd, s: *Symbol) callconv(.c) void {
		if (getEnum(ru.Options.Phase, s)) |value| {
			const rubber: *Rubber = &parentPtr(p).rubber;
			rubber.state.setPhaseOption(value);
		}
	}

	fn pitchC(p: *Pd, s: *Symbol) callconv(.c) void {
		if (getEnum(ru.Options.Pitch, s)) |value| {
			const rubber: *Rubber = &parentPtr(p).rubber;
			rubber.state.setPitchOption(value);
		}
	}

	fn fscaleC(p: *Pd, f: Float) callconv(.c) void {
		const rubber: *Rubber = &parentPtr(p).rubber;
		rubber.state.setFormantScale(f);
	}

	fn tempoC(p: *Pd, f: Float) callconv(.c) void {
		const rubber: *Rubber = &parentPtr(p).rubber;
		rubber.tempo.* = f;
	}

	fn delayC(p: *Pd) callconv(.c) void {
		const self = parentPtr(p);
		const player: *pr.Player = &self.base.player;
		const rubber: *Rubber = &self.rubber;
		player.outlet.anything(s_delay, &.{
			.float(@floatFromInt(rubber.state.getStartDelay())),
		});
	}

	pub inline fn extend(gpa: Allocator) Allocator.Error!void {
		s_delay = .gen("delay");

		dict = .init(gpa);
		errdefer dict.deinit();
		inline for ([_][:0]const u8{
			"transients", "detector", "phase", "threading", "window",
			"smoothing", "formant", "pitch", "channels", "engine",
		}) |name| {
			try dict.put(.gen(name), &FieldSetter(name).set);
		}

		const class: *pd.Class = Self.class;
		class.addMethod(&.{ .symbol }, transientsC, .gen("transients"));
		class.addMethod(&.{ .symbol }, detectorC, .gen("detector"));
		class.addMethod(&.{ .symbol }, formantC, .gen("formant"));
		class.addMethod(&.{ .symbol }, phaseC, .gen("phase"));
		class.addMethod(&.{ .symbol }, pitchC, .gen("pitch"));
		class.addMethod(&.{ .float }, fscaleC, .gen("fscale"));
		class.addMethod(&.{ .float }, tempoC, .gen("tempo"));
		class.addMethod(&.{}, delayC, s_delay);
	}
};}
