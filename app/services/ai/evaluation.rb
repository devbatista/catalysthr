require "prawn"

module Ai
  # The evaluation set of the documents' reading (spec 14, RN-14-140, P-14-34, D-670): fictitious
  # documents, made here with Prawn and marked as fictitious on every page, with the expected
  # answers. It runs only by hand, with `bin/rails ai:evaluate`, because it calls the API and
  # uses the Anthropic's credits; the specs never do (RN-14-141). A change of the model, of the
  # instructions or of the effort only goes on if the hit rate does not fall from the last run,
  # kept in tmp/ai_evaluation.
  module Evaluation
    Case = Data.define(:name, :profile, :lines, :expected)
    Report = Data.define(:prompt_version, :model, :effort, :results) do
      def fields = results.flat_map { |result| result[:fields] }
      def hits = fields.count { |field| field[:hit] }
      def rate = fields.empty? ? 0.0 : (hits * 100.0 / fields.size).round(1)
      def type_rate = results.empty? ? 0.0 : (results.count { |result| result[:type_hit] } * 100.0 / results.size).round(1)
    end

    NOTICE = "DOCUMENTO FICTÍCIO PARA TESTE — SEM VALOR LEGAL".freeze

    CASES = [
      Case.new(name: "rg", profile: "rg", lines: [
        "REPÚBLICA FEDERATIVA DO BRASIL", "CARTEIRA DE IDENTIDADE", "REGISTRO GERAL: 12.345.678-9",
        "DATA DE EXPEDIÇÃO: 15/03/2015", "NOME: ANA PAULA SOUZA TESTE", "FILIAÇÃO: MARIA SOUZA TESTE E JOSÉ SOUZA TESTE",
        "NATURALIDADE: PORTO ALEGRE - RS", "DATA DE NASCIMENTO: 20/05/1990", "CPF: 529.982.247-25",
        "SECRETARIA DA SEGURANÇA PÚBLICA - SSP/RS"
      ], expected: { "detected_type" => "rg", "name" => "ANA PAULA SOUZA TESTE", "rg_number" => "12.345.678-9",
        "rg_issuer" => "SSP", "rg_state" => "RS", "rg_issued_on" => "2015-03-15", "birth_date" => "1990-05-20",
        "birth_city" => "PORTO ALEGRE", "birth_state" => "RS", "cpf" => "52998224725" }),
      Case.new(name: "cnh", profile: "cnh", lines: [
        "CARTEIRA NACIONAL DE HABILITAÇÃO", "NOME: CARLOS EDUARDO LIMA TESTE", "CPF: 111.444.777-35",
        "DATA NASCIMENTO: 02/11/1985", "Nº REGISTRO: 01234567890", "CAT. HAB.: AB", "VALIDADE: 10/08/2030",
        "1ª HABILITAÇÃO: 05/06/2005", "DATA EMISSÃO: 10/08/2025"
      ], expected: { "detected_type" => "cnh", "name" => "CARLOS EDUARDO LIMA TESTE", "cpf" => "11144477735",
        "birth_date" => "1985-11-02", "cnh_number" => "01234567890", "cnh_category" => "AB", "valid_until" => "2030-08-10",
        "first_license_on" => "2005-06-05", "issued_on" => "2025-08-10" }),
      Case.new(name: "proof_of_address", profile: "proof_of_address", lines: [
        "COMPANHIA DE ENERGIA FICTÍCIA S.A.", "CONTA DE ENERGIA ELÉTRICA", "TITULAR: ANA PAULA SOUZA TESTE",
        "ENDEREÇO: RUA DAS FLORES, 123, APTO 45", "BAIRRO: CENTRO", "CIDADE: CAXIAS DO SUL - RS", "CEP: 95010-000",
        "DATA DE EMISSÃO: 05/10/2026"
      ], expected: { "detected_type" => "proof_of_address", "holder_name" => "ANA PAULA SOUZA TESTE", "street" => "RUA DAS FLORES",
        "street_number" => "123", "complement" => "APTO 45", "district" => "CENTRO", "city" => "CAXIAS DO SUL", "state" => "RS",
        "postal_code" => "95010000", "issued_on" => "2026-10-05" }),
      Case.new(name: "aso", profile: "aso", lines: [
        "ATESTADO DE SAÚDE OCUPACIONAL - ASO", "TIPO DE EXAME: ADMISSIONAL", "EMPREGADO: CARLOS EDUARDO LIMA TESTE",
        "CPF: 111.444.777-35", "RESULTADO: APTO PARA A FUNÇÃO", "DATA DO EXAME: 03/11/2026",
        "MÉDICO: DRA. BEATRIZ FICTÍCIA - CRM/RS 12345"
      ], expected: { "detected_type" => "aso", "name" => "CARLOS EDUARDO LIMA TESTE", "cpf" => "11144477735",
        "aso_result" => "fit", "exam_on" => "2026-11-03" }),
      # A CNH sent as the proof of address: the reading must point the other type (CA-14-002).
      Case.new(name: "cnh_as_proof_of_address", profile: "proof_of_address", lines: [
        "CARTEIRA NACIONAL DE HABILITAÇÃO", "NOME: CARLOS EDUARDO LIMA TESTE", "CPF: 111.444.777-35", "CAT. HAB.: B"
      ], expected: { "detected_type" => "cnh" })
    ].freeze

    module_function

    def pdf(test_case)
      Prawn::Document.new(page_size: "A4", margin: 48) do |document|
        document.fill_color "B00020"
        document.text NOTICE, size: 11, style: :bold
        document.fill_color "000000"
        document.move_down 24
        test_case.lines.each { |line| document.text line, size: 13, leading: 6 }
        document.move_down 24
        document.fill_color "B00020"
        document.text NOTICE, size: 11, style: :bold
      end.render
    end

    def run(cases = CASES, client: Client.new(timeout: Features::DOCUMENT_TIMEOUT))
      results = cases.map do |test_case|
        data = client.structured(system: Prompts::DocumentExtraction::SYSTEM,
          content: Prompts::DocumentExtraction.content(pdf(test_case), test_case.profile, I18n.t("ai.extraction.profiles.#{test_case.profile}")),
          schema: Prompts::DocumentExtraction.schema(test_case.profile), max_tokens: Prompts::DocumentExtraction::MAX_TOKENS,
          effort: Rails.configuration.x.ai_document_effort).data
        score(test_case, data)
      end
      Report.new(prompt_version: Prompts::DocumentExtraction::VERSION, model: Client.model,
        effort: Rails.configuration.x.ai_document_effort, results: results)
    end

    def score(test_case, data)
      fields = Extraction.normalize(data["fields"], test_case.profile).index_by { |field| field["key"] }
      expected = test_case.expected.except("detected_type")
      { name: test_case.name, type_hit: data["detected_type"] == test_case.expected["detected_type"],
        fields: expected.map { |key, value| { key: key, hit: comparable(fields.dig(key, "value")) == comparable(value) } } }
    end

    def comparable(value) = I18n.transliterate(value.to_s).downcase.gsub(/[^a-z0-9]/, "")
  end
end
