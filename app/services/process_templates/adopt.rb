module ProcessTemplates
  # Adopting makes an independent copy (D-232): the library's into a partner or a company,
  # the partner's into one of its companies (P-06-02). The copy keeps where it came from
  # only for information; changes to the original never reach it (CA-06-001). It is born
  # a draft, for the new owner to review before using it. A company's copy is read inside
  # the company, so the tenant sets it.
  module Adopt
    module_function

    # into: a Partner, or the current Company.
    def call(source, into:)
      ActiveRecord::Base.transaction do
        copy = model_for(into).create!(**owner(into), kind: source.kind, name: source.name, description: source.description,
          status: "draft", source_template_id: source.id)
        copies = source.items.to_h { |item| [ item.id, copy.items.create!(item.copy_attributes) ] }
        source.items.each do |item|
          next if item.depends_on_item_ids.empty?

          copies.fetch(item.id).update!(depends_on_item_ids: item.depends_on_item_ids.map { |id| copies.fetch(id).id })
        end
        copy
      end
    end

    def model_for(into)
      into.is_a?(Company) ? ProcessTemplate : SharedProcessTemplate
    end

    def owner(into)
      into.is_a?(Partner) ? { partner: into } : {}
    end
    private_class_method :model_for, :owner
  end
end
