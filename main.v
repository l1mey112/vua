// import terisback.discordv as vd
import internals

fn main() {
	// mut p := internals.new_parser('function hello() return 20 + 20 > 5 end')
	
	// src := 'path.to[in_var].hello + 2' // THIS CREATES A STACK OVERFLOW
	// src := 'hello = -hello.name++ + 2'
	// src := 'hello = -2[2]'
	// src := 'hello = -(2)[2]'
	// src := '15 && 10 + 2'
	src := 'hello()'

	// println("--- `${src}`")

	mut p := internals.new_compiler(src)

	p.all() or { eprintln(err) exit(1) }
	print(p.code_ret)
}