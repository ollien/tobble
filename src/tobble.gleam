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

import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/result
import gleam/string
import gleam/string_tree
import gleam/yielder
import string_width
import tobble/internal/builder.{type BuilderError as InternalBuilderError}
import tobble/internal/rows

/// `Table` is the central type of Tobble. It holds the data you wish to display,
/// without regard for how you render it. These can be built using `builder`/`build`.
pub opaque type Table {
  Table(rows: rows.Rows(String), title: option.Option(String))
}

/// `Builder` is a type used to help you build tables. See `builder` for more details.
pub opaque type Builder {
  Builder(inner: builder.Builder)
}

pub type RenderOption {
  /// Render the table with a width of, at most, the given width. Note that this
  /// is best effort, and there are pathological cases where Tobble will decide
  /// to render your tables slightly wider than requested (e.g. requesting a
  /// width too small to even fit the table borders). By default, the table
  /// width is unconstrained.
  TableWidthRenderOption(width: Int)

  /// Render the table where each column's text has the given width. If a width
  /// less than 1 is given, this will default to 1. By default, columns are as
  /// wide as the longest row within them.
  ColumnWidthRenderOption(width: Int)

  /// Render the table with a different style of border
  /// By default, `ASCIILineType` is used.
  LineTypeRenderOption(line_type: RenderLineType)

  /// Changes the way the table renders horizontal rules. See `HorizontalRules` for more details.
  /// By default, only the first row has a horizontal rule.
  HorizontalRulesRenderOption(horizontal_rules: HorizontalRules)

  /// Render a title for the table at the given position. If the table does not have a title set,
  /// this option is ignored. By default, the title will render at the top.
  TitlePositionRenderOption(position: TitlePosition)

  /// Render a table that has a title set, but without its title.
  HideTitleRenderOption
}

pub type RenderLineType {
  /// Renders the table with box drawing characters for the borders.
  ///
  /// <pre><code style="font-family: monospace;" class="language-plaintext">┌─────────┬──────────────┐
  /// │         │ Output       │
  /// ├─────────┼──────────────┤
  /// │ Stage 1 │ Wibble       │
  /// │ Stage 2 │ Wobble       │
  /// │ Stage 3 │ WibbleWobble │
  /// └─────────┴──────────────┘</code></pre>
  BoxDrawingCharsLineType

  /// Renders the table with box drawing characters for the borders, but
  /// with rounded corners.
  ///
  /// <pre><code style="font-family: monospace;" class="language-plaintext">╭─────────┬──────────────╮
  /// │         │ Output       │
  /// ├─────────┼──────────────┤
  /// │ Stage 1 │ Wibble       │
  /// │ Stage 2 │ Wobble       │
  /// │ Stage 3 │ WibbleWobble │
  /// ╰─────────┴──────────────╯</code></pre>
  BoxDrawingCharsWithRoundedCornersLineType

  /// Render the table with ASCII characters for the borders.
  /// This is the default setting.
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
  ASCIILineType

  /// Renders the table with spaces for the borders.
  /// Note that this does not strip trailing spaces, the borders that
  /// you see in other line types are simply replaced with spaces. It
  /// will, however, remove the top and bottom borders for you.
  ///
  /// ```text
  ///             Output
  ///
  ///   Stage 1   Wibble
  ///   Stage 2   Wobble
  ///   Stage 3   WibbleWobble
  /// ```
  BlankLineType
}

pub type TitlePosition {
  /// Place the title above the table
  TopTitlePosition

  /// Place the title below the table
  BottomTitlePosition
}

pub type HorizontalRules {
  /// Renders the table with only the header having a horizontal rule beneath it. This is the default setting.
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
  HeaderOnlyHorizontalRules
  /// Renders the table with every row the header having a horizontal rule beneath it.
  ///
  /// ```text
  /// +---------+--------------+
  /// |         | Output       |
  /// +---------+--------------+
  /// | Stage 1 | Wibble       |
  /// +---------+--------------+
  /// | Stage 2 | Wobble       |
  /// +---------+--------------+
  /// | Stage 3 | WibbleWobble |
  /// +---------+--------------+
  /// ```
  EveryRowHasHorizontalRules
  /// Renders the table without any horizontal rules interleaved with the table's rows.
  ///
  /// ```text
  /// +---------+--------------+
  /// |         | Output       |
  /// | Stage 1 | Wibble       |
  /// | Stage 2 | Wobble       |
  /// | Stage 3 | WibbleWobble |
  /// +---------+--------------+
  /// ```
  NoHorizontalRules
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

type RenderContext(o) {
  RenderContext(
    minimum_column_widths: List(Int),
    top_and_bottom_border_visibility: Visibility,
    horizontal_rules: HorizontalRules,
    title_options: TitleOptions,
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

type Visibility {
  Visible
  Hidden
}

type TitleOptions {
  TitleOptions(position: TitlePosition, visibility: Visibility)
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
/// tobble.builder()
/// |> tobble.add_row(["", "Output"])
/// |> tobble.add_row(["Stage 1", "Wibble"])
/// |> tobble.add_row(["Stage 2", "Wobble"])
/// |> tobble.add_row(["Stage 3", "WibbleWobble"])
/// |> tobble.build()
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
  options options: List(RenderOption),
) -> yielder.Yielder(String) {
  default_render_context(table)
  |> apply_options(options)
  |> rendered_yielder(table)
}

/// Render the given table to a `String`, with extra options. Note that options
/// are applied in order, so if duplicate or conflicting options are given, the
/// last one will win.
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
///     tobble.ColumnWidthRenderOption(6),
///   ]),
/// )
/// ```
///
/// ```text
/// +--------+--------+
/// |        | Output |
/// +--------+--------+
/// | Stage  | Wibble |
/// | 1      |        |
/// | Stage  | Wobble |
/// | 2      |        |
/// | Stage  | Wibble |
/// | 3      | Wobble |
/// +--------+--------+
/// ```
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

fn rendered_yielder(
  context: RenderContext(a),
  table: Table,
) -> yielder.Yielder(String) {
  title_yielder(context, table.title, for: TopTitlePosition)
  |> yielder.append(top_border_yielder(context))
  |> yielder.append(table_content_yielder(context, table.rows))
  |> yielder.append(bottom_border_yielder(context))
  |> yielder.append(title_yielder(
    context,
    table.title,
    for: BottomTitlePosition,
  ))
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

fn top_border_yielder(context: RenderContext(o)) -> yielder.Yielder(String) {
  case context.top_and_bottom_border_visibility {
    Hidden -> yielder.empty()
    Visible ->
      yielder.once(fn() { render_horizontal_rule(context, TopRulePosition) })
  }
}

fn bottom_border_yielder(context: RenderContext(o)) -> yielder.Yielder(String) {
  case context.top_and_bottom_border_visibility {
    Hidden -> yielder.empty()
    Visible ->
      yielder.once(fn() { render_horizontal_rule(context, BottomRulePosition) })
  }
}

fn title_yielder(
  context: RenderContext(o),
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

fn render_title(context: RenderContext(o), title: String) -> String {
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
  context: RenderContext(o),
  rows: rows.Rows(String),
) -> yielder.Yielder(String) {
  case context.horizontal_rules {
    HeaderOnlyHorizontalRules -> rows_with_header_yielder(context, rows)
    EveryRowHasHorizontalRules ->
      rows_with_horizontal_rules_everywhere_yielder(context, rows)
    NoHorizontalRules -> rows_yielder(context, rows)
  }
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
        row_with_horizontal_rule_yielder(context, head_row),
        rows_yielder(context, rest_rows),
      )
    }
  }
}

fn rows_with_horizontal_rules_everywhere_yielder(
  context: RenderContext(o),
  rows: rows.Rows(String),
) -> yielder.Yielder(String) {
  rows_yielder(context, rows)
  |> yielder.intersperse(render_horizontal_rule(context, CenterRulePosition))
}

fn row_with_horizontal_rule_yielder(
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

fn default_render_context(table: Table) -> RenderContext(b) {
  RenderContext(
    minimum_column_widths: column_lengths(table.rows),
    lookup_element: lookup_ascii_table_element,
    top_and_bottom_border_visibility: Visible,
    horizontal_rules: HeaderOnlyHorizontalRules,
    title_options: TitleOptions(position: TopTitlePosition, visibility: Visible),
  )
}

fn apply_options(
  context: RenderContext(a),
  options: List(RenderOption),
) -> RenderContext(a) {
  list.fold(over: options, from: context, with: fn(context, option) {
    case option {
      LineTypeRenderOption(line_type) ->
        apply_line_type_render_option(context, line_type)
      TableWidthRenderOption(width) ->
        apply_table_width_render_option(context, width)
      ColumnWidthRenderOption(width) ->
        apply_column_width_render_option(context, width)
      HorizontalRulesRenderOption(rules) ->
        apply_horizontal_rules_header_option(context, rules)
      TitlePositionRenderOption(position) ->
        apply_title_position_render_option(context, position)
      HideTitleRenderOption -> apply_hide_title_render_option(context)
    }
  })
}

fn apply_line_type_render_option(
  context: RenderContext(a),
  line_type: RenderLineType,
) -> RenderContext(a) {
  case line_type {
    ASCIILineType ->
      RenderContext(
        ..context,
        lookup_element: lookup_ascii_table_element,
        top_and_bottom_border_visibility: Visible,
      )

    BoxDrawingCharsLineType ->
      RenderContext(
        ..context,
        lookup_element: lookup_box_drawing_table_element,
        top_and_bottom_border_visibility: Visible,
      )

    BoxDrawingCharsWithRoundedCornersLineType ->
      RenderContext(
        ..context,
        lookup_element: lookup_box_drawing_rounded_corner_table_element,
        top_and_bottom_border_visibility: Visible,
      )

    BlankLineType ->
      RenderContext(
        ..context,
        lookup_element: lookup_blank_table_element,
        top_and_bottom_border_visibility: Hidden,
      )
  }
}

fn apply_horizontal_rules_header_option(
  context: RenderContext(o),
  rules: HorizontalRules,
) -> RenderContext(o) {
  RenderContext(..context, horizontal_rules: rules)
}

fn apply_title_position_render_option(
  context: RenderContext(o),
  position: TitlePosition,
) -> RenderContext(o) {
  RenderContext(
    ..context,
    title_options: TitleOptions(position: position, visibility: Visible),
  )
}

fn apply_hide_title_render_option(context: RenderContext(o)) -> RenderContext(o) {
  RenderContext(
    ..context,
    title_options: TitleOptions(..context.title_options, visibility: Hidden),
  )
}

fn apply_table_width_render_option(
  context: RenderContext(a),
  desired_width: Int,
) -> RenderContext(a) {
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

fn apply_column_width_render_option(
  context: RenderContext(a),
  desired_width: Int,
) {
  RenderContext(
    ..context,
    minimum_column_widths: list.map(context.minimum_column_widths, fn(_width) {
      int.max(1, desired_width)
    }),
  )
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

fn lookup_box_drawing_rounded_corner_table_element(
  element: TableElement,
) -> String {
  case element {
    HorizontalLineElement -> "─"
    VerticalLineElement -> "│"
    FourWayJunctionElement -> "┼"
    StartJunctionElement -> "├"
    EndJunctionElement -> "┤"
    TopJunctionElement -> "┬"
    BottomJunctionElement -> "┴"
    TopStartCornerJunctionElement -> "╭"
    TopEndCornerJunctionElement -> "╮"
    BottomStartCornerJunctionElement -> "╰"
    BottomEndCornerJunctionElement -> "╯"
  }
}

fn lookup_blank_table_element(element: TableElement) -> String {
  case element {
    HorizontalLineElement -> " "
    VerticalLineElement -> " "
    FourWayJunctionElement -> " "
    StartJunctionElement -> " "
    EndJunctionElement -> " "
    TopJunctionElement -> " "
    BottomJunctionElement -> " "
    TopStartCornerJunctionElement -> " "
    TopEndCornerJunctionElement -> " "
    BottomStartCornerJunctionElement -> " "
    BottomEndCornerJunctionElement -> " "
  }
}
