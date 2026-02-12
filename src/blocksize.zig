const pd = @import("pd");

const Float = pd.Float;

const BlockSize = extern struct {
	obj: pd.Object = undefined,
	out: *pd.Outlet,

	const name = "blocksize";
	var class: *pd.Class = undefined;

	fn bangC(self: *BlockSize) callconv(.c) void {
		self.out.float(@floatFromInt(pd.this().stuff.blocksize));
	}

	fn initC() callconv(.c) ?*BlockSize {
		return pd.wrap(*BlockSize, init(), name);
	}
	inline fn init() !*BlockSize {
		const self: *BlockSize = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		self.* = .{ .out = try .init(obj, &pd.s_float) };
		return self;
	}

	inline fn setup() !void {
		class = try .init(BlockSize, name, &.{}, &initC, null, .{});
		class.addBang(@ptrCast(&bangC));
	}
};

export fn blocksize_setup() void {
	_ = pd.wrap(void, BlockSize.setup(), @src().fn_name);
}
