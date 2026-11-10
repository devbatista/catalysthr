module Exports
  # What the company's full export carries (RN-18-072, P-18-21, D-661, D-667): the company's
  # registrations, people, employments and revisions, users and roles, documents and versions,
  # processes, admissions, notices, acknowledgments, consents, the imports' history and the
  # audit trail. What the system does not have yet (requests, time tracking, payroll, eSocial)
  # comes with its module (D-661).
  #
  # Out, as the platform's own records (D-667): secrets (passwords, MFA, passkeys, tokens),
  # sessions, devices, push, notifications, virus scans, the AI's embeddings, the billing
  # (contract, invoices, payments, NFS-e), the brand, the transfers, the other exports and the
  # imports' lines, which are temporary (RN-18-010). The encrypted fields leave readable,
  # because the ZIP has a password (RN-18-075).
  module CompanyContents
    # Never in the export, whatever the table (RN-18-072).
    SECRET_COLUMN = /password|token|otp|secret|digest|webauthn|timestep/

    # One table of the export: its name in dados/, and the records of the company.
    Entity = Data.define(:name, :description, :scope, :only) do
      def initialize(only: nil, **fields) = super(only: only, **fields)

      def relation(company) = scope.call(company)

      def columns(model)
        names = only || model.column_names
        names.reject { |column| column.match?(SECRET_COLUMN) }
      end
    end

    def self.by_company(model)
      ->(company) { model.unscoped.where(company_id: company.id) }
    end

    # Kept documents only: the deleted ones wait for their 30 days of recovery and leave
    # (RN-08-083).
    KEPT_DOCUMENTS = ->(company) { Document.unscoped.where(company_id: company.id, deleted_at: nil) }

    ENTITIES = [
      Entity.new(name: "empresa", description: "Dados cadastrais da empresa", scope: ->(company) { Company.unscoped.where(id: company.id) }),
      Entity.new(name: "unidades", description: "Unidades (estabelecimentos)", scope: by_company(Unit)),
      Entity.new(name: "feriados_das_unidades", description: "Feriados e pontos facultativos das unidades", scope: by_company(UnitHoliday)),
      Entity.new(name: "departamentos", description: "Departamentos", scope: by_company(Department)),
      Entity.new(name: "gestores_dos_departamentos", description: "Gestores de cada departamento", scope: by_company(DepartmentManager)),
      Entity.new(name: "cargos", description: "Cargos, com o CBO", scope: by_company(Position)),
      Entity.new(name: "documentos_exigidos_por_cargo", description: "Documentos exigidos por cargo", scope: by_company(PositionRequiredDocumentType)),
      Entity.new(name: "vencimentos_por_cargo", description: "Periodicidade dos documentos por cargo", scope: by_company(PositionDocumentExpiration)),
      Entity.new(name: "clientes_de_alocacao", description: "Clientes de alocação", scope: by_company(AllocationClient)),
      Entity.new(name: "gestores_dos_clientes", description: "Gestores dos clientes de alocação", scope: by_company(AllocationClientManager)),
      Entity.new(name: "campos_personalizados", description: "Campos personalizados da ficha", scope: by_company(CustomFieldDefinition)),
      Entity.new(name: "tipos_de_documento", description: "Tipos de documento da empresa", scope: by_company(DocumentType)),
      Entity.new(name: "configuracao_dos_tipos_de_documento", description: "Ajustes da empresa nos tipos de documento", scope: by_company(CompanyDocumentTypeSetting)),
      Entity.new(name: "usuarios", description: "Pessoas com acesso à empresa, sem senha, MFA nem passkeys",
        scope: ->(company) { User.unscoped.where(id: Membership.unscoped.where(organization: company).select(:user_id)) },
        only: %w[id name cpf email mobile_phone birth_date status created_at updated_at]),
      Entity.new(name: "perfis_de_acesso", description: "Perfis de cada pessoa na empresa", scope: ->(company) { Membership.unscoped.where(organization: company) }),
      Entity.new(name: "unidades_dos_perfis", description: "Unidades de cada perfil", scope: by_company(MembershipUnit)),
      Entity.new(name: "fichas", description: "Fichas dos colaboradores", scope: by_company(WorkerProfile)),
      Entity.new(name: "dependentes", description: "Dependentes", scope: by_company(Dependent)),
      Entity.new(name: "contatos_de_emergencia", description: "Contatos de emergência", scope: by_company(EmergencyContact)),
      Entity.new(name: "contas_bancarias", description: "Contas bancárias e chaves PIX", scope: by_company(BankAccount)),
      Entity.new(name: "vinculos", description: "Vínculos", scope: by_company(Employment)),
      Entity.new(name: "revisoes_dos_vinculos", description: "Revisões dos vínculos, com vigência e motivo", scope: by_company(EmploymentRevision)),
      Entity.new(name: "admissoes", description: "Admissões", scope: by_company(Admission)),
      Entity.new(name: "documentos", description: "Documentos dos colaboradores", scope: KEPT_DOCUMENTS),
      Entity.new(name: "versoes_dos_documentos", description: "Versões de cada documento",
        scope: ->(company) { DocumentVersion.unscoped.where(company_id: company.id, document_id: KEPT_DOCUMENTS.call(company).select(:id)) }),
      Entity.new(name: "pedidos_de_documento", description: "Pedidos de documento", scope: by_company(DocumentRequest)),
      Entity.new(name: "destinatarios_dos_pedidos", description: "Destinatários dos pedidos de documento", scope: by_company(DocumentRequestTarget)),
      Entity.new(name: "lotes_de_documentos", description: "Lotes de documentos", scope: by_company(DocumentBatch)),
      Entity.new(name: "itens_dos_lotes", description: "Itens dos lotes de documentos", scope: by_company(DocumentBatchItem)),
      Entity.new(name: "publicacoes_de_documentos", description: "Documentos publicados para ciência", scope: by_company(DocumentPublication)),
      Entity.new(name: "ciencias", description: "Ciências e recusas dos documentos", scope: by_company(Acknowledgment)),
      Entity.new(name: "modelos_de_documento", description: "Modelos de contratos e termos", scope: by_company(DocumentTemplate)),
      Entity.new(name: "documentos_gerados", description: "Documentos gerados pelos modelos", scope: by_company(GeneratedDocument)),
      Entity.new(name: "modelos_de_processo", description: "Modelos de processo da empresa", scope: by_company(ProcessTemplate)),
      Entity.new(name: "itens_dos_modelos_de_processo", description: "Itens dos modelos de processo", scope: by_company(ProcessTemplateItem)),
      Entity.new(name: "materiais_dos_modelos_de_processo", description: "Materiais dos modelos de processo", scope: by_company(ProcessTemplateMaterial)),
      Entity.new(name: "processos", description: "Processos (admissão, integração e outros)", scope: by_company(ProcessInstance)),
      Entity.new(name: "itens_dos_processos", description: "Itens dos processos", scope: by_company(ProcessItem)),
      Entity.new(name: "dependencias_dos_itens", description: "Dependências entre os itens dos processos", scope: by_company(ProcessItemDependency)),
      Entity.new(name: "respostas_dos_formularios", description: "Respostas dos formulários dos processos", scope: by_company(ProcessFormResponse)),
      Entity.new(name: "historico_dos_processos", description: "Histórico dos processos", scope: by_company(ProcessEvent)),
      Entity.new(name: "comunicados", description: "Comunicados do mural", scope: by_company(Announcement)),
      Entity.new(name: "leituras_dos_comunicados", description: "Quem abriu cada comunicado", scope: by_company(AnnouncementRead)),
      Entity.new(name: "consentimentos", description: "Consentimentos dados à empresa", scope: ->(company) { Consent.unscoped.where(scope: company) }),
      Entity.new(name: "importacoes", description: "Histórico das importações, com as contagens e sem os dados", scope: by_company(DataImport)),
      Entity.new(name: "autorizacoes_de_importacao_assistida", description: "Autorizações da importação assistida", scope: by_company(AssistedImportAuthorization)),
      Entity.new(name: "auditoria_alteracoes", description: "Trilha de alterações (sem os valores dos campos sensíveis)", scope: by_company(PaperTrail::Version)),
      Entity.new(name: "auditoria_acessos", description: "Eventos de acesso a dados sensíveis, downloads e exportações", scope: by_company(AccessEvent)),
      Entity.new(name: "auditoria_atividades", description: "Atividade recente da empresa", scope: by_company(ActivityEvent))
    ].freeze
  end
end
