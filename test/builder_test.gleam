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

pub fn cannot_build_table_with_inconsistent_column_counts_test() {
  builder.new()
  |> builder.add_row(["1", "2", "3"])
  |> builder.add_row(["4", "5"])
  |> builder.add_row(["7", "8", "9"])
  |> builder.to_result()
  |> should.be_error()
  |> should.equal(builder.InconsistentColumnCountError(expected: 3, got: 2))
}

pub fn to_result_returns_all_rows_test() {
  let rows = [["1", "2", "3"], ["4", "5", "6"]]
  let builder = builder.from_list(rows)

  builder
  |> builder.to_result()
  |> should.be_ok()
  |> rows.to_lists()
  |> should.equal(rows)
}
