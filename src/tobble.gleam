//// Tobble is a table library for Gleam, which makes it as easy as
//// possible to render tables from simple output. It does provide some
//// customization options, but they are not very expansive, as Tobble does not
//// aim to be a full layout library. Rather, it aims to make it simple to make
//// beautiful output for your programs.
////
//// ```gleam
//// import gleam/io
//// import tobble
////
//// pub fn main() {
////   let assert Ok(table) =
////     tobble.builder()
////     |> tobble.add_row(["", "Output"])
////     |> tobble.add_row(["Stage 1", "Wibble"])
////     |> tobble.add_row(["Stage 2", "Wobble"])
////     |> tobble.add_row(["Stage 3", "WibbleWobble"])
////     |> tobble.build()
////
////   io.println(tobble.render(table))
//// }
//// ```
////
//// ```text
//// +---------+--------------+
//// |         | Output       |
//// +---------+--------------+
//// | Stage 1 | Wibble       |
//// | Stage 2 | Wobble       |
//// | Stage 3 | WibbleWobble |
//// +---------+--------------+
//// ```

import gleam/option
import gleam/result
import gleam/string_tree
import gleam/yielder
import tobble/internal/builder.{type BuilderError as InternalBuilderError}
import tobble/internal/render
import tobble/internal/rows
import tobble/table_render_opts

/// `Table` is the central type of Tobble. It holds the data you wish to display,
/// without regard for how you render it. These can be built using `builder`/`build`.
pub opaque type Table {
  Table(rows: rows.Rows(String), title: option.Option(String))
}

/// `Builder` is a type used to help you build tables. See `builder` for more details.
pub opaque type Builder {
  Builder(inner: builder.Builder)
}

pub type BuilderError {
  /// Returned when not all rows have the same number of columns.
  ///
  /// **Why is this an error?** It is not possible to render a rectangular
  ///                           table if any row has a different number of
  ///                           columns than another.
  InconsistentColumnCountError(expected: Int, got: Int)

  /// Returned when attempting to build a table with no rows.
  ///
  /// **Why is this an error?** It is somewhat unclear how to render this, and
  ///                           is left as an error so callers can handle it
  ///                           however is best for their application.
  EmptyTableError

  /// Returned when attempting to build a table with an empty string as the title.
  ///
  /// **Why is this an error?** It is somewhat unclear how to render this, and
  ///                           is likely the result of a bug in your app.
  EmptyTitleError
}

/// Create a new `Builder` for table generation. Once you have completed
/// adding your rows to this with `add_row`, you should call `build` to
/// generate a `Table`.
pub fn builder() -> Builder {
  Builder(inner: builder.new())
}

/// Add a row to a table that is being built. Every call to `add_row` for a given
/// `Builder` must have the same number of columns, or an
/// `InconsistentColumnCountError` will be returned when `build` is called.
pub fn add_row(to builder: Builder, columns columns: List(String)) -> Builder {
  builder.inner
  |> builder.add_row(columns)
  |> Builder()
}

/// Set a title for a table that is being built. The title must be a non-empty
/// string or a `TitleEmptyError` will be returned when `build` is called.
///
/// # Example
///
/// ```gleam
/// let assert Ok(table) =
///   tobble.builder()
///   |> tobble.set_title("Setup")
///   |> tobble.add_row(["", "Output"])
///   |> tobble.add_row(["Stage 1", "Wibble"])
///   |> tobble.add_row(["Stage 2", "Wobble"])
///   |> tobble.add_row(["Stage 3", "WibbleWobble"])
///   |> tobble.build()
///
/// io.println(tobble.render(table))
/// ```
///
/// ```gleam
///          Setup
/// +---------+--------------+
/// |         | Output       |
/// +---------+--------------+
/// | Stage 1 | Wibble       |
/// | Stage 2 | Wobble       |
/// | Stage 3 | WibbleWobble |
/// +---------+--------------+
/// ```
pub fn set_title(to builder: Builder, title title: String) -> Builder {
  builder.inner
  |> builder.set_title(title)
  |> Builder()
}

/// Build a `Table` from the given `Builder`. If an invalid operation was
/// performed when constructing the `Builder`, an error will be returned.
pub fn build(with builder: Builder) -> Result(Table, BuilderError) {
  builder.inner
  |> builder.to_result()
  |> result.map(fn(built) { Table(rows: built.rows, title: built.title) })
  |> result.map_error(builder_error_from_internal)
}

@internal
pub fn build_with_internal(
  builder: builder.Builder,
) -> Result(Table, BuilderError) {
  build(Builder(inner: builder))
}

/// Render the given table to a `String`, with the default options.
/// The output can be customized by using `render_with_options`.
///
/// # Example
///
/// ```gleam
/// let assert Ok(table) =
///     tobble.builder()
///     |> tobble.add_row(["", "Output"])
///     |> tobble.add_row(["Stage 1", "Wibble"])
///     |> tobble.add_row(["Stage 2", "Wobble"])
///     |> tobble.add_row(["Stage 3", "WibbleWobble"])
///     |> tobble.build()
///
/// io.println(tobble.render(table))
/// ```
///
/// ```text
/// +---------+--------------+
/// |         | Output       |
/// +---------+--------------+
/// | Stage 1 | Wibble       |
/// | Stage 2 | Wobble       |
/// | Stage 3 | WibbleWobble |
/// +---------+--------------+
/// ```
pub fn render(table table: Table) -> String {
  render_with_options(table, [])
}

/// Render the given table to a `Yielder`. Each element of the `Yielder` will
/// produce a single line of output, without a trailing newline. Note that
/// options are applied in order, so if duplicate or conflicting options
/// are given, the last one will win.
///
/// # Example
///
/// ```gleam
/// let assert Ok(table) =
///   tobble.builder()
///   |> tobble.add_row(["", "Output"])
///   |> tobble.add_row(["Stage 1", "Wibble"])
///   |> tobble.add_row(["Stage 2", "Wobble"])
///   |> tobble.add_row(["Stage 3", "WibbleWobble"])
///   |> tobble.build()
///
///
/// table
/// |> tobble.render_iter(options: [])
/// |> yielder.each(io.println)
/// ```
///
/// ```text
/// +---------+--------------+
/// |         | Output       |
/// +---------+--------------+
/// | Stage 1 | Wibble       |
/// | Stage 2 | Wobble       |
/// | Stage 3 | WibbleWobble |
/// +---------+--------------+
/// ```
pub fn render_iter(
  table table: Table,
  options options: List(table_render_opts.Option),
) -> yielder.Yielder(String) {
  render.default_render_context(table.rows)
  |> table_render_opts.apply_options(options)
  |> render.to_yielder(table.rows, table.title)
}

/// Render the given table to a `String`, with extra options (found in
/// `tobble/table_render_opts`). Note that options are applied in order, so if
/// duplicate or conflicting options are given, the last one will win.
///
///
/// ```gleam
/// let assert Ok(table) =
///   tobble.builder()
///   |> tobble.add_row(["", "Output"])
///   |> tobble.add_row(["Stage 1", "Wibble"])
///   |> tobble.add_row(["Stage 2", "Wobble"])
///   |> tobble.add_row(["Stage 3", "WibbleWobble"])
///   |> tobble.build()
///
/// io.println(
///   tobble.render_with_options(table, options: [
///     table_render_opts.column_width(6),
///     table_render_opts.horizontal_rules_after_every_row(),
/// ]),
///)
/// ```
///
/// ```text
/// +--------+--------+
/// |        | Output |
/// +--------+--------+
/// | Stage  | Wibble |
/// | 1      |        |
/// +--------+--------+
/// | Stage  | Wobble |
/// | 2      |        |
/// +--------+--------+
/// | Stage  | Wibble |
/// | 3      | Wobble |
/// +--------+--------+
pub fn render_with_options(
  table table: Table,
  options options: List(table_render_opts.Option),
) -> String {
  render.default_render_context(table.rows)
  |> table_render_opts.apply_options(options)
  |> render.to_yielder(table.rows, table.title)
  |> yielder.map(string_tree.from_string)
  |> yielder.to_list()
  |> string_tree.join("\n")
  |> string_tree.to_string()
}

/// Convert an existing table to a list of its rows.
///
/// # Example
///
/// ```gleam
/// let assert Ok(table) =
///   tobble.builder()
///   |> tobble.add_row(["", "Output"])
///   |> tobble.add_row(["Stage 1", "Wibble"])
///   |> tobble.add_row(["Stage 2", "Wobble"])
///   |> tobble.add_row(["Stage 3", "WibbleWobble"])
///   |> tobble.build()
///
/// io.debug(tobble.to_list(table))
/// ```
///
/// ```gleam
/// [
///   ["", "Output"],
///   ["Stage 1", "Wibble"],
///   ["Stage 2", "Wobble"],
///   ["Stage 3", "WibbleWobble"]
/// ]
/// ```
pub fn to_list(table: Table) -> List(List(String)) {
  rows.to_lists(table.rows)
}

/// Get the title of a table, if there is one.
///
/// # Example
///
/// ```gleam
/// let assert Ok(table) =
///   tobble.builder()
///   |> tobble.set_title("Setup")
///   |> tobble.add_row(["", "Output"])
///   |> tobble.add_row(["Stage 1", "Wibble"])
///   |> tobble.add_row(["Stage 2", "Wobble"])
///   |> tobble.add_row(["Stage 3", "WibbleWobble"])
///   |> tobble.build()
///
/// io.debug(tobble.title(table))
/// ```
///
/// ```gleam
/// Some("Setup")
/// ```
pub fn title(table: Table) -> option.Option(String) {
  table.title
}

fn builder_error_from_internal(error: InternalBuilderError) {
  case error {
    builder.InconsistentColumnCountError(expected:, got:) ->
      InconsistentColumnCountError(expected:, got:)

    builder.EmptyTableError -> EmptyTableError
    builder.EmptyTitleError -> EmptyTitleError
  }
}
