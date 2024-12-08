# tobble

[![Package Version](https://img.shields.io/hexpm/v/tobble)](https://hex.pm/packages/tobble)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/tobble/)

Tobble is a table library for Gleam, which makes it as easy as
possible to render tables from simple output. It does provide some
customization options, but they are not very expansive, as Tobble does not
aim to be a full layout library. Rather, it aims to make it simple to make
beautiful output for your programs.

```gleam
import gleam/io
import tobble

pub fn main() {
  let assert Ok(table) =
    tobble.builder()
    |> tobble.add_row(["", "Output"])
    |> tobble.add_row(["Stage 1", "Wibble"])
    |> tobble.add_row(["Stage 2", "Wobble"])
    |> tobble.add_row(["Stage 3", "WibbleWobble"])
    |> tobble.build()

  io.println(tobble.render(table))
}
```

```text
+---------+--------------+
|         | Output       |
+---------+--------------+
| Stage 1 | Wibble       |
| Stage 2 | Wobble       |
| Stage 3 | WibbleWobble |
+---------+--------------+
```

## Installation

```sh
gleam add tobble@2
```

Further documentation can be found at <https://hexdocs.pm/tobble>.

## Development

Tobble is built using Gleam 1.6. If you would like to hack on Tobble, you
can run the tests with `gleam test`.
