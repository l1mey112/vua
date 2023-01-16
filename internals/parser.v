module internals

pub struct Compiler {
mut:
	l        Lexer
	tok      Token
	peek     Token
	vstack   []&Cval
	vreg     int
	vreg_cap int
	lbl      int
}

pub fn new_compiler(src string) Compiler {
	mut p := Compiler {
		l: Lexer{ src: src }
	}
	p.next()
	p.next()
	return p
}

fn (mut p Compiler) next() {
	p.tok = p.peek
	p.peek = p.l.get()
}

type Creg   = int
type Cnum   = i64
type Cident = string
type Ctype  = Creg | Cnum | Cident

/* fn (typ Ctype) str() string {
	return match typ {
		Creg   { "R${typ}" }
		Cnum   { "${typ}" }
		Cident { "'${typ}'" }
	}
} */

[heap]
struct Cval {
	v    Ctype
mut:
	next &Cval = unsafe { nil }
}

fn (path &Cval) next() ?&Cval {
	if isnil(path.next) {
		return none
	}
	return path.next
}

fn (mut path Cval) append(to_append &Cval) {
	if isnil(path.next) {
		path.next = to_append
		return
	}

	path.append(to_append)
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

// TODO: a more sophisticated algorithm
fn (mut p Compiler) reg_alloc() Creg {
	v := p.vreg
	p.vreg++
	if p.vreg > p.vreg_cap {
		p.vreg_cap = p.vreg
	}
	return Creg(v)
}

// TODO: a more sophisticated algorithm
fn (mut p Compiler) reg_free(r Creg) {
	if p.vreg == r + 1 {
		p.vreg = r
	}
}

fn (mut p Compiler) unwrap_index_cval(curr &Cval, reg Creg) {
	if isnil(curr) {
		return
	}
	p.unwrap_index_cval(curr.next, reg)

	match curr.v {
		Cnum   { println("R${reg} = index R${reg}[${curr.v}]")   }
		Cident { println("R${reg} = index R${reg}['${curr.v}']") }
		Creg   { println("R${reg} = index R${reg}[R${curr.v}]")  }
	}
}

pub fn (mut p Compiler) flush() {
	for p.vstack.len > 0 {
		p.unwrap_pop_cval()
	}
}

fn (mut p Compiler) unwrap_cval(curr &Cval, reg Creg) Creg {
	match curr.v {
		Cnum {
			println("R${reg} = load ${curr.v}")
		}
		Cident {
			println("R${reg} = index _env['${curr.v}']")
		}
		Creg {
			if curr.v != reg {
				println("R${reg} = R${curr.v}")
			}
		}
	}
	p.unwrap_index_cval(curr.next, reg)

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

pub fn (mut p Compiler) check_current(kind Kind, err string) {
	if p.tok.kind != kind {
		panic("check: ${err}")
	}
}

pub fn (mut p Compiler) check(kind Kind, err string) {
	p.check_current(kind, err)
	p.next()
}

pub fn (mut p Compiler) expr(precedence u8) {
	match p.tok.kind {
		.ident {
			p.vpush(Cident(p.tok.lit))
			p.next()
		}
		.number {
			p.vpush(Cnum(p.tok.lit.i64()))
			p.next()
		}
		.oparen {
			p.next()
			p.expr(0)
			p.check(.cparen, "expected closing `)` to close paren expression")
		}
		else {
			if p.tok.kind.is_prefix() {
				if p.tok.kind == .sub && p.peek.kind == .number {
					p.next()
					p.vpush(Cnum("-${p.tok.lit}".i64()))
					p.next()
				} else {
					opcode := if p.tok.kind == .sub {
						"neg"
					} else {
						p.tok.kind.str()
					}

					p.next()
					p.expr(u8(Precedence.prefix))
					
					lhs := p.unwrap_pop_cval()
					println("R${lhs} = ${opcode} R${lhs}")
					p.vpush(lhs)
				}
			} else {
				panic("unimplemented ${p.tok.kind}")
			}
		}
	}
	
	for precedence < p.tok.kind.precedence() {
		match p.tok.kind {
			.dot, .osbrace {
				mut curr := p.vpop()

				is_osbrace := p.tok.kind == .osbrace
				p.next()
				
				if is_osbrace {
					p.expr(0)
					p.check(.csbrace, "expected `]` to close index expression")

					mut rval := p.vpop()
					curr.append(rval)
				} else {
					p.check_current(.ident, 'expected identifier after `.` expression')
					rval := &Cval {
						v: Cident(p.tok.lit)
					}
					curr.append(rval)
					p.next()
				}

				p.vstack << curr
			}
			.inc, .dec {
				lhs := p.unwrap_pop_cval()

				reg := p.reg_alloc()
				if p.tok.kind == .add {
					println("R${reg} = add R${lhs}, 1")
				} else {
					println("R${reg} = add R${lhs}, 1")
				}
				println("store R${lhs}, R${reg}")
				p.reg_free(reg)
				p.next()

				p.vpush(lhs)
			}
			else {
				if p.tok.kind.is_infix() {
					op := p.tok.kind
					is_short_circuit := op in [.l_and, .l_or, .or_unwrap]
					prec := p.tok.kind.precedence()
					p.next()

					lhs := p.unwrap_pop_cval()
					
					mut lbl := p.lbl
					mut rhs := Creg(-1)
					if is_short_circuit {
						p.lbl++
						if op != .or_unwrap {
							typ := if op == .l_and { "false" } else { "true" }
							println("cjmp R${lhs}, ${typ}, .LC${lbl}")
						} else {
							println("unwrap R${lhs}, .LC${lbl}")
						}
						
						if op in [.l_or, .or_unwrap] {
							p.expr(prec)
							p.unwrap_pop_cval_to(lbl)
						}
					}
					if op !in [.l_or, .or_unwrap] {
						p.expr(prec)
						rhs = p.unwrap_pop_cval()
					}		

					if op.is_assign() {
						mut n_rhs := rhs
						if op != .assign {
							reg := p.reg_alloc()
							println("R${reg} = ${op.to_assign_arith()} R${lhs}, R${rhs}")

							p.reg_free(reg)
							n_rhs = reg
						}
						println("store R${lhs}, R${n_rhs}")						
					} else if op !in [.l_or, .or_unwrap] {
						println("R${lhs} = ${op} R${lhs}, R${rhs}")
					}

					if is_short_circuit {
						println(".LC${lbl}:")
					}

					p.vpush(lhs)
				} else {
					break
				}
			}
		}
	}
}