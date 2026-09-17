# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Metanorma::Plugin::Asciichem::Extension do
  def load_doc(adoc)
    Asciidoctor.load(adoc, safe: :safe)
  end

  it 'exposes the extension classes for the host to register' do
    # Plugin contract (lutaml/glossarist pattern): the gem does not
    # self-register; the host converter does. spec_helper plays the
    # host, so the registration is active here.
    expect(Asciidoctor.load('x chem:H_2O[]', safe: :safe).blocks.first)
      .not_to be_nil
    expect(Metanorma::Plugin::Asciichem::VERSION).to eq('0.1.0')
  end

  describe '[chem] blocks' do
    it 'rewrites the block into a stem carrying the MathML' do
      doc = load_doc("[chem]\n----\n2H_2 + O_2 -> 2H_2O\n----\n")
      stem = doc.blocks.find { |b| b.context == :stem }

      expect(stem).not_to be_nil
      expect(stem.style).to eq('asciimath')
      mathml = stem.lines.join("\n")
      expect(mathml).to start_with('<math')
      expect(mathml).not_to include('<?xml')
      expect(doc.find_by(style: 'chem')).to be_empty
    end

    it "keeps the block's id and title on the stem" do
      doc = load_doc("[chem#reaction,title=\"Hydrolysis\"]\n----\nH_2O\n----\n")
      stem = doc.blocks.find { |b| b.context == :stem }

      expect(stem.id).to eq('reaction')
      expect(stem.title).to eq('Hydrolysis')
    end

    it 'logs and keeps the original as sourcecode on invalid AsciiChem' do
      doc = load_doc("[chem]\n----\nnot chemistry at all\n----\n")
      original = doc.blocks.find { |b| b.context == :listing }

      expect(original).not_to be_nil
      expect(original.style).to eq('chem')
      expect(original.lines).to eq(['not chemistry at all'])
    end

    it 'renders multi-line sources such as zmatrices' do
      source = "zmatrix{\n  C1\n  H2 C1 1.09\n}"
      doc = load_doc("[chem]\n----\n#{source}\n----\n")
      stem = doc.blocks.find { |b| b.context == :stem }

      expect(stem.lines.join("\n")).to start_with('<math')
    end
  end

  describe 'chem: inline macro' do
    # Inline macro results resolve at substitution time; html5 has no
    # inline-asciimath handler, so specs drive the real processor
    # directly (the standoc target renders these via stem_parse).
    def process_inline(target, attrs = {})
      parent = Asciidoctor.load("x\n", safe: :safe).blocks.first
      Metanorma::Plugin::Asciichem::Extension::ChemInlineMacro.new
                                                              .process(parent, target, attrs)
    end

    it 'renders the target form into an asciimath inline node' do
      inline = process_inline('H_2O')

      expect(inline.context).to eq(:asciimath)
      expect(inline.text).to start_with('<math')
      expect(inline.text).to include('H')
    end

    it 'renders the attribute form (sources with spaces)' do
      inline = process_inline('', 'text' => '2H_2 + O_2 -> 2H_2O')

      expect(inline.context).to eq(:asciimath)
      expect(inline.text).to start_with('<math')
    end

    it 'falls back to monospaced text on invalid AsciiChem' do
      inline = process_inline('not chemistry')

      expect(inline.context).to eq(:monospaced)
      expect(inline.text).to eq('not chemistry')
    end

    it 'logs and renders empty on a macro with no source' do
      inline = process_inline('', {})

      expect(inline.text).to eq('')
    end
  end
end
