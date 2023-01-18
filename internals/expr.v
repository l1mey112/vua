module internals

pub fn (mut p Compiler) expr(precedence u8)! {
	size_start := p.vstack.len

	match p.tok.kind {
		.ident {
			p.vpush(Cident(p.tok.lit))
			p.next()!
		}
		.number {
			p.vpush(Cnum(p.tok.lit.i64()))
			p.next()!
		}
		.oparen {
			p.next()!
			p.expr(0)!
			p.check(.cparen, "expected closing `)` to close paren expression")!
		}
		else {
			if p.tok.kind.is_prefix() {
				if p.tok.kind == .sub && p.peek.kind == .number {
					p.next()!
					p.vpush(Cnum("-${p.tok.lit}".i64()))
					p.next()!
				} else {
					opcode := p.tok.kind.unary_to_opcode()

					p.next()!
					p.expr(u8(Precedence.prefix))!
					
					lhs := p.unwrap_pop_cval()
					p.vm.encode_unary(opcode, lhs, Cval{v: Creg(lhs)})
					p.vpush(lhs)
				}
			} else {
				estr := if p.tok.kind != .eof {
					"unexpected `${p.tok.kind}`"
				} else {
					"unexpected end of file"
				}
				return error(p.error_str(p.tok, estr))
			}
		}
	}
	
	for precedence < p.tok.kind.precedence() {
		match p.tok.kind {
			.dot, .osbrace {
				if p.prev.loc.line_nr != p.tok.loc.line_nr {
					break
				}
				mut curr := p.vpop()

				is_osbrace := p.tok.kind == .osbrace
				p.next()!
				
				if is_osbrace {
					p.expr(0)!
					p.check(.csbrace, "expected `]` to close table index")!

					curr = &Cval {
						v: p.unwrap_pop_cval()
						next: curr
					}
				} else {
					p.check_current(.ident, 'expected identifier after `.` expression')!
					curr = &Cval {
						v: Cident(p.tok.lit)
						next: curr
					}
					p.next()!
				}

				p.vstack << curr
			}
			.oparen {
				if p.prev.loc.line_nr != p.tok.loc.line_nr {
					break
				}
				func := p.unwrap_pop_cval()
				mut args := []Creg{cap: 2}

				p.next()!
				for p.tok.kind != .cparen {
					p.expr(0)!
					args << p.unwrap_pop_cval()
					if p.tok.kind != .cparen {
						p.check(.comma, 'use `,` to denote each argument in funciton call')!
					}
				}
				p.check(.cparen, 'expected `)` to close function call')!

				$if !prod {
					if args.len > 0 {
						mut curr := args[0]
						for v in args[1..] {
							assert curr + 1 == v
							curr = v
						}
					}
				}

				p.vpush(func)
				arg_str := if args.len != 0 { 'R${args[0]}..R${args.last()}' } else { '' }
				p.writeln('R${func} = R${func}(${arg_str})')
			}
			.inc, .dec {
				lhs := p.unwrap_pop_cval()

				reg := p.reg_alloc()
				if p.tok.kind == .add {
					p.writeln("R${reg} = add R${lhs}, 1")
				} else {
					p.writeln("R${reg} = add R${lhs}, 1")
				}
				p.writeln("store R${lhs}, R${reg}")
				p.reg_free(reg)
				p.next()!

				p.vpush(lhs)
			}
			else {
				if p.tok.kind.is_infix() {
					op := p.tok.kind
					
					is_short_circuit := op in [.l_and, .l_or, .or_unwrap]
					if op == .or_unwrap {
						return error(p.error_str(p.tok, "`or` unwrapping or the `err` type are not implemented, they are WIP"))
					}

					prec := p.tok.kind.precedence()
					p.next()!

					lhs := p.unwrap_pop_cval()
					
					mut lbl := p.lbl
					mut rhs := Creg(-1)
					if is_short_circuit {
						p.lbl++
						if op != .or_unwrap {
							typ := if op == .l_and { "false" } else { "true" }
							p.writeln("cjmp R${lhs}, ${typ}, .LC${lbl}")
						} else {
							p.writeln("unwrap R${lhs}, .LC${lbl}")
						}
						
						if op in [.l_or, .or_unwrap] {
							p.expr(prec)!
							p.unwrap_pop_cval_to(lbl)
						}
					}
					if op !in [.l_or, .or_unwrap] {
						p.expr(prec)!
						rhs = p.unwrap_pop_cval()
					}

					if op.is_assign() {
						mut n_rhs := rhs
						if op != .assign {
							reg := p.reg_alloc()
							opcode := op.to_assign_arith().infix_to_opcode()
							p.vm.encode_infix(opcode, reg, lhs, Cval{v: Creg(rhs)})

							p.reg_free(reg)
							n_rhs = reg
						}

						p.writeln("store R${lhs}, R${n_rhs}")
					} else if op !in [.l_or, .or_unwrap] {
						opcode := op.infix_to_opcode()
						p.vm.encode_infix(opcode, lhs, lhs, Cval{v: Creg(rhs)})
					}

					if is_short_circuit {
						p.writeln(".LC${lbl}:")
					}

					p.vpush(lhs)
				} else {
					break
				}
			}
		}
	}

	assert p.vstack.len == size_start + 1
}