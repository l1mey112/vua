module internals

struct Token {
pub:
	loc  Loc
	kind Kind
	lit  string
}

struct Loc {
	column int
	line_nr int
	len int
	pos int
}

pub struct Lexer {
mut:
	src string
	pos int
	last_nl_pos int
	line_nr int
}

pub fn new_lexer_with_string(src string) Lexer {
	return Lexer {
		src: src
	}
}

fn is_id(ch u8) bool { return (ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`) || ch == `_` }

fn (l Lexer) loc(len int) Loc {
	comp_col := l.pos - l.last_nl_pos - len
	return Loc {
		column: comp_col
		line_nr: l.line_nr
		len: len
		pos: l.pos - len
	}
}

pub fn (mut l Lexer) get()! Token {
	for l.pos < l.src.len {
		mut ch := l.src[l.pos]
		
		if ch.is_space() {
			l.pos++
			if ch == `\n` {
				l.last_nl_pos = l.pos
				l.line_nr++
			}
			continue
		}

		if is_id(ch) {
			start := l.pos
			
			for l.pos < l.src.len {
				c := l.src[l.pos]
				if (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || (c >= `0` && c <= `9`) || c == `_` {
					l.pos++
					continue
				}
				break
			}

			ident := l.src[start..l.pos]

			op := match ident {
				'or'       { Kind.or_unwrap }
				'function' { Kind.function  }
				'end'      { Kind.end       }
				'return'   { Kind.ret       }
				'do'       { Kind.do        }
				else       { Kind.ident     }
			}
			return Token {
				loc: l.loc(ident.len)
				kind: op
				lit: ident
			}
		} else if ch.is_digit() {
			start := l.pos

			for l.pos < l.src.len {
				c := l.src[l.pos]
				if !c.is_digit() {
					if is_id(c) {
						return error("unsuitable character in integer")
					}
					break
				}
				l.pos++
			}

			lit := l.src[start..l.pos]

			return Token {
				loc: l.loc(lit.len)
				kind: .number
				lit: lit
			}
		} else {
			start := l.pos
			l1 := l.src[l.pos + 1] or { 0 }
			l2 := l.src[l.pos + 2] or { 0 }

			if ch == `/` && l1 == `/` {
				for {
					l.pos++
					if l.pos >= l.src.len || l.src[l.pos] == `\n` {
						break
					}
				}
				l.pos++
				continue
			}

			l.pos++

			op := match ch {
				`(` { Kind.oparen  }
				`)` { Kind.cparen  }
				`{` { Kind.obrace  }
				`}` { Kind.cbrace  }
				`[` { Kind.osbrace }
				`]` { Kind.csbrace }
				`,` { Kind.comma   }
				`+` { if l1 == `+` { l.pos++ Kind.inc   } else if l1 == `=` { l.pos++ Kind.a_add } else { Kind.add } }
				`-` { if l1 == `-` { l.pos++ Kind.dec   } else { Kind.sub    } }
				`*` { if l1 == `=` { l.pos++ Kind.a_mul } else { Kind.mul    } }
				`/` { if l1 == `=` { l.pos++ Kind.a_div } else { Kind.div    } }
				`%` { if l1 == `=` { l.pos++ Kind.a_mod } else { Kind.mod    } }
				`=` { if l1 == `=` { l.pos++ Kind.eq    } else { Kind.assign } }
				`!` { if l1 == `=` { l.pos++ Kind.neq   } else { Kind.l_not  } }
				`>` { if l1 == `=` { l.pos++ Kind.gte   } else { Kind.gt     } }
				`<` { if l1 == `=` { l.pos++ Kind.lte   } else { Kind.lt     } }
				`&` { if l1 == `&` { l.pos++ Kind.l_and } else { Kind.l_and  } }
				`|` { if l1 == `|` { l.pos++ Kind.l_or  } else { Kind.b_or   } }
				`.` { if l1 == `.` { l.pos++ if l2 == `=` { l.pos++ Kind.range_inc } else { Kind.range } } else { Kind.dot } }
				`~` { Kind.b_not }
				`^` { Kind.b_xor }
				else {
					return error("unknown character ${ch.ascii_str()}")
				}
			}


			return Token {
				loc: l.loc(l.pos - start)
				kind: op
			}
		}
		// break
	}

	return Token {
		kind: .eof
	}
}