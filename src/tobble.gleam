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

type RenderContext {
  RenderContext(
    output_tree: string_tree.StringTree,
    minimum_column_widths: List(Int),
  )
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
  let rendered_context =
    RenderContext(
      output_tree: string_tree.new(),
      minimum_column_widths: column_lengths(table.rows),
    )
    |> render_horizontal_rule()
    |> render_newline()
    |> render_rows_with_header(table.rows)
    |> render_newline()
    |> render_horizontal_rule()

  string_tree.to_string(rendered_context.output_tree)
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

fn render_horizontal_rule(context: RenderContext) -> RenderContext {
  let upd_tree =
    list.fold(
      over: context.minimum_column_widths,
      from: string_tree.append(context.output_tree, junction()),
      with: fn(acc, width) {
        acc
        // +2 for padding on each side
        |> string_tree.append(string.repeat(horizontal(), width + 2))
        |> string_tree.append(junction())
      },
    )

  RenderContext(..context, output_tree: upd_tree)
}

fn render_newline(context: RenderContext) -> RenderContext {
  let upd_tree = string_tree.append(context.output_tree, "\n")

  RenderContext(..context, output_tree: upd_tree)
}

fn render_rows_with_header(
  context: RenderContext,
  rows: rows.Rows(String),
) -> RenderContext {
  case rows.pop_row(rows) {
    // No rows, so no change needed
    Error(Nil) -> context
    Ok(#(head_row, rest_rows)) -> {
      context
      |> render_header(head_row)
      |> render_newline()
      |> render_rows(rest_rows)
    }
  }
}

fn render_header(
  context: RenderContext,
  column_text: List(String),
) -> RenderContext {
  context
  |> render_row(column_text)
  |> render_newline()
  |> render_horizontal_rule()
}

fn render_rows(context: RenderContext, rows: rows.Rows(String)) -> RenderContext {
  let upd_tree =
    rows.map_rows(over: rows, apply: fn(row) {
      let row_ctx =
        render_row(
          RenderContext(..context, output_tree: string_tree.new()),
          row,
        )

      row_ctx.output_tree
    })
    |> string_tree.join("\n")
    |> string_tree.prepend_tree(context.output_tree)

  RenderContext(..context, output_tree: upd_tree)
}

fn render_row(
  context: RenderContext,
  column_text: List(String),
) -> RenderContext {
  let upd_tree =
    list.map2(column_text, context.minimum_column_widths, fn(column, width) {
      column
      |> string.pad_end(to: width, with: " ")
      |> string_tree.from_string()
    })
    |> string_tree.join(center_separator())
    |> string_tree.prepend(start_separator())
    |> string_tree.append(end_separator())
    |> string_tree.prepend_tree(context.output_tree)

  RenderContext(..context, output_tree: upd_tree)
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
