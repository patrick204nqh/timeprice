# frozen_string_literal: true

RSpec.describe "timeprice.gemspec" do
  let(:spec) do
    gemspec_path = File.expand_path("../../timeprice.gemspec", __dir__)
    Dir.chdir(File.dirname(gemspec_path)) { Gem::Specification.load(gemspec_path) }
  end

  it "ships at least one file under data/" do
    expect(spec.files.grep(%r{data/}).any?).to be(true)
  end

  it "declares Thor as a runtime dependency" do
    thor = spec.dependencies.find { |d| d.name == "thor" }
    expect(thor).not_to be_nil
    expect(thor.type).to eq(:runtime)
  end

  it "requires Ruby >= 3.2" do
    expect(spec.required_ruby_version.satisfied_by?(Gem::Version.new("3.2.0"))).to be(true)
    expect(spec.required_ruby_version.satisfied_by?(Gem::Version.new("3.1.0"))).to be(false)
  end
end
