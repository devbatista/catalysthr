module Documents
  # The PDF of a contract or term (RN-07-041, D-263), with Prawn, from the text's simple
  # markup: "# " and "## " for titles, **bold**, *italic*, "- " and "1. " for lists, and "|"
  # for simple tables. Values go in after the markup is read, so what a person typed never
  # becomes formatting. Only the company's text: no mark of the platform. A blank value
  # becomes a line to fill in by hand, once the HR confirms (RN-07-042). Prawn's standard
  # font has no character outside Windows-1252, so those are refused before (D-650).
  class ContractPdf
    BLANK = "____________________".freeze
    SIZE = 11

    # The characters the font doesn't have.
    def self.unsupported(text)
      text.to_s.each_char.uniq.reject do |char|
        char == "\n" || char.encode(Encoding::Windows_1252)
      rescue EncodingError
        false
      end
    end

    def initialize(title:, body:, values:)
      @title = title
      @body = body
      @values = values
    end

    def render
      Prawn::Document.new(page_size: "A4", margin: 56, info: { Title: @title, Producer: "CatalystHR" }) do |pdf|
        pdf.font_size SIZE
        blocks.each { |type, content| draw(pdf, type, content) }
        pdf.number_pages "<page> / <total>", at: [ pdf.bounds.right - 60, -10 ], width: 60, align: :right, size: 8
      end.render
    end

    private

    # [[:h1, text], [:paragraph, text], [:bullets, [...]], [:numbers, [...]], [:table, [[...]]]]
    def blocks
      list = []
      @body.to_s.split("\n").each do |line|
        text = line.strip
        case text
        when "" then list << [ :gap, nil ]
        when /\A## (.+)/ then list << [ :h2, $1 ]
        when /\A# (.+)/ then list << [ :h1, $1 ]
        when /\A[-*] (.+)/ then append(list, :bullets, $1)
        when /\A\d+\. (.+)/ then append(list, :numbers, $1)
        when /\A\|[\s:|-]+\|\z/ then next
        when /\A\|(.+)\|\z/ then append(list, :table, $1.split("|").map(&:strip))
        else
          list.last&.first == :paragraph ? list.last[1] += " #{text}" : list << [ :paragraph, text ]
        end
      end
      list
    end

    def append(list, type, item)
      list.last&.first == type ? list.last[1] << item : list << [ type, [ item ] ]
    end

    def draw(pdf, type, content)
      case type
      when :gap then pdf.move_down 6
      when :h1 then heading(pdf, content, 15)
      when :h2 then heading(pdf, content, 12)
      when :paragraph then pdf.text inline(content), inline_format: true, align: :justify, leading: 2
      when :bullets then items(pdf, content) { "•" }
      when :numbers then items(pdf, content) { |index| "#{index + 1}." }
      when :table then table(pdf, content)
      end
    end

    def heading(pdf, text, size)
      pdf.move_down 6
      pdf.text inline(text), inline_format: true, size: size, style: :bold
      pdf.move_down 4
    end

    def items(pdf, list)
      list.each_with_index do |item, index|
        top = pdf.cursor
        pdf.text_box yield(index), at: [ 0, top ], width: 20, height: 14
        pdf.indent(20) { pdf.text inline(item), inline_format: true, leading: 2 }
        pdf.move_down 2
      end
    end

    # Prawn has no table without another gem, and D-648 asks for none: each row is measured
    # and drawn, moving to the next page when it doesn't fit.
    def table(pdf, rows)
      columns = rows.map(&:size).max
      width = pdf.bounds.width / columns
      rows.each do |row|
        cells = Array.new(columns) { |index| inline(row[index].to_s) }
        height = cells.map { |cell| pdf.height_of(cell, width: width - 10, inline_format: true) }.max + 10
        pdf.start_new_page if pdf.cursor < height
        top = pdf.cursor
        cells.each_with_index do |cell, index|
          left = index * width
          pdf.stroke_rectangle [ left, top ], width, height
          pdf.text_box cell, at: [ left + 5, top - 5 ], width: width - 10, height: height - 10, inline_format: true
        end
        pdf.move_cursor_to top - height
      end
      pdf.move_down 6
    end

    def inline(text)
      escaped(text).gsub(/\*\*(.+?)\*\*/, '<b>\1</b>').gsub(/\*(.+?)\*/, '<i>\1</i>').gsub(TemplateVariables::PATTERN) do
        value = @values[$1].to_s
        value.empty? ? BLANK : escaped(value)
      end
    end

    def escaped(text)
      text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end
  end
end
