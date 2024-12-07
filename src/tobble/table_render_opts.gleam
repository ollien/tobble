import gleam/list
import tobble/internal/render

pub opaque type Option {
  Option(inner: render.Option)
}

/// Render the table with a width of, at most, the given width. Note that this
/// is best effort, and there are pathological cases where Tobble will decide
/// to render your tables slightly wider than requested (e.g. requesting a
/// width too small to even fit the table borders). By default, the table
/// width is unconstrained.
pub fn table_width(width: Int) -> Option {
  Option(inner: render.TableWidthRenderOption(width:))
}

/// Render the table where each column's text has the given width. If a width
/// less than 1 is given, this will default to 1. By default, columns are as
/// wide as the longest row within them.
pub fn column_width(width: Int) -> Option {
  Option(inner: render.ColumnWidthRenderOption(width:))
}

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
pub fn line_type_ascii() -> Option {
  Option(inner: render.LineTypeRenderOption(line_type: render.ASCIILineType))
}

/// Renders the table with box drawing characters for the borders.
///
/// <pre><code style="font-family: monospace;" class="language-plaintext">┌─────────┬──────────────┐
/// │         │ Output       │
/// ├─────────┼──────────────┤
/// │ Stage 1 │ Wibble       │
/// │ Stage 2 │ Wobble       │
/// │ Stage 3 │ WibbleWobble │
/// └─────────┴──────────────┘</code></pre>
pub fn line_type_box_drawing_characters() -> Option {
  Option(inner: render.LineTypeRenderOption(
    line_type: render.BoxDrawingCharsLineType,
  ))
}

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
pub fn line_type_rounded_corner_box_drawing_characters() -> Option {
  Option(inner: render.LineTypeRenderOption(
    line_type: render.BoxDrawingCharsWithRoundedCornersLineType,
  ))
}

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
pub fn line_type_blank() -> Option {
  Option(inner: render.LineTypeRenderOption(line_type: render.BlankLineType))
}

/// Place the title above the table. If the table does not have a title set, this option is ignored.
/// By default, the title will render at the top.
pub fn title_position_top() -> Option {
  Option(inner: render.TitlePositionRenderOption(render.TopTitlePosition))
}

/// Place the title above the table. If the table does not have a title set, this option is ignored.
pub fn title_position_bottom() -> Option {
  Option(inner: render.TitlePositionRenderOption(render.BottomTitlePosition))
}

/// Render a table that has a title set, but without its title.
pub fn hide_title() -> Option {
  Option(inner: render.HideTitleRenderOption)
}

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
pub fn horizontal_rules_only_after_header() -> Option {
  Option(inner: render.HorizontalRulesRenderOption(
    render.HeaderOnlyHorizontalRules,
  ))
}

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
pub fn horizontal_rules_after_every_row() -> Option {
  Option(inner: render.HorizontalRulesRenderOption(
    render.EveryRowHasHorizontalRules,
  ))
}

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
pub fn no_horizontal_rules() -> Option {
  Option(inner: render.HorizontalRulesRenderOption(render.NoHorizontalRules))
}

@internal
pub fn unwrap_options(options: List(Option)) {
  list.map(options, fn(option) { option.inner })
}
