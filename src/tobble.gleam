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
    minimum_column_widths: List(Int),
    lookup_element: fn(TableElement) -> String,
  )
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
  default_render_context(table)
  |> apply_options(options)
  |> rendered_yielder(table)
}

pub fn render_with_options(
  table table: Table,
  options options: List(RenderOption),
) -> String {
  default_render_context(table)
  |> apply_options(options)
  |> rendered_yielder(table)
  |> yielder.map(string_tree.from_string)
  |> yielder.to_list()
  |> string_tree.join("\n")
  |> string_tree.to_string()
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

fn rendered_yielder(
  context: RenderContext(a),
  table: Table,
) -> yielder.Yielder(String) {
  yielder.once(fn() { render_horizontal_rule(context, TopRulePosition) })
  |> yielder.append(rows_with_header_yielder(context, table.rows))
  |> yielder.append(
    yielder.once(fn() { render_horizontal_rule(context, BottomRulePosition) }),
  )
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

fn render_horizontal_rule(
  context: RenderContext(o),
  position: HorizontalRulePosition,
) -> String {
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

  rule
}

fn rows_with_header_yielder(
  context: RenderContext(o),
  rows: rows.Rows(String),
) -> yielder.Yielder(String) {
  case rows.pop_row(rows) {
    // No rows, so no change needed
    Error(Nil) -> yielder.empty()
    Ok(#(head_row, rest_rows)) -> {
      yielder.append(
        header_yielder(context, head_row),
        rows_yielder(context, rest_rows),
      )
    }
  }
}

fn header_yielder(
  context: RenderContext(o),
  column_text: List(String),
) -> yielder.Yielder(String) {
  yielder.append(
    row_yielder(context, column_text),
    yielder.once(fn() { render_horizontal_rule(context, CenterRulePosition) }),
  )
}

fn rows_yielder(
  context: RenderContext(o),
  rows: rows.Rows(String),
) -> yielder.Yielder(String) {
  yielder.unfold(rows, fn(remaining_rows) {
    case rows.pop_row(remaining_rows) {
      Error(Nil) -> yielder.Done
      Ok(#(row, rest_rows)) -> {
        yielder.Next(element: row_yielder(context, row), accumulator: rest_rows)
      }
    }
  })
  |> yielder.flatten()
}

fn row_yielder(
  context: RenderContext(o),
  column_text: List(String),
) -> yielder.Yielder(String) {
  let column_lines =
    list.map(column_text, fn(cell) { string.split(cell, "\n") })
  let height = column_lines |> max_length(list.length) |> result.unwrap(or: 1)

  let visual_rows =
    column_lines
    |> list.map(fn(column) { pad_list_end(column, to: height, with: "") })
    |> list.transpose()

  yielder.unfold(visual_rows, fn(remaining_rows) {
    case remaining_rows {
      [] -> yielder.Done
      [visual_row, ..rest_rows] ->
        yielder.Next(
          element: render_visual_row(context, visual_row),
          accumulator: rest_rows,
        )
    }
  })
}

fn render_visual_row(
  context: RenderContext(o),
  column_text: List(String),
) -> String {
  let start_separator = context.lookup_element(VerticalLineElement) <> " "
  let center_separator =
    " " <> context.lookup_element(VerticalLineElement) <> " "
  let end_separator = " " <> context.lookup_element(VerticalLineElement)

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

fn default_render_context(table: Table) -> RenderContext(b) {
  RenderContext(
    minimum_column_widths: column_lengths(table.rows),
    lookup_element: lookup_ascii_table_element,
  )
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
