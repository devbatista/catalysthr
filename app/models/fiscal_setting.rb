# What goes on every NFS-e the platform sends to Asaas (spec 19, RN-19-102, D-632, D-633),
# kept by the superadmin and the finance team. The Asaas account's own setup (certificate
# or portal login, DPS series, regime, municipal registration) stays in Asaas's panel, so
# no credential passes through the platform. One row; `current` is it, or a new one with
# the accountant's values of D-632 to start from.
class FiscalSetting < ApplicationRecord
  audited

  RATES = %i[pis_rate cofins_rate csll_rate inss_rate ir_rate].freeze
  # Asaas takes the NBS with its dots ("1.1506.21.00"); without them it refuses it.
  NBS_FORMAT = /\A\d\.\d{4}\.\d{2}\.\d{2}\z/
  DEFAULTS = {
    service_name: "Licenciamento ou cessão de direito de uso de programas de computação",
    nbs_code: "1.1506.21.00",
    operation_indicator_code: "100501",
    description: "Licenciamento de software CatalystHR por assinatura",
    observations: "Documento emitido por ME ou EPP optante pelo Simples Nacional."
  }.freeze

  belongs_to :updated_by, class_name: "User"

  normalizes :service_code, :service_name, :nbs_code, :operation_indicator_code, with: ->(value) { value.to_s.strip }
  normalizes :description, :observations, with: ->(value) { value.to_s.strip }

  validates :service_code, :service_name, :description, :observations, presence: true
  validates :service_code, length: { maximum: 20 }
  validates :service_name, length: { maximum: 255 }
  validates :nbs_code, format: { with: NBS_FORMAT }
  validates :operation_indicator_code, format: { with: /\A\d{6}\z/ }
  validates(*RATES, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 })

  def self.current
    first || new(DEFAULTS)
  end
end
