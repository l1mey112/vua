module internals

/* enum Type as u8 {
	@nil
	err
	bool
	number
	string
	function
	table
} */

enum Opcode as u8 {
	add      // R + R
	sub      // R - R
	mul      // R * R
	div      // R / R
	mod      // R % R
}

struct Inst {
	op  Opcode
	val u16
}

/* struct Err {}
struct Nil {}
struct Function {}

type Table = map[Some]Value
type None = Nil | Err
type Some =
	| bool
	| i64
	| Table
	| Function
	| string
type Value = Some | None */

/* type Value = i64 | bool | string

struct VM {
	sp   int
	r    []Value
} */