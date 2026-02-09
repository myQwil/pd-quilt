const std = @import("std");
const pd = @import("pd");
const ru = @import("rubber");
const pr = @import("player.zig");
const Inlet = @import("inlet.zig").Inlet;

const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;

const gpa = pd.gpa;
var s_delay: *Symbol = undefined;

pub const Rubber = extern struct {
	state: *ru.State,
	tempo: *Float,

	pub inline fn init(obj: *pd.Object, channels: u8, av: []const Atom) !Rubber {
		const in3: *Inlet = @ptrCast(@alignCast(try obj.inletSignal(1.0)));
		return .{
			.tempo = &in3.un.floatsignalvalue,
			.state = try .init(@intFromFloat(pd.sampleRate()), channels,
				try parseOptions(av), 1, 1),
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

fn parseOptions(av: []const Atom) !ru.Options {
	var options: ru.Options = .{ .process = .realtime, .engine = .finer };
	for (av) |a| {
		if (a.getSymbol()) |s| {
			const name = std.mem.sliceTo(s.name, 0);
			const eql = std.mem.findScalar(u8, name, '=') orelse continue;
			const str = try gpa.dupeZ(u8, name);
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
	fn transientsC(self: *Self, s: *Symbol) callconv(.c) void {
		if (getEnum(ru.Options.Transients, s)) |value| {
			const rubber: *Rubber = &self.rubber;
			rubber.state.setTransientsOption(value);
		}
	}

	fn detectorC(self: *Self, s: *Symbol) callconv(.c) void {
		if (getEnum(ru.Options.Detector, s)) |value| {
			const rubber: *Rubber = &self.rubber;
			rubber.state.setDetectorOption(value);
		}
	}

	fn formantC(self: *Self, s: *Symbol) callconv(.c) void {
		if (getEnum(ru.Options.Formant, s)) |value| {
			const rubber: *Rubber = &self.rubber;
			rubber.state.setFormantOption(value);
		}
	}

	fn phaseC(self: *Self, s: *Symbol) callconv(.c) void {
		if (getEnum(ru.Options.Phase, s)) |value| {
			const rubber: *Rubber = &self.rubber;
			rubber.state.setPhaseOption(value);
		}
	}

	fn pitchC(self: *Self, s: *Symbol) callconv(.c) void {
		if (getEnum(ru.Options.Pitch, s)) |value| {
			const rubber: *Rubber = &self.rubber;
			rubber.state.setPitchOption(value);
		}
	}

	fn fscaleC(self: *Self, f: Float) callconv(.c) void {
		const rubber: *Rubber = &self.rubber;
		rubber.state.setFormantScale(f);
	}

	fn tempoC(self: *Self, f: Float) callconv(.c) void {
		const rubber: *Rubber = &self.rubber;
		rubber.tempo.* = f;
	}

	fn delayC(self: *Self) callconv(.c) void {
		const player: *pr.Player = &self.base.player;
		const rubber: *Rubber = &self.rubber;
		player.outlet.anything(s_delay, &.{
			.float(@floatFromInt(rubber.state.getStartDelay())),
		});
	}

	pub inline fn extend() !void {
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
		class.addMethod(@ptrCast(&transientsC), .gen("transients"), &.{ .symbol });
		class.addMethod(@ptrCast(&detectorC), .gen("detector"), &.{ .symbol });
		class.addMethod(@ptrCast(&formantC), .gen("formant"), &.{ .symbol });
		class.addMethod(@ptrCast(&phaseC), .gen("phase"), &.{ .symbol });
		class.addMethod(@ptrCast(&pitchC), .gen("pitch"), &.{ .symbol });
		class.addMethod(@ptrCast(&fscaleC), .gen("fscale"), &.{ .float });
		class.addMethod(@ptrCast(&tempoC), .gen("tempo"), &.{ .float });
		class.addMethod(@ptrCast(&delayC), s_delay, &.{});
	}
};}
