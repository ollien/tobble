import gleam/int
import gleam/list
import gleam/order
import gleam/result
import gleam/string
import gleam/string_tree
import gleam/yielder
import string_width
import tobble/internal/builder.{type BuilderError as InternalBuilderError}
import tobble/internal/rows

pub opaque type Table {
  Table(rows: rows.Rows(String))
}

pub type RenderOption {
  RenderTableWidth(width: Int)
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

type ScaledColumnWidths {
  ScaledColumnWidths(widths: List(Int), extra_width: Int)
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
    |> max_length(string_width.line)
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
    list.map2(column_text, context.minimum_column_widths, fn(cell, width) {
      cell
      |> string_width.limit(
        // The max number of rows is the length of the string,
        // so worst case we can have one char per line
        to: string_width.Size(rows: string.length(cell), columns: width),
        ellipsis: "",
      )
      |> string.split("\n")
    })
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
  |> list.map2(context.minimum_column_widths, fn(column, width) {
    column
    |> column_text_to_width(width)
    |> string_tree.from_string()
  })
  |> string_tree.join(center_separator)
  |> string_tree.prepend(start_separator)
  |> string_tree.append(end_separator)
  |> string_tree.to_string()
}

fn column_text_to_width(text: String, width: Int) -> String {
  text
  |> string_width.limit(
    to: string_width.Size(rows: string.length(text), columns: width),
    ellipsis: "",
  )
  |> string.pad_end(to: width, with: " ")
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
      RenderTableWidth(width) -> apply_width_render_option(context, width)
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

fn apply_width_render_option(
  context: RenderContext(a),
  desired_width: Int,
) -> RenderContext(a) {
  let desired_width =
    column_content_width_for_table_width(
      num_columns: list.length(context.minimum_column_widths),
      desired_width:,
    )

  let total_original_width = list_sum(context.minimum_column_widths)
  let scaled_widths =
    list.map(context.minimum_column_widths, fn(column_width) {
      column_width * desired_width / total_original_width
    })

  let total_scaled_width = list_sum(scaled_widths)

  case int.compare(total_scaled_width, total_original_width) {
    order.Gt | order.Eq ->
      RenderContext(..context, minimum_column_widths: scaled_widths)

    order.Lt -> {
      let extra_width = desired_width - total_scaled_width
      // Prioritize adding extra width to empty columns, to hopefully display something
      let ScaledColumnWidths(widths: scaled_widths, extra_width:) =
        scale_empty_columns(scaled_widths, extra_width)

      // ... then redistribute what's left to the other columns
      let ScaledColumnWidths(widths: scaled_widths, ..) =
        redistribute_extra_width(scaled_widths, extra_width)

      RenderContext(..context, minimum_column_widths: scaled_widths)
    }
  }
}

// Turn the desired width from the option into one that includes space for table decorations
// If this is not possible, each column gets one character of content
fn column_content_width_for_table_width(
  num_columns num_columns: Int,
  desired_width desired_width: Int,
) -> Int {
  // This is a bit hacky, but we need to account for thw width of the
  // decorations on the table. The tables are known to have decorations of
  // width 1, width padding on each side. So, we can determine the width taken
  // up by the decorations by observing that
  // +---+---+---+
  // | 1 | 2 | 3 |
  // +---+---+---+
  //
  // ...can be counted as having
  //  - two spaces per column (num_columns * 2), an
  //  - an inner division for each column (num_columns - 1)
  //  - two outer divisions (2)
  //
  let decoration_width = {
    num_columns * 2 + { num_columns - 1 } + 2
  }
  let desired_width = desired_width - decoration_width

  case desired_width <= 0 {
    False -> desired_width
    True -> num_columns
  }
}

fn list_sum(list: List(Int)) -> Int {
  list
  |> list.reduce(fn(a, b) { a + b })
  |> result.unwrap(or: 0)
}

fn scale_empty_columns(
  widths: List(Int),
  allowed_extra_width: Int,
) -> ScaledColumnWidths {
  let #(extra_width, new_widths) =
    list.map_fold(over: widths, from: allowed_extra_width, with: fn(acc, width) {
      case acc {
        0 -> #(acc, width)
        acc if width == 0 -> #(acc - 1, width + 1)
        acc -> #(acc, width)
      }
    })

  ScaledColumnWidths(widths: new_widths, extra_width:)
}

fn redistribute_extra_width(
  widths: List(Int),
  allowed_extra_width: Int,
) -> ScaledColumnWidths {
  case allowed_extra_width {
    0 -> ScaledColumnWidths(widths:, extra_width: 0)
    allowed_extra_width -> {
      let redistributed = do_redistribute_width(widths, allowed_extra_width)
      redistribute_extra_width(redistributed.widths, redistributed.extra_width)
    }
  }
}

fn do_redistribute_width(
  widths: List(Int),
  allowed_extra_width: Int,
) -> ScaledColumnWidths {
  let #(extra_width, new_widths) =
    list.map_fold(
      over: widths,
      from: allowed_extra_width,
      with: fn(extra_width, width) {
        case extra_width {
          0 -> #(extra_width, width)
          extra_width -> #(extra_width - 1, width + 1)
        }
      },
    )

  ScaledColumnWidths(widths: new_widths, extra_width:)
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
