# frozen_string_literal: true

module Metanorma
  module Plugin
    module Asciichem
      # The parse/render seam between AsciiDoc and AsciiChem. Parsing is
      # separated from rendering so the treeprocessor can parse once and
      # both render MathML and harvest citation molecules from the same
      # semantic model.
      module Renderer
        module_function

        # Parses AsciiChem source into the semantic model. Raises
        # AsciiChem::ParseError on invalid input.
        def parse(source)
          AsciiChem.parse(source)
        end

        # Renders the parsed model to a MathML <math> document. Standoc's
        # stem handling detects the <math> root and types the stem
        # accordingly (type="MathML"), so no converter-side support is
        # needed. The formatter's XML declaration is stripped: embedded
        # MathML is a fragment inside the document, not a document.
        def mathml(formula)
          formula.to_mathml.sub(/\A<\?xml[^>]*>\s*/, '')
        end
      end
    end
  end
end
