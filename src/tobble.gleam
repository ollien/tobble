import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam/string_tree
import gleam/yielder
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

type RenderContext(o) {
  RenderContext(
    output: RenderOutput(o),
    minimum_column_widths: List(Int),
    lookup_element: fn(TableElement) -> String,
  )
}

type RenderOutput(a) {
  RenderOutput(state: a, append: fn(RenderOutput(a), String) -> RenderOutput(a))
}

type TableElement {
  HorizontalLineElement
  VerticalLineElement
  FourWayJunctionElement
  StartJunctionElement
  EndJunctionElement
  TopJunctionElement
  BottomJunctionElement
  TopStartCornerJunctionElement
  TopEndCornerJunctionElement
  BottomStartCornerJunctionElement
  BottomEndCornerJunctionElement
}

type HorizontalRulePosition {
  TopRulePosition
  CenterRulePosition
  BottomRulePosition
}

type ItemPosition(a) {
  NotLastItemPosition(a)
  LastItemPosition(a)
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
  render_with_options(table, [])
}

pub fn render_iter(
  table table: Table,
  options options: List(RenderOption),
) -> yielder.Yielder(String) {
  let rendered_context =
    yielder_render_context(table)
    |> apply_options(options)
    |> render_table_into_context(table)

  rendered_context.output.state
}

pub fn render_with_options(
  table table: Table,
  options options: List(RenderOption),
) -> String {
  let rendered_context =
    default_render_context(table)
    |> apply_options(options)
    |> render_table_into_context(table)

  string_tree.to_string(rendered_context.output.state)
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

fn render_table_into_context(
  context: RenderContext(a),
  table: Table,
) -> RenderContext(a) {
  context
  |> render_horizontal_rule(TopRulePosition)
  |> render_newline()
  |> render_rows_with_header(table.rows)
  |> render_newline()
  |> render_horizontal_rule(BottomRulePosition)
}

fn column_lengths(rows: rows.Rows(String)) {
  rows.columnwise_fold(over: rows, from: 0, with: fn(max, column) {
    column
    |> string.split("\n")
    |> max_length(string.length)
    |> result.unwrap(or: 0)
    |> int.max(max)
  })
}

fn render_text(context: RenderContext(o), text: String) -> RenderContext(o) {
  RenderContext(..context, output: context.output.append(context.output, text))
}

fn render_horizontal_rule(
  context: RenderContext(o),
  position: HorizontalRulePosition,
) -> RenderContext(o) {
  let start_junction = case position {
    TopRulePosition -> context.lookup_element(TopStartCornerJunctionElement)
    CenterRulePosition -> context.lookup_element(StartJunctionElement)
    BottomRulePosition ->
      context.lookup_element(BottomStartCornerJunctionElement)
  }

  let middle_junction = case position {
    TopRulePosition -> context.lookup_element(TopJunctionElement)
    CenterRulePosition -> context.lookup_element(FourWayJunctionElement)
    BottomRulePosition -> context.lookup_element(BottomJunctionElement)
  }

  let end_junction = case position {
    TopRulePosition -> context.lookup_element(TopEndCornerJunctionElement)
    CenterRulePosition -> context.lookup_element(EndJunctionElement)
    BottomRulePosition -> context.lookup_element(BottomEndCornerJunctionElement)
  }
  let horizontal = context.lookup_element(HorizontalLineElement)

  let rule =
    context.minimum_column_widths
    |> list.map(fn(width) {
      horizontal
      |> string.repeat(width + 2)
      |> string_tree.from_string()
    })
    |> string_tree.join(middle_junction)
    |> string_tree.prepend(start_junction)
    |> string_tree.append(end_junction)
    |> string_tree.to_string()

  render_text(context, rule)
}

fn render_newline(context: RenderContext(o)) -> RenderContext(o) {
  render_text(context, "\n")
}

fn render_rows_with_header(
  context: RenderContext(o),
  rows: rows.Rows(String),
) -> RenderContext(o) {
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
  context: RenderContext(o),
  column_text: List(String),
) -> RenderContext(o) {
  context
  |> render_row(column_text)
  |> render_newline()
  |> render_horizontal_rule(CenterRulePosition)
}

fn render_rows(
  context: RenderContext(o),
  rows: rows.Rows(String),
) -> RenderContext(o) {
  let rows =
    rows.map_rows(over: rows, apply: fn(row) {
      let row_ctx =
        render_row(
          // Can't be a record update until https://github.com/gleam-lang/gleam/pull/3773
          RenderContext(
            minimum_column_widths: context.minimum_column_widths,
            lookup_element: context.lookup_element,
            output: string_tree_render_output(),
          ),
          row,
        )

      row_ctx.output.state
    })
    |> string_tree.join("\n")
    |> string_tree.to_string()

  render_text(context, rows)
}

fn render_row(
  context: RenderContext(o),
  column_text: List(String),
) -> RenderContext(o) {
  let column_lines =
    list.map(column_text, fn(cell) { string.split(cell, "\n") })
  let height = column_lines |> max_length(list.length) |> result.unwrap(or: 1)

  column_lines
  |> list.map(fn(column) { pad_list_end(column, to: height, with: "") })
  |> list.transpose()
  |> fold_join_list(from: context, with: fn(context, item) {
    case item {
      LastItemPosition(row_columns) -> render_visual_row(context, row_columns)
      NotLastItemPosition(row_columns) ->
        context
        |> render_visual_row(row_columns)
        |> render_text("\n")
    }
  })
}

fn render_visual_row(
  context: RenderContext(o),
  column_text: List(String),
) -> RenderContext(o) {
  let start_separator = context.lookup_element(VerticalLineElement) <> " "
  let center_separator =
    " " <> context.lookup_element(VerticalLineElement) <> " "
  let end_separator = " " <> context.lookup_element(VerticalLineElement)

  let row =
    column_text
    |> list.map2(context.minimum_column_widths, fn(cell, width) {
      cell
      |> string.pad_end(to: width, with: " ")
      |> string_tree.from_string()
    })
    |> string_tree.join(center_separator)
    |> string_tree.prepend(start_separator)
    |> string_tree.append(end_separator)
    |> string_tree.to_string()

  render_text(context, row)
}

fn fold_join_list(
  list: List(a),
  from initial: b,
  with folder: fn(b, ItemPosition(a)) -> b,
) {
  let length = list.length(list)

  list
  |> list.index_fold(from: initial, with: fn(acc, item, idx) {
    case idx == length - 1 {
      True -> folder(acc, LastItemPosition(item))
      False -> folder(acc, NotLastItemPosition(item))
    }
  })
}

fn pad_list_end(
  list list: List(a),
  to to_length: Int,
  with filler: a,
) -> List(a) {
  let length = list.length(list)
  case length >= to_length {
    True -> list
    False -> list.flatten([list, list.repeat(filler, to_length - length)])
  }
}

fn max_length(lists: List(a), with get_length: fn(a) -> Int) -> Result(Int, Nil) {
  case lists {
    [] -> Error(Nil)
    lists -> {
      lists
      |> list.fold(from: 0, with: fn(acc, lengthable) {
        let length = get_length(lengthable)
        case length > acc {
          True -> length
          False -> acc
        }
      })
      |> Ok()
    }
  }
}

fn default_render_context(table: Table) -> RenderContext(string_tree.StringTree) {
  default_render_context_with_output(table, string_tree_render_output())
}

fn yielder_render_context(
  table: Table,
) -> RenderContext(yielder.Yielder(String)) {
  default_render_context_with_output(table, yielder_render_output())
}

fn default_render_context_with_output(
  table: Table,
  output: RenderOutput(b),
) -> RenderContext(b) {
  RenderContext(
    output:,
    minimum_column_widths: column_lengths(table.rows),
    lookup_element: lookup_ascii_table_element,
  )
}

fn string_tree_render_output() -> RenderOutput(string_tree.StringTree) {
  RenderOutput(state: string_tree.new(), append: fn(output, data) {
    RenderOutput(..output, state: string_tree.append(output.state, data))
  })
}

fn yielder_render_output() -> RenderOutput(yielder.Yielder(String)) {
  RenderOutput(state: yielder.empty(), append: fn(output, data) {
    let next = yielder.once(fn() { data })
    RenderOutput(..output, state: yielder.append(output.state, next))
  })
}

fn apply_options(
  context: RenderContext(a),
  options: List(RenderOption),
) -> RenderContext(a) {
  list.fold(over: options, from: context, with: fn(context, option) {
    case option {
      RenderLineType(line_type) ->
        apply_line_type_render_option(context, line_type)
      RenderWidth(_width) -> todo
    }
  })
}

fn apply_line_type_render_option(
  context: RenderContext(a),
  line_type: RenderLineType,
) -> RenderContext(a) {
  case line_type {
    ASCIILineType ->
      RenderContext(..context, lookup_element: lookup_ascii_table_element)
    BoxDrawingCharsLineType ->
      RenderContext(..context, lookup_element: lookup_box_drawing_table_element)
  }
}

fn lookup_ascii_table_element(element: TableElement) -> String {
  case element {
    HorizontalLineElement -> "-"
    VerticalLineElement -> "|"
    FourWayJunctionElement -> "+"
    StartJunctionElement -> "+"
    EndJunctionElement -> "+"
    TopJunctionElement -> "+"
    BottomJunctionElement -> "+"
    TopStartCornerJunctionElement -> "+"
    TopEndCornerJunctionElement -> "+"
    BottomStartCornerJunctionElement -> "+"
    BottomEndCornerJunctionElement -> "+"
  }
}

fn lookup_box_drawing_table_element(element: TableElement) -> String {
  case element {
    HorizontalLineElement -> "─"
    VerticalLineElement -> "│"
    FourWayJunctionElement -> "┼"
    StartJunctionElement -> "├"
    EndJunctionElement -> "┤"
    TopJunctionElement -> "┬"
    BottomJunctionElement -> "┴"
    TopStartCornerJunctionElement -> "┌"
    TopEndCornerJunctionElement -> "┐"
    BottomStartCornerJunctionElement -> "└"
    BottomEndCornerJunctionElement -> "┘"
  }
}
