#!/usr/bin/env python3

import re
import subprocess

include = '/usr/include/'

types = {
	'atomtype': 't_atomtype',

	'array': 'cnv.Array',
	'canvasenvironment': 'cnv.CanvasEnvironment',
	'dataslot': 'cnv.DataSlot',
	'glist': 'cnv.GList',
	'glistkeyfn': 'cnv.GListKeyFn',
	'glistmotionfn': 'cnv.GListMotionFn',
	'parentwidgetbehavior': 'cnv.ParentWidgetBehavior',
	'template': 'cnv.Template',
	'widgetbehavior': 'cnv.WidgetBehavior',

	'iem_fstyle_flags': 'iem.FontStyleFlags',
	'iem_init_symargs': 'iem.InitSymArgs',
	'iemgui': 'iem.Gui',
	'iemgui_drawfunctions': 'iem.DrawFunctions',

	'binbuf': 'pd.BinBuf',
	'classfreefn': 'pd.ClassFreeFn',
	'floatarg': 'pd.Float',
	'garray': 'pd.GArray',
	'gobj': 'pd.GObj',
	'gpointer': 'pd.GPointer',
	'gstub': 'pd.GStub',
	'guicallbackfn': 'pd.GuiCallbackFn',
	'newmethod': 'pd.NewMethod',
	'perfroutine': 'pd.PerfRoutine',
	'propertiesfn': 'pd.PropertiesFn',
	'savefn': 'pd.SaveFn',
	'text': 'pd.Object',
}

vec_names = ['argv', 'av', 'vec']

# Types should be TitleCase and referential to our tailored zig definitions
r_type = r'([^\w])(?:struct__|t_|union_)(\w+)'
def re_type(m):
	name = m.group(2)
	name = types[name] if name in types else ('pd.' + name.capitalize())
	return m.group(1) + name

# Assume pointers aren't intended to be optional except in special cases,
# and assume char pointers are supposed to be null-terminated strings
r_param = r'(\w+): (?:\[\*c\]|\?\*)(const )?([\w\.]+)'
def re_param(m):
	name = m.group(1)
	typ = m.group(3)
	p = None
	for vec in vec_names:
		if name.endswith(vec):
			p = '[*]'
			break;
	if p == None:
		p = '[*:0]' if typ == 'u8' else '*'
	return m.group(1) + ': ' + p + (m.group(2) or '') + typ

# Assume double pointer is an array pointer or a symbol pointer
# (this is probably wrong sometimes and should eventually be changed)
r_dblptr = r'\[\*c\]\[\*c\](const )?([\w\.]+)'
def re_dblptr(m):
	ptr = '**' if m.group(2) == 'pd.Symbol' else '*[*]'
	return ptr + (m.group(1) or '') + m.group(2)


################################################################################
# Main
if __name__ == '__main__':
	lines: list[str]

	# Zig's C-translator does not like bit fields (for now)
	with open(include + 'm_pd.h', 'r') as f:
		lines = f.read().splitlines()
		for i in range(len(lines)):
			if lines[i].startswith('    unsigned int te_type:2;'):
				lines[i] = '    unsigned char te_type;'
			elif lines[i].startswith('PD_DEPRECATED'):
				lines[i] = ''
	lines += [
		'#include <pd/m_imp.h>',
		'#include <pd/g_canvas.h>',
		'#include <pd/g_all_guis.h>',
	]
	with open('m_pd.h', 'w') as f:
		f.write('\n'.join(lines))

	# Translate to zig
	out = subprocess.check_output([
		'zig', 'translate-c',
		'-isystem', include,
		'm_pd.h',
	], encoding='utf-8')

	# Make some alterations to the translated file
	lines = out.splitlines()
	for i in range(len(lines)):
		if re.match(r'(pub extern fn|pub const \w+ = \?\*const fn)', lines[i]):
			m = re.match(r'(.*)\((?!\.)(.*)\)(.*)', lines[i])
			if m:
				ret = re.sub(r_type, re_type, m.group(3))
				args = re.sub(r_type, re_type, m.group(2))
				args = re.sub(r_param, re_param, args)
				args = re.sub(r_dblptr, re_dblptr, args)
				lines[i] = m.group(1) + '(' + args + ')' + ret
		elif re.match(r'pub const t_(\w+) = struct__(\w+)', lines[i]):
			lines[i] = re.sub(r'([^\w])(?:struct__|union_)(\w+)', re_type, lines[i])

	with open('m_pd.zig', 'w') as f:
		f.write(
			'const pd = @import("main.zig");\n' +
			'const iem = @import("iem.zig");\n' +
			'const cnv = @import("canvas.zig");\n' +
			'\n'.join(lines)
		)
