module internals

pub enum Kind {
	ident     // hello
	number    // 1999 199.9
	str       // 'hello'

	oparen    // (
	cparen    // )
	obrace    // {
	cbrace    // }
	osbrace   // [
	csbrace   // ]
	comma     // ,

	add       // +
	sub       // -
	mul       // *
	div       // /
	mod       // %
	inc       // ++
	dec       // --
	a_add     // +=
	a_sub     // -=
	a_mul     // *=
	a_div     // /=
	a_mod     // %=
	assign    // =
	eq        // ==
	neq       // !=
	gt        // >
	gte       // >=
	lt        // <
	lte       // <=
	l_and     // &&
	l_or      // ||
	l_not     // !
	b_and     // &
	b_or      // |
	b_xor     // ^
	b_not     // ~
	range     // ..
	range_inc // ..=
	or_unwrap // or
	dot       // .

	function  // function
	end       // end
	ret       // return
	do        // do
	/* nil       // nil
	true      // true
	false     // false
 */
	eof
}

// 2 | 2 == 2

enum Precedence as u8 {
	lowest
	assign   // = += -= *= /= %=
	range    // .. ..=
	l_or     // ||
	l_and    // &&
	eq       // == != < <= > >=
	b_or     // |
	b_xor    // ^
	b_and    // &
	sum      // + -
	factor   // * / %
	prefix   // -x !x
	postfix  // ++ --
	unwrap   // or
	call     // . x() x[]
}

fn (kind Kind) precedence() u8 {
	v := match kind {
		.assign, .a_add, .a_sub, .a_mul, .a_mod { Precedence.assign }
		.range, .range_inc { Precedence.range }
		.l_or { Precedence.l_or }
		.l_and { Precedence.l_and }
		.eq, .neq, .gt, .gte, .lt, .lte { Precedence.eq }
		.b_or { Precedence.b_or }
		.b_xor { Precedence.b_or }
		.b_and { Precedence.b_and }
		.add, .sub { Precedence.sum }
		.mul, .div, .mod { Precedence.factor }
		.inc, .dec { Precedence.postfix }		
		.or_unwrap { Precedence.unwrap }
		.dot, .osbrace, .oparen { Precedence.call }
		else { Precedence.lowest }
	}
	
	return u8(v)
}

fn (kind Kind) is_assign() bool {
	return kind in [
		.a_add,
		.a_sub,
		.a_mul,
		.a_div,
		.a_mod,
		.assign,
	]
}

fn (kind Kind) to_assign_arith() Kind {
	return match kind {
		.a_add { .add }
		.a_sub { .sub }
		.a_mul { .mul }
		.a_div { .div }
		.a_mod { .mod }
		else { panic("unreachable") }
	}
}

fn (kind Kind) is_prefix() bool {
	return kind in [
		.sub,
		.l_not,
		.b_not,
	]
}

fn (kind Kind) is_infix() bool {
	return kind in [
		.add,
		.sub,
		.mul,
		.div,
		.mod,
		.a_add,
		.a_sub,
		.a_mul,
		.a_div,
		.a_mod,
		.assign,
		.eq,
		.neq,
		.gt,
		.gte,
		.lt,
		.lte,
		.l_and,
		.l_or,
		.l_not,
		.b_and,
		.b_or,
		.b_xor,
		.range,
		.range_inc,
		.dot,
		.or_unwrap,
	]
}