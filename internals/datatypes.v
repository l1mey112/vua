module internals

type VTableTyp = map[string]&VTable

struct Nil {}

[heap]
struct VTable {
	ptr VTableTyp
}

type VNum   = i64
type VValue = VNum | VTable | Nil

fn (typ VValue) vvalue_to_str() string {
	return match typ {
		VNum { "${typ}" }
		Nil  { "nil" }
		else { typ.str() }
	}
}

fn (typ VValue) str() string {
	return typ.vvalue_to_str()
}

fn (typ VValue) number_like() !VNum {
	return match typ {
		VNum { typ }
		else {
			return error("cannot cast type `${typeof(typ).name}` to number")
		}
	}
}

fn perform_infix(op Opcode, _a VValue, _b VValue) !VValue {
	a := _a.number_like()!
	b := _b.number_like()!

	v := match op {
		.add { a + b }
		.sub { a - b }
		.mul { a * b }
		.div { a / b }
		.mod { a % b }
		.bor { a | b }
		.and { a & b }
		.xor { a ^ b }
		else { panic("unreachable") }
	}
	
	return VValue(VNum(v))
}