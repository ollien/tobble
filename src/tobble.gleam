import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam/string_tree
import tobble/internal/builder.{type BuilderError as InternalBuilderError}
import tobble/internal/rows

pub opaque type Table {
  Table(rows: rows.Rows(String))
}

pub type RenderOption {
  RenderWidth(width: Int)
  RenderLineType(line_type: RenderLineType)
}

pub type RenderLineType {
  BoxDrawingCharsLineType
  ASCIILineType
}

pub type BuilderError {
  InconsistentColumnCountError(expected: Int, got: Int)
}

pub fn builder() -> builder.Builder {
  builder.new()
}

pub fn add_row(
  to builder: builder.Builder,
  columns columns: List(String),
) -> builder.Builder {
  builder.add_row(builder, columns)
}

pub fn build(with builder: builder.Builder) -> Result(Table, BuilderError) {
  builder
  |> builder.to_result()
  |> result.map(fn(rows) { Table(rows:) })
  |> result.map_error(builder_error_from_internal)
}

pub fn render(table table: Table) -> String {
  let column_lengths = column_lengths(table.rows)

  string_tree.new()
  |> render_horizontal_rule(column_lengths)
  |> render_newline()
  |> render_rows_with_header(table.rows, column_lengths)
  |> render_newline()
  |> render_horizontal_rule(column_lengths)
  |> string_tree.to_string()
}

pub fn render_with_options(
  table table: Table,
  options options: List(RenderOption),
) -> String {
  todo
}

pub fn to_list(table: Table) -> List(List(String)) {
  rows.to_lists(table.rows)
}

fn builder_error_from_internal(error: InternalBuilderError) {
  case error {
    builder.InconsistentColumnCountError(expected:, got:) ->
      InconsistentColumnCountError(expected:, got:)
  }
}

fn column_lengths(rows: rows.Rows(String)) {
  rows.columnwise_fold(over: rows, from: 0, with: fn(max, column) {
    int.max(max, string.length(column))
  })
}

fn render_horizontal_rule(
  tree: string_tree.StringTree,
  column_stops: List(Int),
) -> string_tree.StringTree {
  list.fold(
    over: column_stops,
    from: string_tree.append(tree, junction()),
    with: fn(acc, width) {
      acc
      // +2 for padding on each side
      |> string_tree.append(string.repeat(horizontal(), width + 2))
      |> string_tree.append(junction())
    },
  )
}

fn render_newline(tree: string_tree.StringTree) -> string_tree.StringTree {
  string_tree.append(tree, "\n")
}

fn render_rows_with_header(
  main_tree: string_tree.StringTree,
  rows: rows.Rows(String),
  column_stops: List(Int),
) -> string_tree.StringTree {
  case rows.pop_row(rows) {
    // No rows, just give an empty builder
    Error(Nil) -> string_tree.new()
    Ok(#(head_row, rest_rows)) -> {
      main_tree
      |> render_header(head_row, column_stops)
      |> render_newline()
      |> render_rows(rest_rows, column_stops)
    }
  }
}

fn render_header(
  tree: string_tree.StringTree,
  column_text: List(String),
  column_stops: List(Int),
) -> string_tree.StringTree {
  tree
  |> render_row(column_text, column_stops)
  |> render_newline()
  |> render_horizontal_rule(column_stops)
}

fn render_rows(
  tree: string_tree.StringTree,
  rows: rows.Rows(String),
  column_stops: List(Int),
) -> string_tree.StringTree {
  rows.map_rows(over: rows, apply: fn(row) {
    render_row(string_tree.new(), row, column_stops)
  })
  |> string_tree.join("\n")
  |> string_tree.prepend_tree(tree)
}

fn render_row(
  tree: string_tree.StringTree,
  column_text: List(String),
  column_stops: List(Int),
) -> string_tree.StringTree {
  list.map2(column_text, column_stops, fn(column, width) {
    column
    |> string.pad_end(to: width, with: " ")
    |> string_tree.from_string()
  })
  |> string_tree.join(center_separator())
  |> string_tree.prepend(start_separator())
  |> string_tree.append(end_separator())
  |> string_tree.prepend_tree(tree)
}

fn horizontal() -> String {
  "-"
}

fn start_separator() -> String {
  "| "
}

fn end_separator() -> String {
  " |"
}

fn center_separator() -> String {
  " | "
}

fn junction() -> String {
  "+"
}
