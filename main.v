import internals { Creg, Cnum, Cval }

fn main() {
	// mut p := internals.new_parser('function hello() return 20 + 20 > 5 end')
	
	// src := 'path.to[in_var].hello + 2'
	// src := 'hello = -hello.name++ + 2'
	// src := 'hello = -2[2]'
	// src := 'hello = -(2)[2]'
	// src := '15 && 10 + 2'
	// src := 'hello or (2 + 2)'

	/* src := '10 + 15 * 2'
	println("--- `${src}`")

	mut p := internals.new_compiler(src)
	p.all() or { eprintln(err) exit(1) } */

	/* mut vm := internals.VM{}
	vm.encode_load(Creg(0), &Cval{v: Cnum(10)})
	vm.encode_load(Creg(1), &Cval{v: Cnum(15)})
	vm.encode_load(Creg(2), &Cval{v: Cnum(2)})
	vm.encode_infix(.mul, Creg(1), Creg(1), &Cval{v: Creg(2)})
	vm.encode_infix(.add, Creg(0), Creg(0), &Cval{v: Creg(1)})

	str := vm.disassemble()
	println(str)
	state := vm.execute(3) or { eprintln(err) exit(1) }

	println(state[0]) */

	src := '10 + 15 * 2'
	mut p := internals.new_compiler(src)

	p.compile() or { eprintln(err) exit(1) }

	str := p.vm.disassemble()
	println(str)
	state := p.vm.execute(p.vreg_cap) or { eprintln(err) exit(1) }

	println(state)
	println(state[0])
}