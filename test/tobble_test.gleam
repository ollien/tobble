import birdie
import gleam/string
import gleam/yielder
import gleeunit
import gleeunit/should
import tobble
import tobble/internal/builder
import tobble/table_render_opts

pub fn main() {
  gleeunit.main()
}

pub fn build_builds_acceptable_builder_test() {
  let rows = [["1", "2", "3"], ["4", "5", "6"]]
  let builder = builder.from_list(rows)

  tobble.build_with_internal(builder)
  |> should.be_ok()
  |> tobble.to_list()
  |> should.equal(rows)
}

pub fn build_does_not_build_failed_builder_test() {
  let error = builder.InconsistentColumnCountError(expected: 5, got: 2)

  builder.from_error(error)
  |> tobble.build_with_internal()
  |> should.be_error()
  |> should.equal(tobble.InconsistentColumnCountError(expected: 5, got: 2))
}

pub fn build_copies_title_from_builder_test() {
  let rows = [["1", "2", "3"], ["4", "5", "6"]]
  let builder =
    rows
    |> builder.from_list()
    |> builder.set_title("Numbers")

  tobble.build_with_internal(builder)
  |> should.be_ok()
  |> tobble.title()
  |> should.be_some()
  |> should.equal("Numbers")
}

pub fn title_is_empty_if_none_set_test() {
  let rows = [["1", "2", "3"], ["4", "5", "6"]]
  let builder = builder.from_list(rows)

  tobble.build_with_internal(builder)
  |> should.be_ok()
  |> tobble.title()
  |> should.be_none()
}

pub fn snapshot_3x3_fixed_width_test() {
  tobble.builder()
  |> tobble.add_row(["1", "2", "3"])
  |> tobble.add_row(["4", "5", "6"])
  |> tobble.add_row(["7", "8", "9"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render()
  |> birdie.snap("3x3 fixed width table")
}

pub fn snapshot_3x3_fixed_width_without_horizontal_rules_test() {
  tobble.builder()
  |> tobble.add_row(["1", "2", "3"])
  |> tobble.add_row(["4", "5", "6"])
  |> tobble.add_row(["7", "8", "9"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options(options: [
    table_render_opts.no_horizontal_rules(),
  ])
  |> birdie.snap("3x3 fixed width table without horizontal rules")
}

pub fn snapshot_3x3_fixed_width_with_horizontal_rules_on_every_row_test() {
  tobble.builder()
  |> tobble.add_row(["1", "2", "3"])
  |> tobble.add_row(["4", "5", "6"])
  |> tobble.add_row(["7", "8", "9"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options(options: [
    table_render_opts.horizontal_rules_after_every_row(),
  ])
  |> birdie.snap("3x3 fixed width table with horizontal rules on every row")
}

pub fn snapshot_3x3_variable_width_test() {
  tobble.builder()
  |> tobble.add_row(["", "Wibbles", "Wobbles"])
  |> tobble.add_row(["Rating", "Better", "Best"])
  |> tobble.add_row(["Alternative", "Foo", "Bar"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render()
  |> birdie.snap("3x3 variable width table")
}

pub fn snapshot_2x3_variable_width_with_wide_chars_test() {
  tobble.builder()
  |> tobble.add_row(["✅", "❌"])
  |> tobble.add_row(["Wibbles", "Foo"])
  |> tobble.add_row(["Wobbles", "Bar"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render()
  |> birdie.snap("3x3 variable width table with wide chars")
}

pub fn snapshot_3x3_variable_height_test() {
  tobble.builder()
  |> tobble.add_row(["1\n1", "2", "3"])
  |> tobble.add_row(["4", "5\n5", "6"])
  |> tobble.add_row(["7", "8", "9\n9"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render()
  |> birdie.snap("3x3 variable height table")
}

pub fn snapshot_3x3_variable_height_and_width_test() {
  tobble.builder()
  |> tobble.add_row(["Wobbles\nThen Wibbles", "Wibbles\nThen Wobbles"])
  |> tobble.add_row(["WobbleWobble\nWibble", "WibbleWibble\nWobble"])
  |> tobble.add_row(["Wibble", "Wobble"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render()
  |> birdie.snap("3x3 variable height and width table")
}

pub fn snapshot_3x3_variable_width_box_drawing_test() {
  tobble.builder()
  |> tobble.add_row(["", "Wibbles", "Wobbles"])
  |> tobble.add_row(["Rating", "Better", "Best"])
  |> tobble.add_row(["Alternative", "Foo", "Bar"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options([
    table_render_opts.line_type_box_drawing_characters(),
  ])
  |> birdie.snap("3x3 variable width table, box drawing chars")
}

pub fn snapshot_3x3_variable_width_box_drawing_with_rounded_corners_test() {
  tobble.builder()
  |> tobble.add_row(["", "Wibbles", "Wobbles"])
  |> tobble.add_row(["Rating", "Better", "Best"])
  |> tobble.add_row(["Alternative", "Foo", "Bar"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options([
    table_render_opts.line_type_rounded_corner_box_drawing_characters(),
  ])
  |> birdie.snap(
    "3x3 variable width table, box drawing chars with rounded corners",
  )
}

pub fn snapshot_3x3_variable_width_blank_line_type_test() {
  tobble.builder()
  |> tobble.add_row(["", "Wibbles", "Wobbles"])
  |> tobble.add_row(["Rating", "Better", "Best"])
  |> tobble.add_row(["Alternative", "Foo", "Bar"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options([table_render_opts.line_type_blank()])
  |> birdie.snap("3x3 variable width table, blank decorations")
}

pub fn snapshot_3x3_fixed_width_from_iterator_test() {
  tobble.builder()
  |> tobble.add_row(["1", "2", "3"])
  |> tobble.add_row(["4", "5", "6"])
  |> tobble.add_row(["7", "8", "9"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_iter(options: [])
  |> yielder.to_list()
  |> string.join("\n")
  |> birdie.snap("3x3 fixed width table from iterator")
}

pub fn snapshot_3x3_scaled_width_test() {
  tobble.builder()
  |> tobble.add_row(["#", "Phrase", "Usage"])
  |> tobble.add_row([
    "1", "The Quick Brown Fox Jumped Over The Lazy Dog",
    "Typing every character",
  ])
  |> tobble.add_row(["2", "Wibble", "An alternative to 'foo' in Gleam"])
  |> tobble.add_row(["3", "Wobble", "An alternative to 'bar' in Gleam"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options(options: [table_render_opts.table_width(32)])
  |> birdie.snap("3x3 scaled width table")
}

pub fn snapshot_3x3_scaled_width_too_small_gives_one_char_per_column_test() {
  tobble.builder()
  |> tobble.add_row(["#", "Phrase", "Usage"])
  |> tobble.add_row([
    "1", "The Quick Brown Fox Jumped Over The Lazy Dog",
    "Typing every character",
  ])
  |> tobble.add_row(["2", "Wibble", "An alternative to 'foo' in Gleam"])
  |> tobble.add_row(["3", "Wobble", "An alternative to 'bar' in Gleam"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options(options: [table_render_opts.table_width(3)])
  |> birdie.snap("3x3 scaled width table, desired width too small")
}

pub fn snapshot_3x3_column_width_grown_test() {
  tobble.builder()
  |> tobble.add_row(["1", "2", "3"])
  |> tobble.add_row(["4", "5", "6"])
  |> tobble.add_row(["7", "8", "9"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options(options: [table_render_opts.column_width(10)])
  |> birdie.snap("3x3 with 10 wide columns")
}

pub fn snapshot_3x3_column_width_grown_shrunk_test() {
  tobble.builder()
  |> tobble.add_row(["1", "22", "333"])
  |> tobble.add_row(["4444", "55555", "666666"])
  |> tobble.add_row(["7777777", "88888888", "999999999"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options(options: [table_render_opts.column_width(3)])
  |> birdie.snap("3x3 with 3 wide columns")
}

pub fn snapshot_3x3_column_width_minimum_width_enforced_test() {
  tobble.builder()
  |> tobble.add_row(["1", "22", "333"])
  |> tobble.add_row(["4444", "55555", "666666"])
  |> tobble.add_row(["7777777", "88888888", "999999999"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options(options: [table_render_opts.column_width(0)])
  |> birdie.snap("3x3 with minimum width enforced")
}

pub fn snapshot_3x3_column_width_minimum_width_enforced_when_one_less_than_decoration_width_test() {
  tobble.builder()
  |> tobble.add_row(["1", "2", "3"])
  |> tobble.add_row(["4", "5", "6"])
  |> tobble.add_row(["7", "8", "9"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options(options: [
    table_render_opts.table_width(12),
    table_render_opts.title_position_bottom(),
  ])
  |> birdie.snap(
    "3x3 with minimum width enforced when one less than decoration width",
  )
}

pub fn snapshot_3x3_table_with_implicit_top_title_test() {
  tobble.builder()
  |> tobble.add_row(["1", "2", "3"])
  |> tobble.add_row(["4", "5", "6"])
  |> tobble.add_row(["7", "8", "9"])
  |> tobble.set_title("Numbers")
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render()
  |> birdie.snap("3x3 with implicit short top title")
}

pub fn snapshot_3x3_hide_title_test() {
  tobble.builder()
  |> tobble.add_row(["1", "2", "3"])
  |> tobble.add_row(["4", "5", "6"])
  |> tobble.add_row(["7", "8", "9"])
  |> tobble.set_title("Numbers")
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options(options: [table_render_opts.hide_title()])
  |> birdie.snap("3x3 with hidden title")
}

pub fn snapshot_3x3_table_with_top_title_test() {
  tobble.builder()
  |> tobble.add_row(["1", "2", "3"])
  |> tobble.add_row(["4", "5", "6"])
  |> tobble.add_row(["7", "8", "9"])
  |> tobble.set_title("Numbers")
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options(options: [
    table_render_opts.title_position_top(),
  ])
  |> birdie.snap("3x3 with short top title")
}

pub fn snapshot_3x3_table_with_top_multiline_title_test() {
  tobble.builder()
  |> tobble.add_row(["1", "2", "3"])
  |> tobble.add_row(["4", "5", "6"])
  |> tobble.add_row(["7", "8", "9"])
  |> tobble.set_title("Some\nNumbers")
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options(options: [
    table_render_opts.title_position_top(),
  ])
  |> birdie.snap("3x3 with short top multiline title")
}

pub fn snapshot_3x3_table_with_top_title_longer_than_width_test() {
  tobble.builder()
  |> tobble.add_row(["1", "2", "3"])
  |> tobble.add_row(["4", "5", "6"])
  |> tobble.add_row(["7", "8", "9"])
  |> tobble.set_title("These are the first nine numbers")
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options(options: [
    table_render_opts.table_width(13),
    table_render_opts.title_position_top(),
  ])
  |> birdie.snap("3x3 with top title longer than width")
}

pub fn snapshot_3x3_table_with_bottom_title_test() {
  tobble.builder()
  |> tobble.add_row(["1", "2", "3"])
  |> tobble.add_row(["4", "5", "6"])
  |> tobble.add_row(["7", "8", "9"])
  |> tobble.set_title("Numbers")
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options(options: [
    table_render_opts.title_position_bottom(),
  ])
  |> birdie.snap("3x3 with short bottom title")
}

pub fn snapshot_3x3_table_with_bottom_multiline_title_test() {
  tobble.builder()
  |> tobble.add_row(["1", "2", "3"])
  |> tobble.add_row(["4", "5", "6"])
  |> tobble.add_row(["7", "8", "9"])
  |> tobble.set_title("Some\nNumbers")
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options(options: [
    table_render_opts.title_position_bottom(),
  ])
  |> birdie.snap("3x3 with short bottom multiline title")
}

pub fn snapshot_3x3_table_with_bottom_title_longer_than_width_test() {
  tobble.builder()
  |> tobble.add_row(["1", "2", "3"])
  |> tobble.add_row(["4", "5", "6"])
  |> tobble.add_row(["7", "8", "9"])
  |> tobble.set_title("These are the first nine numbers")
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options(options: [
    table_render_opts.table_width(13),
    table_render_opts.title_position_bottom(),
  ])
  |> birdie.snap("3x3 with bottom title longer than width")
}

pub fn snapshot_3x3_table_with_no_title_cannot_render_one_test() {
  tobble.builder()
  |> tobble.add_row(["1", "2", "3"])
  |> tobble.add_row(["4", "5", "6"])
  |> tobble.add_row(["7", "8", "9"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options(options: [
    table_render_opts.title_position_bottom(),
  ])
  |> birdie.snap("3x3 with no title cannot render one")
}

pub fn snapshot_3x3_table_limited_column_width_and_every_row_rules_test() {
  tobble.builder()
  |> tobble.add_row(["", "Output"])
  |> tobble.add_row(["Stage 1", "Wibble"])
  |> tobble.add_row(["Stage 2", "Wobble"])
  |> tobble.add_row(["Stage 3", "WibbleWobble"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options(options: [
    table_render_opts.column_width(6),
    table_render_opts.horizontal_rules_after_every_row(),
  ])
  |> birdie.snap("3x3 table, limited column width, and every row rules")
}
