# The AI's pills (spec 14, RN-14-114, D-670).
module AiHelper
  def ai_cap_pill(cap)
    key, style = if cap.paused? then %w[paused pill-bad]
    elsif cap.released? then %w[released pill-info]
    else %w[active pill-ok]
    end
    tag.span(t("admin.ai.caps.#{key}"), class: "pill #{style}", data: { ai_cap_status: key })
  end
end
