module internals

pub struct Parser {
mut:
	l     Lexer
	tok   Token
	peek  Token
}

pub fn new_parser(src string) Parser {
	mut p := Parser {
		l: Lexer{ src: src }
	}
	p.next()
	p.next()
	return p
}

fn (mut p Parser) next() {
	p.tok = p.peek
	p.peek = p.l.get()
}

fn (mut p Parser) expr(precedence u8) {
	match p.tok.kind {
		.ident {
			println('ident ${p.tok.lit}')
			p.next()
		}
		.number {
			println('number ${p.tok.lit}')
			p.next()
		}
		.sub {
			if p.peek.kind == .number {
				println('number -${p.peek.lit}')
				p.next()
				p.next()
			} else {
				println('prefix expr')
				p.expr(u8(Precedence.prefix))
			}
		}
		else {
			panic("unimplemented ${p.tok.kind}")
		}
	}
	
	for precedence < p.tok.kind.precedence() {
		match p.tok.kind {
			.inc, .dec {
				println('postfix expr ${p.tok.kind}')
				p.next()
			}
			else {
				panic("unimplemented ${p.tok.kind}")
			}
		}
	}
}