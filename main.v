import internals

fn main() {
	// mut p := internals.new_parser('function hello() return 20 + 20 > 5 end')
	
	src := 'path.to[in_var].hello + 2'

	println("--- `${src}`")

	mut p := internals.new_compiler(src)

	p.expr(0)
}