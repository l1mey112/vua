module lexer

pub enum Kind {
	ident     // hello
	number    // 1999 199.9
	str       // 'hello'

	oparen    // (
	cparen    // )
	obrace    // {
	cbrace    // }
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
	b_not     // ~
	b_xor     // ^
	range     // ..
	range_inc // ..=
	or_unwrap // or
	dot       // .

	function  // function
	end       // end
	ret       // return

	eof
}