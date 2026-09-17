# frozen_string_literal: true

require 'nokogiri'

module Metanorma
  module Plugin
    module Asciichem
      # Bibliography emission (TODO.impl 49; TODO.v2 08 section 3):
      # `@cite`-annotated molecules resolve to dataset-type Relaton
      # bibitems - one per (source, substance), deduplicated, anchored by
      # InChIKey - collected into a [bibliography] section appended to
      # the document. Resolution goes through AsciiChem::Citation (the
      # same code path as the CLI), so the document pipeline and the
      # `asciichem cite` command can never drift.
      module Citations
        include Asciidoctor::Logging

        BIBLIOGRAPHY_TITLE = 'Bibliography'
        INCHIKEY_PREFIX = 'inchikey='
        ANCHOR_SANITIZE = /[^A-Za-z0-9-]/

        module_function

        # molecules: parsed AsciiChem model nodes (Model::Molecule) as
        # harvested from [chem] blocks. cache:/fetch: pass through to
        # the resolver (same knobs as `asciichem resolve --refresh` and
        # the asciichem CLI specs). Appends nothing when none of them
        # carries @cite or none resolves (warns instead - builds stay
        # green and reproducible via the resolver cache).
        def append_bibliography(document, molecules, cache: nil, fetch: nil)
          entries = resolve(molecules, cache: cache, fetch: fetch)
          return if entries.empty?

          document << bibliography_section(document, entries)
        end

        def resolve(molecules, cache:, fetch:)
          entries = {}
          molecules.each do |molecule|
            # First-wins: a later identical (source, substance) keeps the
            # first-mention entry and order.
            entries.merge!(entries_for(molecule, cache: cache, fetch: fetch)) do |_key, first, _last|
              first
            end
          end
          entries.values
        end

        def entries_for(molecule, cache:, fetch:)
          AsciiChem::Citation.for_molecule(molecule, cache: cache, fetch: fetch)
                             .map { |source, bibitem| entry(source, bibitem) }
                             .reduce({}, :merge)
        rescue AsciiChem::Error => e
          logger.warn(message_with_context(
                        "cannot build substance citation: #{e.message} " \
                        '(no bibitem emitted)',
                        source_location: nil
                      ))
          {}
        end

        # [source, bibitem] -> { [source, anchor] => [anchor, xml] }:
        # the compound key dedupes same (source, substance) while the
        # insertion-ordered hash preserves first-mention order.
        def entry(source, bibitem)
          xml = bibitem.to_xml
          anchor = anchor_for(xml) || fallback_anchor(source, xml)
          { [source, anchor] => [anchor, with_anchor(xml, anchor)] }
        end

        # The InChIKey is the cross-source join key: every bibitem for
        # the same substance carries the same keyword, so two spellings
        # of one substance (CAS RN vs name) collapse onto one anchor.
        # Anchors read the emitted wire XML, not vendor object APIs:
        # relaton-bib 1 writes <keyword>inchikey=...</keyword> and
        # relaton-bib 2 nests it (<keyword><vocab>...</vocab></keyword>)
        # — one pattern serves both.
        def anchor_for(xml)
          xml[/#{INCHIKEY_PREFIX}([A-Za-z0-9-]+)/, 1]
        end

        def fallback_anchor(source, xml)
          docid = xml[%r{<docidentifier[^>]*>([^<]+)</docidentifier>}, 1]
          slug = docid ? docid.gsub(ANCHOR_SANITIZE, '') : 'substance'
          "#{source}-#{slug}"
        end

        # Relaton emits <bibitem id="..."> with an id derived from the
        # docidentifier; the anchor (InChIKey) replaces it so document
        # cross-references <<INCHIKEY>> land on the entry.
        def with_anchor(xml, anchor)
          root = Nokogiri::XML(xml).root
          root['id'] = anchor
          root.to_xml
        end

        def bibliography_section(document, entries)
          section = Asciidoctor::Section.new(document, 1, false)
          section.style = 'bibliography'
          section.title = BIBLIOGRAPHY_TITLE
          entries.each { |anchor, xml| section << pass_block(section, anchor, xml) }
          section
        end

        # A [pass] block's content reaches the semantic XML unwrapped
        # (passthrough formats="metanorma"), placing the bibitem
        # verbatim inside <references>.
        def pass_block(section, _anchor, xml)
          Asciidoctor::Block.new(section, :pass, content_model: :raw,
                                                 source: xml,
                                                 attributes: { 'style' => 'pass' })
        end
      end
    end
  end
end
