# frozen_string_literal: true

require 'asciidoctor' unless defined?(Asciidoctor)
require 'asciichem'

module Metanorma
  module Plugin
    # AsciiChem integration for Metanorma (TODO.impl 49; TODO.v2 08
    # section 3): chemistry in AsciiDoc documents parses to MathML for
    # rendering, and `@cite`-annotated molecules resolve to dataset-type
    # Relaton bibitems collected into the document bibliography - one
    # bibitem per (source, substance), anchored by InChIKey.
    #
    # Following the plugin contract (lutaml, glossarist), this gem
    # exposes the extension classes and does NOT register them with
    # Asciidoctor itself; the host converter registers what it needs:
    #
    #   Asciidoctor::Extensions.register do
    #     treeprocessor Metanorma::Plugin::Asciichem::Extension::ChemTreeprocessor
    #     inline_macro Metanorma::Plugin::Asciichem::Extension::ChemInlineMacro, :chem
    #   end
    module Asciichem
      autoload :Citations, 'metanorma/plugin/asciichem/citations'
      autoload :Extension, 'metanorma/plugin/asciichem/extension'
      autoload :Renderer, 'metanorma/plugin/asciichem/renderer'
    end
  end
end
