module Documents
  # The receipt in PDF of a publication's acknowledgments (RN-08-054, P-08-15, CA-08-007):
  # the document, its hash, the text that the acknowledgment confirms the receipt only
  # (P-08-13), and each person's record: the date and time where they work, the IP, the
  # browser and the comment, or the refusal with the note and the witnesses. Prawn's
  # standard font covers Portuguese; a character outside it becomes "?".
  class AcknowledgmentReceipt
    def initialize(publication, acknowledgments)
      @publication = publication
      @acknowledgments = acknowledgments
    end

    def render
      Prawn::Document.new(page_size: "A4", margin: 40, info: { Title: safe(@publication.title), Producer: "CatalystHR" }) do |pdf|
        header(pdf)
        @acknowledgments.each { |acknowledgment| record(pdf, acknowledgment) }
        pdf.move_down 12
        pdf.text safe(t("generated", date: I18n.l(Time.current, format: "%d/%m/%Y %H:%M"))), size: 8, color: "666666"
      end.render
    end

    private

    def header(pdf)
      pdf.text safe(t("title")), size: 16, style: :bold
      pdf.move_down 6
      pdf.text safe(@publication.company.name), size: 10
      pdf.move_down 10
      line(pdf, t("document"), "#{@publication.title} (#{@publication.document_type.name})")
      line(pdf, t("published", name: @publication.published_by.name), I18n.l(@publication.created_at, format: "%d/%m/%Y %H:%M"))
      line(pdf, t("due_on"), I18n.l(@publication.due_on))
      line(pdf, t("hash"), @acknowledgments.filter_map { |acknowledgment| acknowledgment.version.sha256 }.uniq.join(", ").presence || "-")
      pdf.move_down 6
      pdf.text safe(t("meaning")), size: 9, style: :italic
      pdf.move_down 10
    end

    def record(pdf, acknowledgment)
      profile = acknowledgment.worker_profile
      zone = Time.find_zone(profile.current_unit&.time_zone || "America/Sao_Paulo")
      pdf.stroke_horizontal_rule
      pdf.move_down 6
      pdf.text safe("#{profile.display_name} - #{t("statuses.#{acknowledgment.status}")}"), size: 11, style: :bold
      if acknowledgment.acknowledged?
        line(pdf, t("acknowledged_at"), I18n.l(acknowledgment.acknowledged_at.in_time_zone(zone), format: "%d/%m/%Y %H:%M:%S %Z"))
        line(pdf, t("ip"), acknowledgment.ip.to_s)
        line(pdf, t("user_agent"), acknowledgment.user_agent.to_s)
        line(pdf, t("file_hash"), acknowledgment.sha256.to_s)
        line(pdf, t("comment"), acknowledgment.comment) if acknowledgment.comment
      elsif acknowledgment.refused?
        line(pdf, t("recorded", name: acknowledgment.recorded_by&.name),
          I18n.l(acknowledgment.recorded_at.in_time_zone(zone), format: "%d/%m/%Y %H:%M %Z"))
        line(pdf, t("note"), acknowledgment.refused_note.to_s)
        acknowledgment.witnesses.each_with_index do |witness, index|
          line(pdf, t("witness", number: index + 1), "#{witness["name"]} - CPF #{Cpf.format(witness["cpf"])}")
        end
      end
      pdf.move_down 8
    end

    def line(pdf, label, value)
      pdf.text "<b>#{escape(label)}:</b> #{escape(value)}", size: 9, inline_format: true
    end

    def escape(text)
      ERB::Util.html_escape(safe(text.to_s))
    end

    # Prawn's standard fonts write Windows-1252 only.
    def safe(text)
      text.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?").encode("UTF-8")
    end

    def t(key, **options)
      I18n.t("documents.receipt.#{key}", **options)
    end
  end
end
