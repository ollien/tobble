import gleam/list
import gleam/option
import gleam/result
import tobble/internal/rows

pub opaque type Builder {
  Builder(internals: BuilderInternals)
  FailedBuilder(error: BuilderError)
}

type BuilderInternals {
  BuilderInternals(rows: List(UnbuiltRow))
}

pub type BuilderError {
  InconsistentColumnCountError(expected: Int, got: Int)
  EmptyTableError
}

type UnbuiltRow =
  List(String)

type StepResult =
  Result(BuilderInternals, BuilderError)

pub fn new() -> Builder {
  Builder(internals: BuilderInternals(rows: []))
}

pub fn add_row(builder: Builder, columns columns: List(String)) -> Builder {
  build_on(builder, fn(internals) {
    use <- validate_column_count(internals, columns)

    Ok(BuilderInternals(rows: [columns, ..internals.rows]))
  })
}

pub fn to_result(builder: Builder) -> Result(rows.Rows(String), BuilderError) {
  case ensure_nonempty(builder) {
    Builder(internals) ->
      internals.rows
      |> list.reverse()
      |> rows.from_lists()
      |> result.map_error(fn(err) {
        case err {
          rows.InconsistentLengthsError(got:, expected:) ->
            InconsistentColumnCountError(got:, expected:)
        }
      })
    FailedBuilder(error) -> Error(error)
  }
}

// from_* are for testing only, in order to help isolate what certain tests test
@internal
pub fn from_list(rows: List(List(String))) -> Builder {
  Builder(internals: BuilderInternals(rows: list.reverse(rows)))
}

@internal
pub fn from_error(error: BuilderError) -> Builder {
  FailedBuilder(error:)
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

fn ensure_nonempty(builder: Builder) -> Builder {
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

fn last_row_column_count(internals: BuilderInternals) -> option.Option(Int) {
  internals.rows
  |> list.first()
  |> option.from_result()
  |> option.map(list.length)
}
