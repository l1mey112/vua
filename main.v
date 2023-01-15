import internals

fn main() {
	mut l := internals.new_parser('function hello() return 20 + 20 > 5 end')

	for {
		mut t := l.get()
		if t.kind == .eof {
			break
		}
		println(t)
	}
}