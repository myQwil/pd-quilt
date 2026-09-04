//! Checks an atom's type.

const pd = @import("pd");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Symbol = pd.Symbol;

const Proxy = struct {
	owner: *Is,

	const name = "_is_pxy";
	var class: *pd.Class = undefined;
	const Box = pd.Box(Pd, Proxy);

	fn anythingC(p: *const Pd, s: *Symbol, _: c_uint, _: [*]const Atom) callconv(.c) void {
		Box.stateConst(p).owner.type = s;
	}

	inline fn create(owner: *Is) pd.Oom!*Pd {
		const p = try class.pd();
		Box.state(p).* = .{ .owner = owner };
		return p;
	}

	inline fn setup() pd.Class.Error!void {
		class = try .create(name, &.{}, null, null, @sizeOf(Box), .{
			.bare = true,
			.no_inlet = true,
		});
		class.addAnything(&anythingC);
	}
};

const Is = struct {
	out: *pd.Outlet,
	type: *Symbol,
	proxy: *Pd,

	const name = "is";
	var class: *pd.Class = undefined;
	const Box = pd.Box(pd.Object, Is);

	fn printC(p: *const Pd) callconv(.c) void {
		pd.post.log(p, .normal, name ++ ": %s", .{ Box.stateConst(p).type.name });
	}

	fn bangC(p: *const Pd) callconv(.c) void {
		const self = Box.stateConst(p);
		self.out.float(if (self.type == pd.s.bang()) 1.0 else 0.0);
	}

	fn anythingC(
		p: *const Pd,
		s: *Symbol, ac: c_uint, _: [*]const Atom,
	) callconv(.c) void {
		const self = Box.stateConst(p);
		const t: *Symbol = if (ac > 0) s else pd.s.symbol();
		self.out.float(if (self.type == t) 1 else 0);
	}

	fn createC(s: *Symbol) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, create(s), name);
	}
	inline fn create(s: *Symbol) pd.Oom!*Pd {
		const obj: *pd.Object = @ptrCast(try class.pd());
		const self = Box.state(&obj.g.pd);
		errdefer obj.g.pd.destroy();

		const proxy: *Pd = try Proxy.create(self);
		errdefer proxy.destroy();

		_ = try obj.inlet(proxy, null, null);
		self.* = .{
			.out = try .create(obj, pd.s.float()),
			.type = if (s != pd.s.empty()) s else pd.s.float(),
			.proxy = proxy,
		};
		return &obj.g.pd;
	}

	fn destroyC(p: *const Pd) callconv(.c) void {
		Box.stateConst(p).proxy.destroy();
	}

	inline fn setup() pd.Class.Error!void {
		class = try .create(name, &.{ .defsymbol }, &createC, &destroyC, @sizeOf(Box), .{});
		class.addBang(&bangC);
		class.addAnything(&anythingC);
		class.addMethod(&.{}, &printC, .gen("print"));
		try Proxy.setup();
	}
};

export fn is_setup() void {
	_ = pd.wrap(void, Is.setup(), @src().fn_name);
}
