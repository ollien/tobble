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
  |> string.join("")
  |> birdie.snap("3x3 fixed width table from iterator")
}
