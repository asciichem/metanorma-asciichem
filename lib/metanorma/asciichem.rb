# frozen_string_literal: true

require 'asciidoctor' unless defined?(Asciidoctor)
require 'asciichem'

module Metanorma
  # AsciiChem integration for Metanorma (TODO.impl 49; TODO.v2 08
  # section 3): chemistry in AsciiDoc documents parses to MathML for
  # rendering, and `@cite`-annotated molecules resolve to dataset-type
  # Relaton bibitems collected into the document bibliography - one
  # bibitem per (source, substance), anchored by InChIKey.
  module Asciichem
    autoload :Citations, 'metanorma/asciichem/citations'
    autoload :Extension, 'metanorma/asciichem/extension'
    autoload :Renderer, 'metanorma/asciichem/renderer'
  end
end

# metanorma-cli auto-requires gems named metanorma-*; registering at
# require time makes the extension active in every Metanorma compile
# once the gem is installed (the flavour-gem contract).
Asciidoctor::Extensions.register do
  treeprocessor Metanorma::Asciichem::Extension::ChemTreeprocessor
  inline_macro Metanorma::Asciichem::Extension::ChemInlineMacro, :chem
end
