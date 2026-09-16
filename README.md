# metanorma-asciichem

[AsciiChem](https://www.asciichem.org) chemistry for
[Metanorma](https://www.metanorma.org) documents: `[chem]` blocks and
`chem:[]` inline macros render chemistry as MathML, and
`@cite`-annotated molecules resolve into dataset-type Relaton
bibitems — one per (source, substance), anchored by InChIKey —
collected automatically into the document bibliography.

## Installation

```sh
gem install metanorma-asciichem
```

metanorma-cli auto-requires gems named `metanorma-*`, so installing
the gem activates the extension for every Metanorma compile (the
flavour-gem contract). Outside metanorma-cli, register manually:

```ruby
require "metanorma/asciichem"
```

## Usage

### Chemistry blocks

```adoc
[chem]
----
2H_2 + O_2 -> 2H_2O
----
```

The block's AsciiChem source parses into the semantic model and
renders as MathML. In the semantic XML this becomes
`<formula><stem type="MathML">…</stem></formula>` — the same shape
Metanorma uses for math, so every flavour renders it. Block ids and
titles carry over (`[chem#reaction,title="Hydrolysis"]`).

Invalid AsciiChem logs an error and keeps the original block as
sourcecode — the build stays reproducible, the problem stays visible.

### Inline chemistry

```adoc
Water is chem:H_2O[] in prose, or chem:[2H_2 + O_2 -> 2H_2O] for
sources with spaces.
```

Inline macros render; they do not contribute citations (inline
substitution runs after the document pass that collects them).

### Substance citations

Annotate a molecule with `@cite` naming the source to cite from; the
molecule's other identifiers say who to resolve it as:

```adoc
[chem]
----
CC(=O)OC1=CC=CC=C1C(=O)O @cas("50-78-2") @cite("pubchem")
----

The record is <<BSYNRYMUTXBXSQ-UHFFFAOYSA-N>>.
```

The build resolves the molecule (CAS RN → PubChem) and appends a
`[bibliography]` section containing one `<bibitem type="dataset">`
per (source, substance):

- **Same substance cited twice** → one deduplicated entry per source.
- **Two sources for one substance** → two entries (PubChem and CAS
  Common Chemistry are different documents), both anchored by the
  same InChIKey — the cross-document join key.
- Every identifier the source returned rides along as a `keyword`, so
  citations stay machine-checkable long after page numbers change.

Resolution goes through `AsciiChem::Citation.for_molecule` — the same
code path as the `asciichem cite` CLI — so the document pipeline and
the command line can never drift.

**Offline/reproducible builds.** Results come from the AsciiChem
resolver cache (user cache directory, TTL'd). Point the document at a
seeded cache to build without network:

```adoc
:asciichem-cache-dir: ./.asciichem-cache
```

Seed it with `asciichem resolve --name aspirin`. Resolution failures
warn and emit no bibitem; they never break the build.

**Sources and licensing.** PubChem resolves by default. CAS Common
Chemistry (CC BY-NC 4.0) is opt-in:

```ruby
AsciiChem::Resolver.register(:common_chemistry,
                             AsciiChem::Resolver::CommonChemistry)
```

A worked example document ships in `docs/example.adoc`.

## Compatibility

Runtime dependencies are `asciichem`, `asciidoctor`, and `nokogiri`
— the extension operates at the Asciidoctor AST level and needs no
Metanorma gem to run.

The full metanorma-standoc compile path was validated against
metanorma-standoc 3.5: `[chem]` → `<formula><stem type="MathML">`,
and the emitted bibitems land verbatim inside
`<references normative="false">` via the `formats="metanorma"`
passthrough. That validation bundle cannot be expressed in this
gem's own Gemfile today because `asciichem` pins `relaton-bib < 2`
while current metanorma-standoc requires relaton-bib 2 — a shared
bundle resolves standoc 3.3.x, which crashes at init. Once asciichem
allows relaton-bib 2, the end-to-end XML spec will be wired into
this suite (the gemspec carries a note at the same location).

## Development

```sh
bundle install
bundle exec rspec        # 15 examples, network-free
bundle exec rubocop
```

Spec fixtures are real PubChem / CAS Common Chemistry payloads; the
fetchers are Structs shaped like the asciidoctor HTTP surface — no
network, no test doubles.

## License

BSD-2-Clause.
