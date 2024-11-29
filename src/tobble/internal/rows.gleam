import gleam/list
import gleam/result

/// Rows represents the rows of a table.
/// Definitionally, all lists MUST be of equal length.
pub opaque type Rows(a) {
  Rows(List(List(a)))
}

pub type RowsError {
  InconsistentLengthsError(expected: Int, got: Int)
}

type NonEmptyList(a) {
  NonEmptyList(head: a, rest: List(a))
}

pub fn from_lists(lists: List(List(a))) -> Result(Rows(a), RowsError) {
  lists
  |> equal_lengths()
  |> result.map(fn(_nil) { Rows(lists) })
}

pub fn to_lists(rows: Rows(a)) -> List(List(a)) {
  let Rows(lists) = rows
  lists
}

// Get the number of columns in this structure
pub fn columns(rows: Rows(a)) -> Int {
  let Rows(lists) = rows
  case lists {
    [] -> 0
    [first_list, ..] -> list.length(first_list)
  }
}

pub fn pop_row(rows: Rows(a)) -> Result(#(List(a), Rows(a)), Nil) {
  case rows {
    Rows([]) -> Error(Nil)
    Rows([head, ..rest]) -> {
      Ok(#(head, Rows(rest)))
    }
  }
}

/// Fold each row's values into one. The accumulator is per-row, so it is reset on each row.
pub fn rowwise_fold(
  over rows: Rows(a),
  from initial_value: b,
  with folder: fn(b, a) -> b,
) -> List(b) {
  map_rows(rows, fn(row) {
    list.fold(over: row, from: initial_value, with: folder)
  })
}

// Apply a function to each row, and then return the row's elements as a list
pub fn map_rows(over rows: Rows(a), apply func: fn(List(a)) -> b) -> List(b) {
  let Rows(lists) = rows
  list.map(lists, func)
}

// Apply a function to each element in the structure
pub fn map(over rows: Rows(a), apply func: fn(a) -> b) -> Rows(b) {
  map_rows(rows, fn(row) { list.map(row, func) })
  |> Rows()
}

/// Fold each column's values into one. The accumulator is per-row, so it is reset on each column.
pub fn columnwise_fold(
  over rows: Rows(a),
  from initial_value: b,
  with folder: fn(b, a) -> b,
) -> List(b) {
  rows
  |> transpose()
  |> rowwise_fold(from: initial_value, with: folder)
}

fn transpose(rows: Rows(a)) -> Rows(a) {
  let Rows(lists) = rows
  case lists {
    [] -> rows
    [head, ..rest] -> {
      let non_empty = NonEmptyList(head:, rest:)
      // The precondition of do_transpose holds for the Rows type
      Rows(do_transpose(non_empty, []))
    }
  }
}

// It is a precondition of this function that lists are of equal length, otherwise
// we may get incorrect results or even panic
fn do_transpose(
  lists: NonEmptyList(List(a)),
  acc: List(List(a)),
) -> List(List(a)) {
  case lists.head {
    [] -> list.reverse(acc)

    _head_list -> {
      let row = [must_first(lists.head), ..list.map(lists.rest, must_first)]

      let all_rests =
        NonEmptyList(
          head: must_rest(lists.head),
          rest: list.map(lists.rest, must_rest),
        )

      do_transpose(all_rests, [row, ..acc])
    }
  }
}

fn must_first(list: List(a)) -> a {
  let assert [head, ..] = list
  head
}

fn must_rest(list: List(a)) -> List(a) {
  let assert [_head, ..rest] = list
  rest
}

fn equal_lengths(lists: List(List(a))) -> Result(Nil, RowsError) {
  case lists {
    [] -> Ok(Nil)
    [_list] -> Ok(Nil)
    [list, ..rest] -> {
      let length = list.length(list)
      do_equal_lengths_check(length, rest)
    }
  }
}

fn do_equal_lengths_check(
  last_length: Int,
  lists: List(List(a)),
) -> Result(Nil, RowsError) {
  case lists {
    [] -> Ok(Nil)
    [list] -> {
      let got_length = list.length(list)

      case got_length == last_length {
        True -> Ok(Nil)
        False ->
          Error(InconsistentLengthsError(got: got_length, expected: last_length))
      }
    }
    [list, ..rest] -> {
      let length = list.length(list)
      case length == last_length {
        False ->
          Error(InconsistentLengthsError(got: length, expected: last_length))
        // We want this to be tail recursive, so we  cannot merge this with the similar check above
        True -> do_equal_lengths_check(length, rest)
      }
    }
  }
}
