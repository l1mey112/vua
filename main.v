import lexer

fn main() {
	mut l := lexer.new_lexer_with_string('function hello() return 20 + 20 > 5 end')

	for {
		mut t := l.get()
		if t.kind == .eof {
			break
		}
		println(t)
	}
}