module Admissions
  # "Concluir admissão" (RN-07-080 to RN-07-083, D-260, D-648, D-651): says what's missing and,
  # with nothing, ends the admission, deletes the PDFs generated, which live only in the
  # process, and starts the onboarding of the model (RN-07-082).
  class Conclusion
    def initialize(admission, by:, starter:)
      @admission = admission
      @by = by
      @starter = starter
      @instance = admission.process_instance
      @employment = admission.employment
    end

    # What stops it, for the screen (CA-07-006).
    def blockers
      list = []
      list << :rejected if @instance.items.any?(&:rejected?)
      list << :items unless @instance.required_resolved?
      list << :aso if @employment.clt? && !@admission.aso_fit?
      list << :salary if salary_missing?
      list << :esocial if esocial_missing?
      list
    end

    def call
      done = @admission.with_lock do
        next false unless @admission.open? && blockers.empty?
        next false unless Processes::Complete.call(@instance, by: @by)

        @admission.update!(completed_at: Time.current, completed_by: @by)
        Admissions.delete_generated(@employment)
        start_onboarding
        true
      end
      done
    end

    private

    def salary_missing?
      revision = @employment.effective_revision
      revision.nil? || (!revision.paid_by_variable_only? && revision.salary_cents.nil?)
    end

    # Off until spec 13: the sending happens outside the system (D-648).
    def esocial_missing?
      FeatureFlags.enabled?(FeatureFlags::ESOCIAL) && !@admission.esocial_status.in?(%w[not_applicable sent accepted rejected])
    end

    # Ends by itself once its required items are done (RN-07-112, P-07-16).
    def start_onboarding
      template = @instance.template&.onboarding_template
      return unless template&.active?

      Processes::Start.call(template: template, employment: @employment, started_by: @by, starter: @starter,
        anchors: { "work_start" => @employment.started_on }, completion_mode: "automatic")
    end
  end
end
