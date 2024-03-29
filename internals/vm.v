module internals

import encoding.binary as bin
import strings

const u16_max = 0xFFFF
const cp_mask = 0b10000000

// 
// cannot have more than 127 Opcodes,
// highest bit is used as a flag.
// 
pub enum Opcode as u8 {
	add // R + R
	sub // R - R
	mul // R * R
	div // R / R
	mod // R % R
	bor // R | R
	and // R & R
	xor // R ^ R
	_infix_end_
	neg // -R
	not // ~R
	_prefix_end_
	load  // load R, R
	index // index env['value']
	store // store R, R
	_special_end_
}

// --- infix expression
// 
// [ u8 ] [  u16  ] [  u16  ] [  u16  ]
// ^op    ^dest     ^reg a    ^reg b
// 
// op & 0b10000000 == `reg b` is constant pool

// --- unary expression
// 
// [ u8 ] [  u16  ] [  u16  ]
// ^op    ^dest     ^reg a
// 
// op & 0b10000000 == `reg a` is constant pool

// --- load (load register or constant)
//  R0 = load R1
//  R0 = load 20
// 
// [ u8 ] [  u16  ] [  u16  ]
// ^op    ^dest     ^src
// 
// op & 0b10000000 == `src` is constant pool

// --- index (index the current enviroment or register, by a string literal or register)
//  R0 = index env['hello']
//  R0 = index R0['hello']
//  R0 = index R0[R0]
// 
// [ u8 ] [  u16  ] [  u16  ] [  u16  ]
// ^op    ^dest     ^src      ^index
// 
// src == 0xFFFF   == `src` is current enviroment, else register
// op & 0b10000000 == `index` is constant pool, else registers

// UNUSED, NOT IMPLEMENTED
// 
// 
/* // --- store (store to upvalue)
//  env['hello'] = store 20
//  R0['child'] = store nil 
// 
// [ u8 ] [  u16  ] [  u16  ] [  u16  ]
// ^op    ^base     ^upval    ^src
// 
// op & 0b10000000 == `base` is current enviroment, else register
*/

fn (kind Kind) infix_to_opcode() Opcode {
	return match kind {
		.add { Opcode.add }
		.sub { Opcode.sub }
		.mul { Opcode.mul }
		.div { Opcode.div }
		.mod { Opcode.mod }
		.b_or  { Opcode.bor }
		.b_and { Opcode.and }
		.b_xor { Opcode.xor }
		else { panic("Kind.infix_to_opcode: kind `${kind}` not implemented") }
	}
}

fn (kind Kind) unary_to_opcode() Opcode {
	return match kind {
		.sub   { Opcode.neg }
		.b_not { Opcode.not }
		else { panic("Kind.unary_to_opcode: kind `${kind}` not implemented") }
	}
}

[heap]
pub struct VM {
pub mut:
	code []u8
	constant_pool []VValue
}

// append `u8`
fn (mut v VM) a8(val u8) {
	v.code << val
}

// append `u16`
fn (mut v VM) a16(val u16) {
	v.code << [u8(0), 0]
	bin.little_endian_put_u16_end(mut v.code, val)
}

fn (v VM) u8_at(idx int) u8 {
	return v.code[idx]
}
fn (v VM) u16_at(idx int) u16 {
	return bin.little_endian_u16_at(v.code, idx)
}

fn (mut v VM) const_pool_append(val Cval) u16 {	
	idx := u16(v.constant_pool.len)

	v.constant_pool << match val.v {
		Cnum   { VValue(VNum(val.v)) }
		Cident { VValue(VStr(val.v)) }
		else { panic("unreachable") }
	}

	assert v.constant_pool.len <= u16_max

	return idx
}

pub fn (mut v VM) encode_overloaded_operand(opidx int, b Cval) {
	if b.v is Creg {
		v.a16(b.v)		
	} else {
		v.code[opidx] |= cp_mask
		v.a16(v.const_pool_append(b))
	}
}

pub fn (mut v VM) encode_infix(typ Opcode, dest Creg, a Creg, b Cval) {
	assert b.v is Cnum || b.v is Creg /* || b.v is Cstr */
	assert isnil(b.next)

	opidx := v.code.len
	v.a8(u8(typ))
	v.a16(dest)
	v.a16(u8(a))
	v.encode_overloaded_operand(opidx, b)
}

pub fn (mut v VM) encode_unary(typ Opcode, dest Creg, a Cval) {
	assert a.v is Cnum || a.v is Creg /* || b.v is Cstr */
	assert isnil(a.next)

	opidx := v.code.len
	v.a8(u8(typ))
	v.a16(dest)
	v.encode_overloaded_operand(opidx, a)
}

pub fn (mut v VM) encode_index(dest Creg, src Creg, index Cval, is_env bool) {
	assert index.v is Cident || index.v is Creg

	opidx := v.code.len
	v.a8(u8(Opcode.index))
	v.a16(dest)

	if is_env {
		v.a16(u16_max)
	} else {
		v.a16(src)
	}
	
	v.encode_overloaded_operand(opidx, index)
}


pub fn (mut v VM) encode_load(dest Creg, src Cval) {
	// assert src.v is Cnum || src.v is Creg /* || src.v is Cstr */
	
	opidx := v.code.len
	v.a8(u8(Opcode.load))
	v.a16(dest)
	v.encode_overloaded_operand(opidx, src)
}

pub fn (mut v VM) encode_store(dest Creg, src Cval) {
	assert src.v is Cnum || src.v is Creg /* || src.v is Cstr */
	
	opidx := v.code.len
	v.a8(u8(Opcode.store))
	v.a16(dest)
	v.encode_overloaded_operand(opidx, src)
}

struct OpcodeParser {
	v &VM
mut:
	ip   int
}

pub fn (mut p OpcodeParser) read_op() (Opcode, bool) {
	defer {
		p.ip++
	}
	return unsafe { Opcode(p.v.u8_at(p.ip) & ~cp_mask) }, (p.v.u8_at(p.ip) & cp_mask) != 0
}

pub fn (mut p OpcodeParser) read_2_u16() (u16, u16) {
	a := p.v.u16_at(p.ip) p.ip += 2
	b := p.v.u16_at(p.ip) p.ip += 2
	return a, b
}

pub fn (mut p OpcodeParser) read_3_u16() (u16, u16, u16) {
	a := p.v.u16_at(p.ip) p.ip += 2
	b := p.v.u16_at(p.ip) p.ip += 2
	c := p.v.u16_at(p.ip) p.ip += 2
	return a, b, c
}

const max_size = 25

pub fn (v &VM) disassemble() string {
	mut p := OpcodeParser{v: v}

	mut sb_out := strings.new_builder(120)

	for p.ip < v.code.len {
		ip_start := p.ip
		op, is_cp := p.read_op()

		sb_out.write_string(p.ip.hex_full())
		sb_out.write_string(' | ')

		disass := match op {
			.add, .sub, .mul, .div, .mod, .bor, .and, .xor {
				dest, a, b := p.read_3_u16()

				if is_cp {
					'R${dest} = ${op} R${a}, ${v.constant_pool[b]}'
				} else {
					'R${dest} = ${op} R${a}, R${b}'
				}
			}
			.load, .store {
				dest, src := p.read_2_u16()

				if is_cp {
					'R${dest} = ${op} ${v.constant_pool[src]}'
				} else {
					'R${dest} = ${op} R${src}'
				}
			}
			.index {
				dest, src, index := p.read_3_u16()
				
				src_str := if src == u16_max {
					'env'
				} else {
					'R${src}'
				}

				if is_cp {
					'R${dest} = index ${src_str}[${v.constant_pool[index]}]'
				} else {
					'R${dest} = index ${src_str}[R${index}]'
				}
			}
			.neg, .not {
				dest, src := p.read_2_u16()
				if is_cp {
					'R${dest} = ${op} ${v.constant_pool[src]}'
				} else {
					'R${dest} = ${op} R${src}'
				} 
			}
			else { panic("VM.disassemble: operator `${op}` unimplemented") }
		}

		arr := v.code[ip_start..p.ip]
		for val in arr {
			sb_out.write_string(val.hex())
			sb_out.write_u8(` `)
		}
		sb_out.write_string(` `.repeat(max_size - arr.len * 3))
		sb_out.writeln(disass)
	}

	return sb_out.str()
}

pub fn (mut v VM) execute(reg_cap int, mut env Enviroment) ![]VValue {
	mut p := OpcodeParser{v: v}

	mut regs := []VValue{len: reg_cap, init: VNil{}}

	for p.ip < v.code.len {
		op, is_cp := p.read_op()

		if u8(op) < u8(Opcode._infix_end_) {
			dest, a, b := p.read_3_u16()

			n_b := if is_cp { v.constant_pool[b] } else { regs[b] }
			regs[dest] = perform_infix(op, regs[a], n_b)!
		} else if op == .load {
			dest, src := p.read_2_u16()
			n_src := if is_cp { v.constant_pool[src] } else { regs[src] }

			regs[dest] = n_src
		} else if op == .index {
			dest, src, index := p.read_3_u16()
			
			lhs := if is_cp {
				v.constant_pool[index]
			} else {
				regs[index]
			}
			if lhs !is VStr {
				return error('indexing[] by anything other than a \'string\' is not implemented')
			}
			index_val := lhs as VStr

			if src == u16_max {
				regs[dest] = env.get(index_val)
			} else {
				rval := regs[src]
				if rval !is VTable {
					return error('cannot index values that are not tables')
				}

				regs[dest] = (rval as VTable)[index_val] or { panic("unreachable") }
			}
		} else {
			panic("VM.execute: operator `${op}` unimplemented")
		}

		/* .load, .store {
			dest, src := p.read_2_u16()

			if is_cp {
				println('R${dest} = ${op} ${v.constant_pool[src]}')
			} else {
				println('R${dest} = ${op} R${src}')
			}
		} */
	}
	
	return regs
}