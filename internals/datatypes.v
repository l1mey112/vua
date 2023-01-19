module internals

/* [heap]
pub struct VTable {
__global:
	val VValue
} */

pub type VTable = map[string]VValue
pub struct VNil {}
pub type VNum   = i64
pub type VStr   = string
pub type VValue = VTable | VStr | VNum | VNil

fn new_vtable() VTable {
	return map[string]VValue{}
}

pub struct Enviroment {
mut:
	global VTable
	stack []VTable
}

pub fn (mut env Enviroment) assign_global(k string, v VValue) {
	env.global[k] = v
}

pub fn (mut env Enviroment) get(name string) VValue {
	mut idx := env.stack.len
	if idx != 0 {
		for {
			idx--
			if v := env.stack[idx][name] {
				return v
			}

			if idx == 0 { break }
		}
	}

	return env.global[name] or {
		VNil{}
	}
}

fn (typ VValue) vvalue_to_str() string {
	return match typ {
		VNum { "${typ}" }
		VNil  { "nil" }
		VStr { "'${typ}'" }
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