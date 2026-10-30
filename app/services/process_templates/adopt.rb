module ProcessTemplates
  # Adopting makes an independent copy (D-232): the library's into a partner or a company,
  # the partner's into one of its companies (P-06-02). The copy keeps where it came from
  # only for information; changes to the original never reach it (CA-06-001). It is born
  # a draft, for the new owner to review before using it. A company's copy is read inside
  # the company, so the tenant sets it.
  module Adopt
    module_function

    # into: a Partner, or the current Company. by: who adopts, as the sender of the copied PDFs.
    def call(source, into:, by:)
      ActiveRecord::Base.transaction do
        copy = model_for(into).create!(**owner(into), kind: source.kind, name: source.name, description: source.description,
          status: "draft", source_template_id: source.id)
        items = source.items_with_materials
        copies = items.to_h { |item| [ item.id, copy.items.create!(item.copy_attributes) ] }
        items.each do |item|
          copy_material(item.material_in_use, into: copies.fetch(item.id), by: by) if item.acknowledgement?
          next if item.depends_on_item_ids.empty?

          copies.fetch(item.id).update!(depends_on_item_ids: item.depends_on_item_ids.map { |id| copies.fetch(id).id })
        end
        copy
      end
    end

    # Only the version in use, as the copy's first, in a file of the copy's own owner with
    # the same scan result (D-640). Nothing is copied during an impersonate simulation.
    def copy_material(material, into:, by:)
      return if material.nil? || Simulation.active?

      original = material.file.blob
      blob = original.open do |file|
        ActiveStorage::Blob.create_and_upload!(io: file, filename: original.filename.to_s, content_type: original.content_type,
          identify: false)
      end
      into.materials.create!(version: 1, uploaded_by: by, file: blob)
      FileScan.start!(blob, from: original.file_scan)
    end

    def model_for(into)
      into.is_a?(Company) ? ProcessTemplate : SharedProcessTemplate
    end

    def owner(into)
      into.is_a?(Partner) ? { partner: into } : {}
    end
    private_class_method :copy_material, :model_for, :owner
  end
end
