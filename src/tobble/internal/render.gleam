import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/result
import gleam/string
import gleam/string_tree
import gleam/yielder
import string_width
import tobble/internal/rows

/// Internal context for the rendering pipeline to share relevant data
/// with different parts of the pipeline
pub opaque type Context {
  Context(
    minimum_column_widths: List(Int),
    top_and_bottom_border_visibility: Visibility,
    horizontal_rules: HorizontalRules,
    title_options: TitleOptions,
    lookup_line: fn(TableLine) -> String,
  )
}

pub type HorizontalRulePosition {
  TopRulePosition
  CenterRulePosition
  BottomRulePosition
}

pub type ScaledColumnWidths {
  ScaledColumnWidths(widths: List(Int), extra_width: Int)
}

pub type LineType {
  BoxDrawingCharsLineType
  BoxDrawingCharsWithRoundedCornersLineType
  ASCIILineType
  BlankLineType
}

pub type TitlePosition {
  TopTitlePosition
  BottomTitlePosition
}

pub type HorizontalRules {
  HeaderOnlyHorizontalRules
  EveryRowHasHorizontalRules
  NoHorizontalRules
}

pub type Visibility {
  Visible
  Hidden
}

type TitleOptions {
  TitleOptions(position: TitlePosition, visibility: Visibility)
}

type TableLine {
  HorizontalLine
  VerticalLine
  FourWayJunction
  StartJunction
  EndJunction
  TopJunction
  BottomJunction
  TopStartCornerJunction
  TopEndCornerJunction
  BottomStartCornerJunction
  BottomEndCornerJunction
}

/// Render a table to a Yielder, using the options from the provided Context.
pub fn to_yielder(
  context: Context,
  rows: rows.Rows(String),
  title: option.Option(String),
) -> yielder.Yielder(String) {
  title_yielder(context, title, for: TopTitlePosition)
  |> yielder.append(top_border_yielder(context))
  |> yielder.append(table_content_yielder(context, rows))
  |> yielder.append(bottom_border_yielder(context))
  |> yielder.append(title_yielder(context, title, for: BottomTitlePosition))
}

/// Get a Context with the default settings applied
pub fn default_render_context(rows: rows.Rows(String)) -> Context {
  Context(
    minimum_column_widths: column_lengths(rows),
    lookup_line: lookup_ascii_table_line,
    top_and_bottom_border_visibility: Visible,
    horizontal_rules: HeaderOnlyHorizontalRules,
    title_options: TitleOptions(position: TopTitlePosition, visibility: Visible),
  )
}

/// Set the line type for tables rendered using the given Context
pub fn apply_line_type(context: Context, line_type: LineType) -> Context {
  case line_type {
    ASCIILineType ->
      Context(
        ..context,
        lookup_line: lookup_ascii_table_line,
        top_and_bottom_border_visibility: Visible,
      )

    BoxDrawingCharsLineType ->
      Context(
        ..context,
        lookup_line: lookup_box_drawing_table_line,
        top_and_bottom_border_visibility: Visible,
      )

    BoxDrawingCharsWithRoundedCornersLineType ->
      Context(
        ..context,
        lookup_line: lookup_box_drawing_rounded_corner_table_line,
        top_and_bottom_border_visibility: Visible,
      )

    BlankLineType ->
      Context(
        ..context,
        lookup_line: lookup_blank_table_line,
        top_and_bottom_border_visibility: Hidden,
      )
  }
}

/// Set where horizontal rules are drawn for tables rendered using the given Context
pub fn apply_horizontal_rules(
  context: Context,
  rules: HorizontalRules,
) -> Context {
  Context(..context, horizontal_rules: rules)
}

pub fn apply_title_position(
  context: Context,
  position: TitlePosition,
) -> Context {
  Context(
    ..context,
    title_options: TitleOptions(position: position, visibility: Visible),
  )
}

/// Hide the title in tables drawn with the given context
pub fn apply_hide_title(context: Context) -> Context {
  Context(
    ..context,
    title_options: TitleOptions(..context.title_options, visibility: Hidden),
  )
}

/// Set the width (in characters) of tables drawn with the given context
pub fn apply_table_width(context: Context, desired_width: Int) -> Context {
  let desired_width =
    column_content_width_for_table_width(
      num_columns: list.length(context.minimum_column_widths),
      desired_width:,
    )

  let total_original_width = int.sum(context.minimum_column_widths)
  let scaled_widths =
    list.map(context.minimum_column_widths, fn(column_width) {
      column_width * desired_width / total_original_width
    })

  let total_scaled_width = int.sum(scaled_widths)

  case int.compare(total_scaled_width, total_original_width) {
    order.Gt | order.Eq ->
      Context(..context, minimum_column_widths: scaled_widths)

    order.Lt -> {
      let extra_width = desired_width - total_scaled_width

      // Prioritize adding extra width to empty columns, to hopefully display something
      let ScaledColumnWidths(widths: scaled_widths, extra_width:) =
        scale_empty_columns(scaled_widths, extra_width)

      // ... then redistribute what's left to the other columns
      let ScaledColumnWidths(widths: scaled_widths, ..) =
        redistribute_extra_width(scaled_widths, extra_width)

      Context(..context, minimum_column_widths: scaled_widths)
    }
  }
}

/// Set a fixed width (in characters) to columns in tables drawn with the given context
pub fn apply_column_width(context: Context, desired_width: Int) {
  Context(
    ..context,
    minimum_column_widths: list.map(context.minimum_column_widths, fn(_width) {
      int.max(1, desired_width)
    }),
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

fn top_border_yielder(context: Context) -> yielder.Yielder(String) {
  case context.top_and_bottom_border_visibility {
    Hidden -> yielder.empty()
    Visible ->
      yielder.once(fn() { render_horizontal_rule(context, TopRulePosition) })
  }
}

fn bottom_border_yielder(context: Context) -> yielder.Yielder(String) {
  case context.top_and_bottom_border_visibility {
    Hidden -> yielder.empty()
    Visible ->
      yielder.once(fn() { render_horizontal_rule(context, BottomRulePosition) })
  }
}

fn title_yielder(
  context: Context,
  maybe_title: option.Option(String),
  for position: TitlePosition,
) -> yielder.Yielder(String) {
  maybe_title
  |> option.map(fn(title) {
    case context.title_options {
      TitleOptions(visibility: Visible, position: chosen_position)
        if chosen_position == position
      -> {
        render_title(context, title)
        |> string.split("\n")
        |> yielder.from_list()
      }

      TitleOptions(..) -> yielder.empty()
    }
  })
  |> option.unwrap(or: yielder.empty())
}

fn render_horizontal_rule(
  context: Context,
  position: HorizontalRulePosition,
) -> String {
  let start_junction = case position {
    TopRulePosition -> context.lookup_line(TopStartCornerJunction)
    CenterRulePosition -> context.lookup_line(StartJunction)
    BottomRulePosition -> context.lookup_line(BottomStartCornerJunction)
  }

  let middle_junction = case position {
    TopRulePosition -> context.lookup_line(TopJunction)
    CenterRulePosition -> context.lookup_line(FourWayJunction)
    BottomRulePosition -> context.lookup_line(BottomJunction)
  }

  let end_junction = case position {
    TopRulePosition -> context.lookup_line(TopEndCornerJunction)
    CenterRulePosition -> context.lookup_line(EndJunction)
    BottomRulePosition -> context.lookup_line(BottomEndCornerJunction)
  }

  let horizontal = context.lookup_line(HorizontalLine)

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

fn render_title(context: Context, title: String) -> String {
  let num_columns = list.length(context.minimum_column_widths)
  let width =
    minimum_decoration_width(with_columns: num_columns)
    + int.sum(context.minimum_column_widths)

  title
  |> string_width.limit(
    to: string_width.Size(rows: string.length(title), columns: width),
    ellipsis: "",
  )
  |> string_width.align(to: width, align: string_width.Center, with: " ")
}

fn table_content_yielder(
  context: Context,
  rows: rows.Rows(String),
) -> yielder.Yielder(String) {
  case context.horizontal_rules {
    HeaderOnlyHorizontalRules -> rows_with_header_yielder(context, rows)
    EveryRowHasHorizontalRules ->
      rows_with_horizontal_rules_everywhere_yielder(context, rows)
    NoHorizontalRules -> visual_rows_yielder(context, rows)
  }
}

fn rows_with_header_yielder(
  context: Context,
  rows: rows.Rows(String),
) -> yielder.Yielder(String) {
  case rows.pop_row(rows) {
    // No rows, so no change needed
    Error(Nil) -> yielder.empty()
    Ok(#(head_row, rest_rows)) -> {
      yielder.append(
        row_with_horizontal_rule_yielder(context, head_row),
        visual_rows_yielder(context, rest_rows),
      )
    }
  }
}

fn rows_with_horizontal_rules_everywhere_yielder(
  context: Context,
  rows: rows.Rows(String),
) -> yielder.Yielder(String) {
  grouped_rows_yielder(context, rows)
  |> yielder.intersperse(
    yielder.once(fn() { render_horizontal_rule(context, CenterRulePosition) }),
  )
  |> yielder.flatten()
}

fn row_with_horizontal_rule_yielder(
  context: Context,
  column_text: List(String),
) -> yielder.Yielder(String) {
  yielder.append(
    row_yielder(context, column_text),
    yielder.once(fn() { render_horizontal_rule(context, CenterRulePosition) }),
  )
}

fn visual_rows_yielder(context: Context, rows: rows.Rows(String)) {
  // These are visual representations, so flatten the group
  yielder.flatten(grouped_rows_yielder(context, rows))
}

fn grouped_rows_yielder(
  context: Context,
  rows: rows.Rows(String),
) -> yielder.Yielder(yielder.Yielder(String)) {
  yielder.unfold(rows, fn(remaining_rows) {
    case rows.pop_row(remaining_rows) {
      Error(Nil) -> yielder.Done
      Ok(#(row, rest_rows)) -> {
        yielder.Next(element: row_yielder(context, row), accumulator: rest_rows)
      }
    }
  })
}

fn row_yielder(
  context: Context,
  column_text: List(String),
) -> yielder.Yielder(String) {
  let column_lines =
    list.map2(column_text, context.minimum_column_widths, fn(text, width) {
      text
      |> limit_text_width(to: width)
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

fn render_visual_row(context: Context, column_text: List(String)) -> String {
  let start_separator = context.lookup_line(VerticalLine) <> " "
  let center_separator = " " <> context.lookup_line(VerticalLine) <> " "
  let end_separator = " " <> context.lookup_line(VerticalLine)

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
  |> limit_text_width(to: width)
  |> pad_end(to: width)
}

fn limit_text_width(text: String, to width: Int) -> String {
  string_width.limit(
    text,
    // The max number of rows is the length of the string,
    // so worst case we can have one char per line
    to: string_width.Size(rows: string.length(text), columns: width),
    ellipsis: "",
  )
}

fn pad_end(text: String, to width: Int) -> String {
  string_width.align(text, align: string_width.Left, to: width, with: " ")
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

// Turn the desired width from the option into one that includes space for table decorations
// If this is not possible, each column gets one character of content
fn column_content_width_for_table_width(
  num_columns num_columns: Int,
  desired_width desired_width: Int,
) -> Int {
  let desired_width =
    desired_width - minimum_decoration_width(with_columns: num_columns)

  int.max(desired_width, num_columns)
}

fn minimum_decoration_width(with_columns num_columns: Int) {
  // This is a bit hacky, but we need to calculate the minimum width to provide
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
  num_columns * 2 + { num_columns - 1 } + 2
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
      let redistributed =
        do_redistribute_extra_width(widths, allowed_extra_width)
      redistribute_extra_width(redistributed.widths, redistributed.extra_width)
    }
  }
}

fn do_redistribute_extra_width(
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

fn lookup_ascii_table_line(element: TableLine) -> String {
  case element {
    HorizontalLine -> "-"
    VerticalLine -> "|"
    FourWayJunction -> "+"
    StartJunction -> "+"
    EndJunction -> "+"
    TopJunction -> "+"
    BottomJunction -> "+"
    TopStartCornerJunction -> "+"
    TopEndCornerJunction -> "+"
    BottomStartCornerJunction -> "+"
    BottomEndCornerJunction -> "+"
  }
}

fn lookup_box_drawing_table_line(element: TableLine) -> String {
  case element {
    HorizontalLine -> "─"
    VerticalLine -> "│"
    FourWayJunction -> "┼"
    StartJunction -> "├"
    EndJunction -> "┤"
    TopJunction -> "┬"
    BottomJunction -> "┴"
    TopStartCornerJunction -> "┌"
    TopEndCornerJunction -> "┐"
    BottomStartCornerJunction -> "└"
    BottomEndCornerJunction -> "┘"
  }
}

fn lookup_box_drawing_rounded_corner_table_line(element: TableLine) -> String {
  case element {
    HorizontalLine -> "─"
    VerticalLine -> "│"
    FourWayJunction -> "┼"
    StartJunction -> "├"
    EndJunction -> "┤"
    TopJunction -> "┬"
    BottomJunction -> "┴"
    TopStartCornerJunction -> "╭"
    TopEndCornerJunction -> "╮"
    BottomStartCornerJunction -> "╰"
    BottomEndCornerJunction -> "╯"
  }
}

fn lookup_blank_table_line(element: TableLine) -> String {
  case element {
    HorizontalLine -> " "
    VerticalLine -> " "
    FourWayJunction -> " "
    StartJunction -> " "
    EndJunction -> " "
    TopJunction -> " "
    BottomJunction -> " "
    TopStartCornerJunction -> " "
    TopEndCornerJunction -> " "
    BottomStartCornerJunction -> " "
    BottomEndCornerJunction -> " "
  }
}
