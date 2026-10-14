require "rails_helper"

RSpec.describe SentryScrubber do
  describe ".mask" do
    it "masks CPF with and without punctuation" do
      expect(described_class.mask("CPF 123.456.789-09 e 12345678909")).to eq("CPF [cpf] e [cpf]")
    end

    it "masks e-mail addresses" do
      expect(described_class.mask("falha ao enviar para ana@empresa.com.br")).to eq("falha ao enviar para [email]")
    end

    it "masks Brazilian phone numbers" do
      expect(described_class.mask("celular (54) 99876-5432")).to eq("celular [telefone]")
    end

    it "keeps text without personal data" do
      expect(described_class.mask("Company 42 not found")).to eq("Company 42 not found")
    end
  end

  describe ".scrub" do
    it "masks the message, exception values and extra data of an event" do
      event = Sentry::Event.new(configuration: Sentry::Configuration.new)
      event.message = "erro para 123.456.789-09"
      event.extra = { "contato" => [ "ana@empresa.com.br" ] }

      described_class.scrub(event)

      expect(event.message).to eq("erro para [cpf]")
      expect(event.extra).to eq({ "contato" => [ "[email]" ] })
    end

    it "masks the exception message of an error event" do
      configuration = Sentry::Configuration.new
      event = Sentry::ErrorEvent.new(configuration: configuration)
      event.add_exception_interface(
        RuntimeError.new("CPF 123.456.789-09 já cadastrado"),
        mechanism: Sentry::Mechanism.new(type: "generic", handled: true)
      )

      described_class.scrub(event)

      value = event.exception.values.first.value
      expect(value).to start_with("CPF [cpf] já cadastrado")
      expect(value).not_to include("123.456.789-09")
    end
  end
end
