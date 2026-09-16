# frozen_string_literal: true

require_relative 'lib/metanorma/asciichem/version'

Gem::Specification.new do |spec|
  spec.name          = 'metanorma-asciichem'
  spec.version       = Metanorma::Asciichem::VERSION
  spec.authors       = ['Ribose Inc.']
  spec.email         = ['open.source@ribose.com']

  spec.summary       = 'AsciiChem chemistry blocks and substance citations for Metanorma documents.'
  spec.description   = 'Adds [chem] blocks and chem:[] inline macros to Metanorma ' \
                       'AsciiDoc: chemistry written in AsciiChem parses to MathML ' \
                       'for rendering, and @cite-annotated molecules resolve to ' \
                       'dataset-type Relaton bibitems - one per (source, substance), ' \
                       'anchored by InChIKey - automatically collected into the ' \
                       "document's bibliography."

  spec.homepage      = 'https://www.asciichem.org'
  spec.license       = 'BSD-2-Clause'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.3.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/asciichem/metanorma-asciichem'
  spec.metadata['changelog_uri'] = 'https://github.com/asciichem/metanorma-asciichem/blob/main/CHANGELOG.md'
  spec.metadata['docs_uri'] = 'https://www.asciichem.org'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/})
    end
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'asciichem', '>= 0.29'
  spec.add_dependency 'asciidoctor', '~> 2.0'
  spec.add_dependency 'nokogiri', '~> 1.16'

  # NOTE: metanorma-standoc is deliberately NOT a dev dependency:
  # asciichem pins relaton-bib < 2 while current metanorma-standoc
  # requires relaton-bib 2, so a shared bundle resolves standoc 3.3.x
  # which crashes at init. The full standoc compile (chem -> <formula>
  # <stem type="MathML">, bibitem pass-through into <references>) is
  # validated in a separate bundle; see README "Compatibility". Wire
  # the end-to-end spec into this suite once asciichem allows
  # relaton-bib 2 (maintainer decision).
end
