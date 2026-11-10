module Ai
  # The AI functions (spec 14, section 4.2, D-389, D-390), with the credits of the spec's table
  # (P-14-05) and the time limit of each call (RN-14-122, P-14-30). The CatalystHR team changes a
  # weight from a date on (AiCreditWeight); until then, the table's holds. Only the functions
  # already built show on the company's settings: the others come with their specs.
  module Features
    Feature = Data.define(:code, :credits, :unit, :timeout) do
      # Credits for a quantity: per call, or one per block of 10 pages (material_ocr).
      def credits_for(quantity, weight: credits)
        unit == "page_block" ? weight * (quantity.to_f / PAGE_BLOCK).ceil : weight * quantity
      end
    end

    PAGE_BLOCK = 10
    DOCUMENT_TIMEOUT = 120
    TIMEOUT = 60

    ALL = [
      Feature.new("document_extraction", 1, "request", DOCUMENT_TIMEOUT),
      Feature.new("batch_classification", 1, "request", DOCUMENT_TIMEOUT),
      Feature.new("guide_reading", 1, "request", DOCUMENT_TIMEOUT),
      Feature.new("esocial_explanation", 1, "request", TIMEOUT),
      Feature.new("operational_summary", 1, "request", TIMEOUT),
      Feature.new("assistant", 1, "request", TIMEOUT),
      Feature.new("material_ocr", 1, "page_block", DOCUMENT_TIMEOUT),
      Feature.new("writing", 1, "request", TIMEOUT),
      Feature.new("recruitment", 1, "request", TIMEOUT),
      Feature.new("performance", 1, "request", TIMEOUT)
    ].index_by(&:code).freeze

    # The functions of spec 14's first part (D-670); each new one is added here with its spec.
    BUILT = %w[document_extraction batch_classification].freeze

    module_function

    def find(code) = ALL.fetch(code.to_s)
    def built = BUILT.map { |code| ALL.fetch(code) }
    def codes = ALL.keys
  end
end
