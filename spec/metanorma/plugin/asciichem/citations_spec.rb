# frozen_string_literal: true

require 'spec_helper'
require 'asciichem/resolver'

# Real fetcher shape from the asciichem CLI: a Struct whose #get
# returns the cached payload (no network in specs). Routed per source
# URL prefix like the adapters' request shapes.
CitationFetcher = Struct.new(:pubchem, :common_chemistry, keyword_init: true) do
  def get(url)
    url.include?('commonchemistry') ? common_chemistry : pubchem
  end
end

RSpec.describe Metanorma::Plugin::Asciichem::Citations do
  let(:fixture) do
    File.read(File.expand_path('../../../fixtures/pubchem-aspirin.json', __dir__))
  end
  let(:cc_fixture) do
    File.read(File.expand_path('../../../fixtures/common-chemistry-aspirin.json', __dir__))
  end

  let(:fetch) do
    CitationFetcher.new(pubchem: fixture, common_chemistry: cc_fixture)
  end

  let(:cache) do
    require 'tmpdir'
    AsciiChem::Resolver::Cache.new(dir: File.join(Dir.tmpdir, "mn-asciichem-#{rand(1e9)}"))
  end

  def molecules(*sources)
    sources.map do |source|
      AsciiChem.parse(source).nodes.grep(AsciiChem::Model::Molecule)
    end.flatten
  end

  def load_doc(adoc = "= T\n\np\n")
    Asciidoctor.load(adoc, safe: :safe)
  end

  describe '.append_bibliography' do
    it 'emits one InChIKey-anchored dataset bibitem per (source, substance)' do
      doc = load_doc
      described_class.append_bibliography(
        doc,
        molecules('CC(=O)OC1=CC=CC=C1C(=O)O @cas("50-78-2") @cite("pubchem")'),
        cache: cache, fetch: fetch
      )

      section = doc.blocks.last
      expect(section).to be_a(Asciidoctor::Section)
      expect(section.style).to eq('bibliography')

      pass = section.blocks.first
      expect(pass.context).to eq(:pass)
      xml = pass.lines.join
      expect(xml).to include('<bibitem')
      expect(xml).to include('type="dataset"')
      expect(xml).to include('id="BSYNRYMUTXBXSQ-UHFFFAOYSA-N"')
      expect(xml).to include('PubChem CID 2244')
      # relaton-bib 1 writes <keyword>x</keyword>; 2 nests it in
      # <vocab> with whitespace — assert the text, either nesting.
      expect(xml).to match(/<keyword>\s*(<vocab>\s*)?inchikey=BSYNRYMUTXBXSQ-UHFFFAOYSA-N/)
    end

    it 'dedupes the same substance cited twice into one entry' do
      doc = load_doc
      described_class.append_bibliography(
        doc,
        molecules('CC(=O)OC1=CC=CC=C1C(=O)O @cas("50-78-2") @cite("pubchem")',
                  'CC(=O)OC1=CC=CC=C1C(=O)O @name("aspirin") @cite("pubchem")'),
        cache: cache, fetch: fetch
      )

      entries = doc.blocks.last.blocks
      expect(entries.length).to eq(1)
      expect(entries.first.lines.join).to include('id="BSYNRYMUTXBXSQ-UHFFFAOYSA-N"')
    end

    it 'keeps two entries when two sources cite the same substance' do
      # CAS Common Chemistry is opt-in (CC BY-NC); a real user
      # registers it explicitly - the spec does the same.
      AsciiChem::Resolver.register(:common_chemistry,
                                   AsciiChem::Resolver::CommonChemistry)

      doc = load_doc
      described_class.append_bibliography(
        doc,
        molecules('CC(=O)OC1=CC=CC=C1C(=O)O @cas("50-78-2") @cite("pubchem")',
                  'CC(=O)OC1=CC=CC=C1C(=O)O @cas("50-78-2") @cite("common_chemistry")'),
        cache: cache, fetch: fetch
      )

      entries = doc.blocks.last.blocks
      expect(entries.length).to eq(2)
      # Same substance -> same InChIKey anchor from both sources; the
      # (source, anchor) key keeps the entries distinct.
      anchors = entries.map { |pass| pass.lines.join[/id="([^"]+)"/, 1] }
      expect(anchors).to all(eq('BSYNRYMUTXBXSQ-UHFFFAOYSA-N'))
      expect(entries.count { |pass| pass.lines.join.include?('PubChem') }).to eq(1)
      expect(entries.count { |pass| pass.lines.join.include?('CAS Common Chemistry') }).to eq(1)
    end

    it 'appends nothing when no molecule carries @cite' do
      doc = load_doc
      before = doc.blocks.length
      described_class.append_bibliography(doc, molecules('H_2O'),
                                          cache: cache, fetch: fetch)

      expect(doc.blocks.length).to eq(before)
      expect(doc.blocks.last).not_to be_a(Asciidoctor::Section)
    end

    it 'warns and appends nothing when resolution cannot identify the molecule' do
      doc = load_doc
      before = doc.blocks.length
      described_class.append_bibliography(
        doc, molecules('H_2O @cite("pubchem")'), cache: cache, fetch: fetch
      )

      expect(doc.blocks.length).to eq(before)
    end
  end
end
