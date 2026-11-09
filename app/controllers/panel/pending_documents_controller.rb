module Panel
  # "Documentos pendentes", opened by the HR panel's indicator (RN-17-010, D-658): the
  # versions waiting for the review and the people of a request without any version sent,
  # in two tabs whose total is the indicator's number (CA-17-001).
  class PendingDocumentsController < BaseController
    include DashboardLists

    TABS = %w[review requests].freeze

    def index
      authorize! :review, Document
      panel = dashboard_panel
      @tab = params[:tab].presence_in(TABS) || "review"
      versions = panel.versions_in_review
      requests = panel.unanswered_requests
      @counts = { "review" => versions.count, "requests" => requests.count }
      @late = panel.late_requests.count
      @today = @filter.today
      if @tab == "review"
        @versions = versions.includes(:uploaded_by, document: [ :document_type, :dependent, :bank_account, { worker_profile: :user } ])
          .order(:uploaded_at, :id).limit(DashboardLists::LIMIT).to_a
      else
        @targets = requests.includes(:request, document: [ :document_type, :dependent ], worker_profile: :user)
          .joins(:request).order(Arel.sql("document_requests.due_on ASC NULLS LAST"), :id).limit(DashboardLists::LIMIT).to_a
      end
    end
  end
end
