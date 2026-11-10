require "csv"
require "digest"

module Exports
  # Writes the content of the company's full export in a folder, in the format of RN-18-071
  # (P-18-20): LEIAME.txt, indice.json with each file's SHA-256, the data in JSON and in CSV
  # (UTF-8 with BOM, separator ';') and the documents' files in
  # arquivos/<cpf>/<categoria>/<documento>-v<versão>.pdf. Each table is read in batches and
  # written as it goes, so a large company does not sit in memory. The eSocial's XMLs and the
  # AFD come with their modules (D-661).
  class CompanyArchive
    BATCH = 1_000

    attr_reader :records_count, :files_count

    def initialize(company, root, generated_at: Time.current)
      @company = company
      @root = root
      @generated_at = generated_at
      @records_count = 0
      @files_count = 0
      @index = { "entidades" => [], "arquivos" => [] }
    end

    def write!
      FileUtils.mkdir_p(File.join(@root, "dados", "json"))
      FileUtils.mkdir_p(File.join(@root, "dados", "csv"))
      CompanyContents::ENTITIES.each { |entity| write_entity(entity) }
      write_documents
      write_index
      write_readme
      self
    end

    # The top entries of the folder, for the ZIP.
    def entries
      %w[LEIAME.txt indice.json dados arquivos].select { |name| File.exist?(File.join(@root, name)) }
    end

    private

    def write_entity(entity)
      relation = entity.relation(@company)
      columns = entity.columns(relation.model)
      json_path = File.join("dados", "json", "#{entity.name}.json")
      csv_path = File.join("dados", "csv", "#{entity.name}.csv")
      count = 0
      File.open(File.join(@root, json_path), "w") do |json|
        File.open(File.join(@root, csv_path), "w:UTF-8") do |file|
          file.write("﻿")
          csv = CSV.new(file, col_sep: ";")
          csv << columns
          json.write("[")
          relation.in_batches(of: BATCH, order: :asc) do |batch|
            batch.each do |record|
              row = columns.index_with { |column| value(record, column) }
              json.write(count.zero? ? "\n" : ",\n")
              json.write(JSON.generate(row))
              csv << columns.map { |column| csv_value(row[column]) }
              count += 1
            end
          end
          json.write(count.zero? ? "]\n" : "\n]\n")
        end
      end
      @records_count += count
      @index["entidades"] << { "nome" => entity.name, "descricao" => entity.description, "registros" => count,
        "json" => file_entry(json_path), "csv" => file_entry(csv_path) }
    end

    # The value as the application reads it: the encrypted fields come out readable
    # (RN-18-075).
    def value(record, column)
      raw = record.public_send(:read_attribute, column)
      case raw
      when ActiveSupport::TimeWithZone, Time, DateTime then raw.iso8601
      when Date then raw.iso8601
      when BigDecimal then raw.to_s("F")
      else raw
      end
    end

    def csv_value(value)
      value.is_a?(Hash) || value.is_a?(Array) ? JSON.generate(value) : value
    end

    # The PDF of each readable version of the kept documents, under the person's CPF; a
    # dependent's goes in the holder's folder.
    def write_documents
      names = Hash.new(0)
      versions = DocumentVersion.unscoped.where(company_id: @company.id, document_id: CompanyContents::KEPT_DOCUMENTS.call(@company).select(:id))
        .includes(document: [ :document_type, :dependent, { worker_profile: :user } ], pdf_attachment: :blob)
      versions.find_each(batch_size: 200) do |version|
        next unless version.readable?

        document = version.document
        folder = File.join("arquivos", document.worker_profile&.user&.cpf.to_s.presence || "sem-cpf",
          safe(I18n.t("documents.categories.#{document.category}")))
        base = safe([ document.document_type.name, document.dependent&.name ].compact.join(" - "))
        key = [ folder, base, version.number ]
        names[key] += 1
        suffix = names[key] > 1 ? " (#{names[key]})" : ""
        path = File.join(folder, "#{base}#{suffix}-v#{version.number}.pdf")
        FileUtils.mkdir_p(File.join(@root, folder))
        File.open(File.join(@root, path), "wb") { |file| version.pdf.download { |chunk| file.write(chunk) } }
        @files_count += 1
        @index["arquivos"] << file_entry(path).merge("documento_id" => document.id, "versao_id" => version.id, "versao" => version.number)
      end
    end

    def file_entry(path)
      full = File.join(@root, path)
      { "caminho" => path, "bytes" => File.size(full), "sha256" => Digest::SHA256.file(full).hexdigest }
    end

    def write_index
      index = { "formato" => CompanyExport::FORMAT_VERSION, "gerado_em" => @generated_at.iso8601,
        "empresa" => { "id" => @company.id, "nome" => @company.name, "documento" => @company.document },
        "registros" => @records_count, "quantidade_de_arquivos" => @files_count }.merge(@index)
      File.write(File.join(@root, "indice.json"), JSON.pretty_generate(index) + "\n")
    end

    def write_readme
      File.write(File.join(@root, "LEIAME.txt"), I18n.t("exports.company.readme",
        company: @company.name, date: I18n.l(@generated_at.in_time_zone, format: "%d/%m/%Y %H:%M"),
        version: CompanyExport::FORMAT_VERSION,
        entities: CompanyContents::ENTITIES.map { |entity| "  - #{entity.name}: #{entity.description}" }.join("\n")))
    end

    # A name without the characters a file system refuses.
    def safe(name)
      name.to_s.gsub(%r{[/\\:*?"<>|]}, "-").squish.first(120)
    end
  end
end
