module internals
import strings

pub struct Compiler {
mut:
	l        Lexer
	tok      Token
	peek     Token
	prev     Token
	vstack   []&Cval
	vreg     int
	vreg_cap int
	lbl      int
pub mut:
	code_ret strings.Builder = strings.new_builder(40)
}

pub fn new_compiler(src string) Compiler {
	mut p := Compiler {
		l: Lexer{ src: src }
	}
	return p
}

fn (mut p Compiler) next()! {
	p.prev = p.tok
	p.tok = p.peek
	p.peek = p.l.get()!
}

pub type Creg   = int
pub type Cnum   = i64
pub type Cident = string
pub type Ctype  = Creg | Cnum | Cident

fn (typ Ctype) ctype_to_str() string {
	return match typ {
		Creg   { "R${typ}" }
		Cnum   { "${typ}" }
		Cident { "'${typ}'" }
	}
}

fn (typ Ctype) str() string {
	return typ.ctype_to_str()
}

[heap]
pub struct Cval {
pub:
	v    Ctype
pub mut:
	next &Cval = unsafe { nil }
}

fn (mut p Compiler) vpush(v Ctype) {
	p.vstack << &Cval{v: v}
}

// TODO: replace `p.vstack.pop()` with `p.vpop()`
fn (mut p Compiler) vpop() &Cval {
	return p.vstack.pop()
}

fn (mut p Compiler) vtop() &Cval {
	return p.vstack.last()
}

fn (mut p Compiler) vclear() {
	p.vstack.clear()
	p.vreg = 0
}

fn (mut p Compiler) writeln(msg string) {
	p.code_ret.writeln(msg)
}

// TODO: a more sophisticated algorithm
fn (mut p Compiler) reg_alloc() Creg {
	v := p.vreg
	p.vreg++
	if p.vreg > p.vreg_cap {
		p.vreg_cap = p.vreg
	}
	assert p.vreg <= u16_max
	return Creg(v)
}

// TODO: a more sophisticated algorithm
fn (mut p Compiler) reg_free(r Creg) {
	if p.vreg == r + 1 {
		p.vreg = r
	}
}

fn (mut p Compiler) unwrap_index_cval(curr &Cval, reg Creg) {
	if !isnil(curr.next) {
		p.unwrap_index_cval(curr.next, reg)
		
		// index chain
		match curr.v {
			Cnum   { p.writeln("R${reg} = index R${reg}[${curr.v}]")   }
			Cident { p.writeln("R${reg} = index R${reg}['${curr.v}']") }
			Creg   { p.writeln("R${reg} = index R${reg}[R${curr.v}]")  }
		}
		return
	}

	// root value
	match curr.v {
		Cnum { p.writeln("R${reg} = load ${curr.v}") }
		Cident { p.writeln("R${reg} = index _scope['${curr.v}']") }
		Creg {
			if curr.v != reg {
				p.writeln("R${reg} = R${curr.v}")
			}
		}
	}
}

pub fn (mut p Compiler) flush() {
	for p.vstack.len > 0 {
		p.unwrap_pop_cval()
	}
}

fn (mut p Compiler) unwrap_cval(curr &Cval, reg Creg) Creg {
	p.unwrap_index_cval(curr, reg)

	return reg
}

fn (mut p Compiler) unwrap_pop_cval() Creg {
	curr := p.vpop()

	reg := match curr.v {
		Creg { curr.v }
		else { p.reg_alloc() }
	}

	p.unwrap_cval(curr, reg)
	return reg
}

fn (mut p Compiler) unwrap_pop_cval_to(v Creg) {
	p.unwrap_cval(p.vpop(), v)
}

fn (mut p Compiler) check_current(kind Kind, err string)! {
	if p.tok.kind != kind {
		return error(p.error_str(p.tok, err))
	}
}

fn (mut p Compiler) check(kind Kind, err string)! {
	p.check_current(kind, err)!
	p.next()!
}

pub fn (mut p Compiler) all()! {
	p.next()!
	p.next()!
	for p.tok.kind != .eof {
		p.stmt()!
	}
}

fn (mut p Compiler) expr0() !Creg {
	p.expr(0)!
	
	reg := p.unwrap_pop_cval()
	p.vreg = 0

	assert p.vstack.len == 0
	return reg
}

fn (mut p Compiler) stmt()! {
	match p.tok.kind {
		.do {
			p.writeln("push_scope")
			p.next()!
			for p.tok.kind != .end {
				p.stmt()!
			}
			p.check(.end, "expected `end` to close off `do` block")!
			p.writeln("pop_scope")
		}
		.ret {
			p.next()!
			reg := p.expr0()!
			p.writeln("return R${reg}")
		}
		else {
			if p.tok.kind == .function && p.peek.kind != .oparen {
				// not expr, a stmt
				// `function name() end`
				p.function()!
			} else {
				p.expr(0)!
				p.vclear()
			}
		}
	}
}

fn (mut p Compiler) function()! {
	return error(p.error_str(p.tok, "functions are not implemented, they are WIP"))
}