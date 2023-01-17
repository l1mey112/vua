module internals

import math as m
import strings

const line_offset = 2
const tab_spaces = '    '

fn (mut p Compiler) error_str(tok Token, msg string) string {
	mut err_out := strings.new_builder(120)
	defer {
		unsafe { err_out.free() }
	}

	pos := tok.loc

	err_out.writeln('<src>${pos.line_nr + 1}:${pos.column + 1}: error: ' + msg)
	err_out.write_u8(`\n`)
	
	lines := p.l.src.split_into_lines()

	bline := m.max(0, pos.line_nr - line_offset)
	aline := m.max(0, m.min(lines.len - 1, pos.line_nr + line_offset))
	for iline := bline ; iline <= aline ; iline++ {
		sline := lines[iline]
		start_column := m.max(0, m.min(pos.column, sline.len))
		end_column := m.max(0, m.min(pos.column + m.max(0, pos.len), sline.len))

		/* cline := if iline == pos.line_nr {
			sline[..start_column] + term.red(sline[start_column..end_column]) + sline[end_column..]
		} else {
			sline
		} */
		cline := sline

		err_out.writeln('${iline + 1:3d} | ' + cline.replace('\t', tab_spaces))
		if iline == pos.line_nr {
			mut pointerline_builder := strings.new_builder(sline.len)
			for i := 0; i < start_column; {
				if sline[i].is_space() {
					pointerline_builder.write_u8(sline[i])
					i++
				} else {
					char_len := utf8_char_len(sline[i])
					spaces := ' '.repeat(utf8_str_visible_length(sline[i..i + char_len]))
					pointerline_builder.write_string(spaces)
					i += char_len
				}
			}
			underline_len := utf8_str_visible_length(sline[start_column..end_column])
			underline := if underline_len > 1 { '~'.repeat(underline_len) } else { '^' }
			pointerline_builder.write_string(underline)
			err_out.writeln('    | ' + pointerline_builder.str().replace('\t', tab_spaces))
		}
	}

	return err_out.str()
}