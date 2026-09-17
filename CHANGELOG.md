# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Changed

- Requires asciichem >= 0.29.2 (relaton-bib `< 3`), enabling
  co-resolution with current metanorma gems; metanorma-standoc is
  now a development dependency.
- End-to-end standoc compile wired into the suite
  (`standoc_spec.rb`): `[chem]` → `<formula><stem type="MathML">`,
  dataset bibitems verbatim in `<references normative="false">`,
  InChIKey anchors.
- Citation anchors are derived from the emitted bibitem XML (works
  under both relaton-bib major lines) instead of vendor object APIs.

## [0.1.0] - 2026-09-16

### Added

- `[chem]` block: AsciiChem source parses to the semantic model and
  renders as a MathML stem (`<formula><stem type="MathML">` in
  Metanorma semantic XML). Block ids and titles carry over; invalid
  sources log an error and keep the block as sourcecode.
- `chem:[]` inline macro (target and attribute forms) for inline
  chemistry.
- Substance citations: `@cite`-annotated molecules in `[chem]` blocks
  resolve through `AsciiChem::Citation` to dataset-type Relaton
  bibitems, one per (source, substance), deduplicated, anchored by
  InChIKey, appended as a `[bibliography]` section.
- `:asciichem-cache-dir:` document attribute for offline,
  reproducible citation resolution.

## [0.1.0-renamed] - 2026-09-17
### Renamed

- The gem moves to the metanorma org as
  `metanorma-plugin-asciichem` (from asciichem/metanorma-asciichem),
  following the plugin-family convention (lutaml, glossarist,
  plantuml). Namespace is now `Metanorma::Plugin::Asciichem` with
  lib at `metanorma/plugin/asciichem`; the require-by-name entry is
  `metanorma-plugin-asciichem`. Per the plugin contract the gem no
  longer self-registers with Asciidoctor — metanorma-standoc
  requires and registers it (as it does for lutaml/glossarist).
  Not released under the previous name, so the rename is invisible
  to users.
