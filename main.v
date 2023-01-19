import internals { VNum, Enviroment }

fn main() {
	// source code
	src := 'hello + 2'
	println('source code = `${src}`\n')

	// create a new compiler and compile bytecode
	mut p := internals.new_compiler(src)
	p.compile() or { eprintln(err) exit(1) }

	// disassemble bytecode and print it out
	str := p.vm.disassemble()
	println(str)

	// create a new 'global execution enviroment'
	// global variables can be assigned here
	mut env := Enviroment{}
	// create a global variable 'hello' with the integer value 120
	env.assign_global('hello', VNum(120))
	
	// execute the virtual machine with allotted registers and the enviroment
	state := p.vm.execute(p.vreg_cap, mut env) or { eprintln(err) exit(1) }

	// print the value of `R0`
	println(state[0])
}