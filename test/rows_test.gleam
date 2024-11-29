import gleam/list
import gleam/result
import gleeunit
import gleeunit/should
import tobble/internal/rows

pub fn main() {
  gleeunit.main()
}

pub fn from_lists_should_return_ok_for_equal_lengths_test() {
  rows.from_lists([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
  |> should.be_ok()
}

pub fn from_lists_should_return_inconsistent_lengths_error_test() {
  rows.from_lists([[1, 2, 3], [4, 5, 6], [7, 9]])
  |> should.be_error()
  |> should.equal(rows.InconsistentLengthsError(expected: 3, got: 2))
}

pub fn from_lists_should_equal_to_lists_output_test() {
  let lists = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

  rows.from_lists(lists)
  |> should.be_ok()
  |> rows.to_lists()
  |> should.equal(lists)
}

pub fn columns_should_return_the_number_of_elements_in_each_row_test() {
  let lists = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

  rows.from_lists(lists)
  |> should.be_ok()
  |> rows.columns()
  |> should.equal(3)
}

pub fn rowwise_fold_should_fold_across_rows_test() {
  let lists = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

  rows.from_lists(lists)
  |> should.be_ok()
  |> rows.rowwise_fold(from: 0, with: fn(acc, n) { acc + n })
  |> should.equal([1 + 2 + 3, 4 + 5 + 6, 7 + 8 + 9])
}

pub fn columnwise_fold_should_fold_across_columns_test() {
  let lists = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

  rows.from_lists(lists)
  |> should.be_ok()
  |> rows.columnwise_fold(from: 0, with: fn(acc, n) { acc + n })
  |> should.equal([1 + 4 + 7, 2 + 5 + 8, 3 + 6 + 9])
}

pub fn map_should_apply_the_function_to_all_elements_test() {
  let lists = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

  rows.from_lists(lists)
  |> should.be_ok()
  |> rows.map(fn(x) { x * 2 })
  |> rows.to_lists()
  |> should.equal([[2, 4, 6], [8, 10, 12], [14, 16, 18]])
}

pub fn map_rows_should_apply_the_function_to_each_row_test() {
  let lists = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

  rows.from_lists(lists)
  |> should.be_ok()
  |> rows.map_rows(fn(row) {
    row
    |> list.reduce(fn(a, b) { a + b })
    |> result.unwrap(or: 0)
  })
  |> should.equal([1 + 2 + 3, 4 + 5 + 6, 7 + 8 + 9])
}

pub fn flatmap_should_apply_the_function_to_each_row_test() {
  let lists = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
  rows.from_lists(lists)
  |> should.be_ok()
  |> rows.flatmap(fn(n) { [n, n] })
  |> should.be_ok()
  |> rows.to_lists()
  |> should.equal([
    [1, 2, 3],
    [1, 2, 3],
    [4, 5, 6],
    [4, 5, 6],
    [7, 8, 9],
    [7, 8, 9],
  ])
}

pub fn flatmap_should_return_an_error_if_apply_returns_different_lengths_in_a_row_test() {
  let lists = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
  rows.from_lists(lists)
  |> should.be_ok()
  |> rows.flatmap(fn(n) {
    case n % 2 {
      0 -> [n]
      _ -> [n, n]
    }
  })
  |> should.be_error()
  |> should.equal(rows.InconsistentLengthsError(expected: 2, got: 1))
}

pub fn flatmap_should_be_able_to_delete_rows_test() {
  let lists = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
  rows.from_lists(lists)
  |> should.be_ok()
  |> rows.flatmap(fn(_n) { [] })
  |> should.be_ok()
  |> rows.to_lists()
  |> should.equal([])
}
