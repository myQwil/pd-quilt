const pd = @import("pd");
const std = @import("std");

const Float = pd.Float;
const Writer = std.Io.Writer;

const prec = if (@bitSizeOf(Float) == 64) 14 else 6;

pub fn fmtG(stream: *Writer, f: Float) !void {
	const gmin = @exp(@log(10.0) * (2 - prec));
	const gmax = @exp(@log(10.0) * prec);

	const g = @abs(f);
	if (g < gmin and g != 0 or gmax <= g) {
		try stream.print("{e}", .{ f });
	} else {
		try stream.print("{d}", .{ f });
	}
}

pub fn writeVec(writer: *Writer, vec: []const pd.Word) !void {
	if (vec.len == 0) {
		_ = try writer.write("[]");
		return;
	}
	try writer.writeByte('[');
	try fmtG(writer, vec[0].float);
	for (vec[1..]) |w| {
		_ = try writer.write(", ");
		try fmtG(writer, w.float);
	}
	try writer.writeByte(']');
}

pub fn ellipsis(w: *Writer) void {
	w.end = w.buffer.len - 3;
	w.writeAll("...") catch unreachable;
}
