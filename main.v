import internals

fn main() {
	// mut p := internals.new_parser('function hello() return 20 + 20 > 5 end')
	
	// src := 'path.to[in_var].hello + 2'
	// src := 'hello = -hello.name++ + 2'
	// src := 'hello = -2[2]'
	// src := 'hello = -(2)[2]'
	// src := '15 && 10 + 2'
	src := '10 or (22 + 2)'

	println("--- `${src}`")

	mut p := internals.new_compiler(src)

	p.expr(0)
	p.flush()
}