# frozen_string_literal: true

module Metanorma
  module Plugin
    module Asciichem
      # Asciidoctor extension surface (TODO.impl 49): one treeprocessor
      # for block-level chemistry + citation collection, one inline macro
      # for inline chemistry.
      #
      # Block form (citations are collected here - inline macros resolve
      # at substitution time, after treeprocessors have run):
      #
      #   [chem]
      #   ----
      #   2H_2 + O_2 -> 2H_2O
      #   ----
      #
      # Inline form (render-only):
      #
      #   chem:H_2O[]  or  chem:[2H_2 + O_2 -> 2H_2O]
      #
      module Extension
        # Rewrites every style-"chem" block into a stem block carrying
        # the formula's MathML, then appends the substance bibliography
        # built from the harvested molecules.
        #
        # Document attributes:
        #   asciichem-cache-dir - resolve citations from this resolver
        #                         cache directory (reproducible, offline
        #                         builds; seed it with `asciichem
        #                         resolve`).
        class ChemTreeprocessor < Asciidoctor::Extensions::Treeprocessor
          include Asciidoctor::Logging

          def process(document)
            molecules = []
            document.find_by(style: 'chem').each do |node|
              next unless node.is_a?(Asciidoctor::Block)

              molecules.concat(rewrite(node))
            end
            Citations.append_bibliography(document, molecules,
                                          cache: cache_for(document))
            nil
          end

          private

          def cache_for(document)
            dir = document.attr('asciichem-cache-dir')
            dir && AsciiChem::Resolver::Cache.new(dir: dir)
          end

          # Parses the block source once; replaces the node with a stem
          # block of its MathML. Returns the formula's molecule nodes
          # (only molecules can carry @cite annotations), or [] when the
          # block does not parse.
          def rewrite(node)
            formula = parse_or_log(node, '[chem] block', '(block kept as sourcecode)')
            return [] unless formula

            replace_with_stem(node, formula)
            formula.nodes.grep(AsciiChem::Model::Molecule)
          end

          # Parses, or logs the failure and returns nil (the caller
          # keeps the offending block visible instead of crashing the
          # build).
          def parse_or_log(node, where, remedy)
            Renderer.parse(node.lines.join("\n"))
          rescue AsciiChem::ParseError => e
            logger.error(message_with_context(
                           "invalid AsciiChem in #{where}: #{e.message} #{remedy}",
                           source_location: node.source_location
                         ))
            nil
          end

          def replace_with_stem(node, formula)
            stem = Asciidoctor::Block.new(
              node.parent, :stem,
              content_model: :verbatim, source: Renderer.mathml(formula),
              # Standoc reads node.lines (raw); :default subs keep plain
              # Asciidoctor/HTML5 previews working (escaped text).
              subs: :default
            )
            # Style "asciimath" matches core stem blocks; standoc still
            # types the stem MathML from the <math> content itself.
            stem.style = 'asciimath'
            stem.id = node.id if node.id
            stem.title = node.title if node.title
            siblings = node.parent.blocks
            siblings[siblings.index(node)] = stem
            stem
          end
        end

        # Inline chemistry: chem:H_2O[] (target form, no spaces) or
        # chem:[source] (attribute form, any single-line source).
        # Render-only - inline macros resolve after treeprocessors run,
        # so they cannot contribute bibliography entries.
        class ChemInlineMacro < Asciidoctor::Extensions::InlineMacroProcessor
          include Asciidoctor::Logging

          use_dsl
          name_positional_attributes 'text'

          def process(parent, target, attrs)
            source = target.empty? ? attrs['text'] : target
            return empty_inline(parent) if source.nil? || source.empty?

            formula = Renderer.parse(source)
            create_inline(parent, :asciimath, Renderer.mathml(formula))
          rescue AsciiChem::ParseError => e
            logger.error(message_with_context(
                           "invalid AsciiChem in chem: macro: #{e.message} " \
                           '(rendered verbatim)',
                           source_location: parent.source_location
                         ))
            create_inline(parent, :monospaced, source)
          end

          private

          def empty_inline(parent)
            logger.error(message_with_context(
                           'empty chem: macro - provide source ' \
                           '(chem:H_2O[] or chem:[...])',
                           source_location: parent.source_location
                         ))
            create_inline(parent, :quoted, '')
          end
        end
      end
    end
  end
end
