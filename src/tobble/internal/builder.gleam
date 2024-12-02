import gleam/list
import gleam/option
import gleam/result
import tobble/internal/rows

pub opaque type Builder {
  Builder(internals: BuilderInternals)
  FailedBuilder(error: BuilderError)
}

pub type BuiltTable {
  BuiltTable(rows: rows.Rows(String), title: option.Option(String))
}

type BuilderInternals {
  BuilderInternals(rows: List(UnbuiltRow), title: option.Option(String))
}

pub type BuilderError {
  InconsistentColumnCountError(expected: Int, got: Int)
  EmptyTableError
  EmptyTitleError
}

type UnbuiltRow =
  List(String)

type StepResult =
  Result(BuilderInternals, BuilderError)

pub fn new() -> Builder {
  Builder(internals: BuilderInternals(rows: [], title: option.None))
}

pub fn add_row(builder: Builder, columns columns: List(String)) -> Builder {
  build_on(builder, fn(internals) {
    use <- validate_column_count(internals, columns)

    Ok(BuilderInternals(..internals, rows: [columns, ..internals.rows]))
  })
}

pub fn set_title(builder: Builder, title title: String) -> Builder {
  build_on(builder, fn(internals) {
    use <- validate_title(title)
    Ok(BuilderInternals(..internals, title: option.Some(title)))
  })
}

pub fn to_result(builder: Builder) -> Result(BuiltTable, BuilderError) {
  case ensure_nonempty_rows(builder) {
    Builder(internals) -> {
      use built_rows <- result.try(build_rows(internals.rows))

      Ok(BuiltTable(rows: built_rows, title: internals.title))
    }

    FailedBuilder(error) -> Error(error)
  }
}

// from_* are for testing only, in order to help isolate what certain tests test
@internal
pub fn from_list(rows: List(List(String))) -> Builder {
  Builder(internals: BuilderInternals(
    rows: list.reverse(rows),
    title: option.None,
  ))
}

@internal
pub fn from_error(error: BuilderError) -> Builder {
  FailedBuilder(error:)
}

fn build_rows(
  unbuilt_rows: List(UnbuiltRow),
) -> Result(rows.Rows(String), BuilderError) {
  unbuilt_rows
  |> list.reverse()
  |> rows.from_lists()
  |> result.map_error(fn(err) {
    case err {
      rows.InconsistentLengthsError(got:, expected:) ->
        InconsistentColumnCountError(got:, expected:)
    }
  })
}

fn build_on(
  builder: Builder,
  build: fn(BuilderInternals) -> StepResult,
) -> Builder {
  case builder {
    Builder(internals) -> {
      internals
      |> build()
      |> finish_build_step()
    }
    FailedBuilder(..) -> builder
  }
}

fn finish_build_step(build_result: StepResult) -> Builder {
  case build_result {
    Ok(internals) -> Builder(internals:)
    Error(error) -> FailedBuilder(error:)
  }
}

fn ensure_nonempty_rows(builder: Builder) -> Builder {
  build_on(builder, fn(internals) {
    case internals.rows {
      [] -> Error(EmptyTableError)
      _ -> Ok(internals)
    }
  })
}

fn validate_column_count(
  internals: BuilderInternals,
  columns: List(String),
  then: fn() -> StepResult,
) -> StepResult {
  let num_columns = list.length(columns)
  case last_row_column_count(internals) {
    option.None -> then()
    option.Some(expected) if expected == num_columns -> then()
    option.Some(expected) ->
      Error(InconsistentColumnCountError(expected:, got: num_columns))
  }
}

fn validate_title(title: String, then: fn() -> StepResult) -> StepResult {
  case title {
    "" -> Error(EmptyTitleError)
    _title -> then()
  }
}

fn last_row_column_count(internals: BuilderInternals) -> option.Option(Int) {
  internals.rows
  |> list.first()
  |> option.from_result()
  |> option.map(list.length)
}
