# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.1] - 2025-03-16

### Fixed

- Fix compiler deprecation warnings in libraries

## [2.0.0] - 2024-12-07

### Changed

- Options are now functions in the `tobble/table_render_opts` module, to facilitate future options expansion

### Fixed

- Fixed a bug where the `horizontal_rules_after_every_row` option (formerly `EveryRowHasHorizontalRules`) would draw a
horizontal rule between wrapped rows

## [1.1.0] - 2024-12-01

### Added

- Added support for a "blank" line type (`BlankLineType`), which uses spaces for rendering decorations.
- Added support for table titles.
- Added support for omitting horizontal rules, or placing then on every row (`HorizontalRules`).

### Fixed

- Fixed bug where a slightly too small table width would cause a column to have zero width.

## [1.0.2] - 2024-12-01

### Fixed

- Fixed improper output when rendering a table with no rows. It is no longer possible to render a table with no rows.

## [1.0.1] - 2024-11-30

### Fixed

- Fixed bug where wide characters' width would not be calculated properly (#1).

## [1.0.0] - 2024-11-30

Initial project release

[unreleased]: https://github.com/ollien/tobblecompare/v2.0.1...HEAD
[2.0.0]: https://github.com/ollien/tobblecompare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/ollien/tobblecompare/v1.1.0...v2.0.0
[1.1.0]: https://github.com/ollien/tobble/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/ollien/tobble/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/ollien/tobble/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/ollien/tobble/releases/tag/v1.0.0
