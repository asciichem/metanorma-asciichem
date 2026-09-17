# frozen_string_literal: true

require 'metanorma-plugin-asciichem'
require 'rspec'

# The plugin contract leaves registration to the host; specs play the
# host (the same registration metanorma-standoc performs).
Asciidoctor::Extensions.register do
  treeprocessor Metanorma::Plugin::Asciichem::Extension::ChemTreeprocessor
  inline_macro Metanorma::Plugin::Asciichem::Extension::ChemInlineMacro, :chem
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.disable_monkey_patching!
  config.order = :random
end
