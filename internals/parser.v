module internals

type Creg   = int
type Cident = string
type Cnum   = i64
type Cval   = Creg | Cnum | Cident

pub struct Compiler {
mut:
	l        Lexer
	tok      Token
	peek     Token
	vstack   []Cval
	vreg     int
	vreg_cap int
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

fn (mut p Compiler) reg_alloc() Creg {
	v := p.vreg
	p.vreg++
	if p.vreg > p.vreg_cap {
		p.vreg_cap = p.vreg
	}
	return Creg(v)
}

fn (mut p Compiler) deref_pop_cval() Creg {
	v := p.vstack.pop()

	match v {
		Creg {
			return v
		}
		Cnum {
			r := p.reg_alloc()
			println('R${r} = load ${v}')
			return r
		}
		Cident {
			r := p.reg_alloc()
			println("R${r} = _env['${v}']")
			return r
		}
	}
}

fn (mut p Compiler) vpop() Cval {
	v := p.vstack.pop()
	if p.vstack.len == 0 {
		// TODO: move this to the start of expr(0)?
		//       maybe not, since this is recursive
		//       move to root callsite?
		p.vreg = 0
	}
	return v
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
			p.vstack << Cident(p.tok.lit)
			p.next()
		}
		.number {
			p.vstack << Cnum(p.tok.lit.i64())
			p.next()
		}
		.sub {
			if p.peek.kind == .number {
				p.next()
				p.vstack << Cnum("-${p.tok.lit}".i64())
				p.next()
			} else {
				p.expr(u8(Precedence.prefix))
				// shift value
				// value()
			}
		}
		else {
			panic("unimplemented ${p.tok.kind}")
		}
	}
	
	for precedence < p.tok.kind.precedence() {
		match p.tok.kind {
			.dot, .osbrace {
				is_osbrace := p.tok.kind == .osbrace

				if p.vstack.last() is Cnum {
					panic("`.` or `[]` expression impossible in this context")
				}
				lval := p.deref_pop_cval()
				p.next()
				if is_osbrace {
					p.expr(0)
					p.check(.csbrace, "expected `]` to close index expression")

					rval := p.deref_pop_cval()
					println("R${lval} = R${lval}[R${rval}]")
				} else {
					for {
						p.check_current(.ident, 'expected identifier after `.` expression')
						println("R${lval} = R${lval}['${p.tok.lit}']")
						
						p.next()
						if p.tok.kind != .dot {
							break
						}
					}
				}
				p.vstack << lval
			}
			.inc, .dec {
				// p.check_lvalue()
				panic("unimplemented")
				// println('postfix expr ${p.tok.kind}')
				// p.next()
			}
			else {
				if p.tok.kind.is_infix() {
					op := p.tok.kind
					prec := p.tok.kind.precedence()
					p.next()
					p.expr(prec)
					
					b := p.deref_pop_cval()
					a := p.deref_pop_cval()
					println("R${b} = ${op} R${a}, R${b}")
					p.vstack << b
				} else {
					break
				}
			}
		}
	}
}