require "rails_helper"

# A key written twice in a locale file silently replaces the first one, as happened to
# the "Segurança" link. This keeps every locale free of duplicated keys.
RSpec.describe "Locale files" do
  def duplicated_keys(node, path = [])
    return [] unless node.respond_to?(:children) && node.children

    if node.is_a?(Psych::Nodes::Mapping)
      keys = node.children.each_slice(2).map { |key, _value| key.value }
      duplicates = keys.tally.select { |_key, count| count > 1 }.keys.map { |key| (path + [ key ]).join(".") }
      duplicates + node.children.each_slice(2).flat_map { |key, value| duplicated_keys(value, path + [ key.value ]) }
    else
      node.children.flat_map { |child| duplicated_keys(child, path) }
    end
  end

  Dir[Rails.root.join("config/locales/**/*.yml")].each do |file|
    it "has no duplicated keys in #{File.basename(file)}" do
      expect(duplicated_keys(Psych.parse_file(file))).to be_empty
    end
  end
end
