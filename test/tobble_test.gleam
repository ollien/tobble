import birdie
import gleam/string
import gleam/yielder
import gleeunit
import gleeunit/should
import tobble
import tobble/internal/builder

pub fn main() {
  gleeunit.main()
}

pub fn build_builds_acceptable_builder_test() {
  let rows = [["1", "2", "3"], ["4", "5", "6"]]
  let builder = builder.from_list(rows)

  tobble.build(builder)
  |> should.be_ok()
  |> tobble.to_list()
  |> should.equal(rows)
}

pub fn build_does_not_build_failed_builder_test() {
  let error = builder.InconsistentColumnCountError(expected: 5, got: 2)

  builder.from_error(error)
  |> tobble.build()
  |> should.be_error()
  |> should.equal(tobble.InconsistentColumnCountError(expected: 5, got: 2))
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
    tobble.RenderLineType(tobble.BoxDrawingCharsLineType),
  ])
  |> birdie.snap("3x3 variable width table, box drawing chars")
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
  |> tobble.render_with_options(options: [tobble.RenderTableWidth(32)])
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
  |> tobble.render_with_options(options: [tobble.RenderTableWidth(3)])
  |> birdie.snap("3x3 scaled width table, desired width too small")
}

pub fn snapshot_3x3_column_width_grown_test() {
  tobble.builder()
  |> tobble.add_row(["1", "2", "3"])
  |> tobble.add_row(["4", "5", "6"])
  |> tobble.add_row(["7", "8", "9"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options(options: [tobble.RenderColumnWidth(10)])
  |> birdie.snap("3x3 with 10 wide columns")
}

pub fn snapshot_3x3_column_width_grown_shrunk_test() {
  tobble.builder()
  |> tobble.add_row(["1", "22", "333"])
  |> tobble.add_row(["4444", "55555", "666666"])
  |> tobble.add_row(["7777777", "88888888", "999999999"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options(options: [tobble.RenderColumnWidth(3)])
  |> birdie.snap("3x3 with 3 wide columns")
}

pub fn snapshot_3x3_column_width_minimum_width_enforced_test() {
  tobble.builder()
  |> tobble.add_row(["1", "22", "333"])
  |> tobble.add_row(["4444", "55555", "666666"])
  |> tobble.add_row(["7777777", "88888888", "999999999"])
  |> tobble.build()
  |> should.be_ok()
  |> tobble.render_with_options(options: [tobble.RenderColumnWidth(0)])
  |> birdie.snap("3x3 with minimum width enforced")
}
