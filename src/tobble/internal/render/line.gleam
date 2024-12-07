pub type TableLine {
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

pub fn lookup_ascii_table_line(element: TableLine) -> String {
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

pub fn lookup_box_drawing_table_line(element: TableLine) -> String {
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

pub fn lookup_box_drawing_rounded_corner_table_line(
  element: TableLine,
) -> String {
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

pub fn lookup_blank_table_line(element: TableLine) -> String {
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
