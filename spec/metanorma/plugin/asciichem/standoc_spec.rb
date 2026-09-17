# frozen_string_literal: true

require 'spec_helper'

# End-to-end through the real metanorma-standoc converter (dev
# dependency since asciichem 0.29.2 widened its relaton-bib
# constraint to < 3): [chem] blocks land as
# <formula><stem type="MathML">, and the emitted bibitems reach
# <references> verbatim through the [pass] passthrough, anchored by
# InChIKey. Offline: resolution comes from a seeded resolver cache.
RSpec.describe 'metanorma-standoc compile', :standoc do
  it 'renders chemistry as MathML formulas and collects dataset bibitems' do
    require 'tmpdir'
    require 'asciichem/resolver'
    require 'metanorma/standoc'
    require 'metanorma/converter/converter'

    fixture = File.read(File.expand_path('../../../fixtures/pubchem-aspirin.json', __dir__))
    fetcher = Struct.new(:body) do
      def get(_url) = body
    end.new(fixture)
    cache = AsciiChem::Resolver::Cache.new(
      dir: File.join(Dir.tmpdir, "mn-asciichem-standoc-#{rand(1e9)}")
    )
    AsciiChem::Resolver[:pubchem].new.resolve(value: 'aspirin', convention: 'name',
                                              fetch: fetcher, cache: cache)

    adoc = <<~ADOC
      = Aspirin monograph
      Author
      :no-isobib:
      :no-valid:
      :asciichem-cache-dir: #{cache.dir}

      == Synthesis

      [chem]
      ----
      2H_2 + O_2 -> 2H_2O
      ----

      [chem]
      ----
      CC(=O)OC1=CC=CC=C1C(=O)O @name("aspirin") @cite("pubchem")
      ----

      Inline water: chem:H_2O[] in prose.
    ADOC

    xml = Asciidoctor.convert(adoc, backend: :standoc, header_footer: true,
                                    safe: :unsafe)

    expect(xml).to include('<formula')
    expect(xml).to include('type="MathML"')
    expect(xml).to include('<math xmlns="http://www.w3.org/1998/Math/MathML"')
    expect(xml).to match(/<references[^>]*normative="false"/)
    bibitem = xml[%r{<bibitem[^>]*type="dataset"[^>]*>.*?</bibitem>}m]
    expect(bibitem).to include('id="BSYNRYMUTXBXSQ-UHFFFAOYSA-N"')
    expect(bibitem).to include('PubChem CID 2244')
  ensure
    FileUtils.remove_entry(cache.dir) if cache
    # standoc writes an error-report html next to the cwd on string input
    FileUtils.rm_f('.html.err.html')
  end
end
