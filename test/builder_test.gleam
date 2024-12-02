import gleeunit
import gleeunit/should
import tobble/internal/builder
import tobble/internal/rows

pub fn main() {
  gleeunit.main()
}

pub fn can_build_table_test() {
  builder.new()
  |> builder.add_row(["1", "2", "3"])
  |> builder.add_row(["4", "5", "6"])
  |> builder.add_row(["7", "8", "9"])
  |> builder.to_result()
  |> should.be_ok()
}

pub fn built_table_has_no_title_by_default_test() {
  let rows = [["1", "2", "3"], ["4", "5", "6"]]
  let builder = builder.from_list(rows)

  let built_table =
    builder
    |> builder.to_result()
    |> should.be_ok()

  built_table.title
  |> should.be_none()
}

pub fn can_add_tile_to_table_test() {
  let rows = [["1", "2", "3"], ["4", "5", "6"]]
  let builder = builder.from_list(rows)

  let built_table =
    builder
    |> builder.set_title("Wobbles")
    |> builder.to_result()
    |> should.be_ok()

  built_table.title
  |> should.be_some()
  |> should.equal("Wobbles")
}

pub fn cannot_build_table_with_inconsistent_column_counts_test() {
  builder.new()
  |> builder.add_row(["1", "2", "3"])
  |> builder.add_row(["4", "5"])
  |> builder.add_row(["7", "8", "9"])
  |> builder.to_result()
  |> should.be_error()
  |> should.equal(builder.InconsistentColumnCountError(expected: 3, got: 2))
}

pub fn to_lists_returns_all_rows_test() {
  let rows = [["1", "2", "3"], ["4", "5", "6"]]
  let builder = builder.from_list(rows)

  let built_table =
    builder
    |> builder.to_result()
    |> should.be_ok()

  built_table.rows
  |> rows.to_lists()
  |> should.equal(rows)
}

pub fn cannot_build_empty_table_test() {
  builder.new()
  |> builder.to_result()
  |> should.be_error()
  |> should.equal(builder.EmptyTableError)
}

pub fn cannot_build_table_with_empty_title_test() {
  builder.new()
  |> builder.set_title("")
  |> builder.to_result()
  |> should.be_error()
  |> should.equal(builder.EmptyTitleError)
}
