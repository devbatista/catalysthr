# The evaluation set of the documents' reading (spec 14, RN-14-140, D-670). Calls the API with
# fictitious documents and uses the Anthropic's credits, so it runs only by hand, with the key:
#
#   ANTHROPIC_API_KEY=... bin/rails ai:evaluate
#
# It prints the hit rate by field and compares it with the last run in tmp/ai_evaluation.
namespace :ai do
  desc "Runs the evaluation set of the documents' reading against the API (spends credits)"
  task evaluate: :environment do
    abort "Defina ANTHROPIC_API_KEY para rodar a avaliação." unless Ai::Client.configured?

    report = Ai::Evaluation.run
    report.results.each do |result|
      misses = result[:fields].reject { |field| field[:hit] }.map { |field| field[:key] }
      puts format("%-26s tipo %-4s campos %d/%d %s", result[:name], result[:type_hit] ? "ok" : "erro",
        result[:fields].count { |field| field[:hit] }, result[:fields].size, misses.any? ? "(erros: #{misses.join(", ")})" : "")
    end
    puts "Acerto: #{report.rate}% dos campos, #{report.type_rate}% dos tipos (#{report.prompt_version}, #{report.model}, effort #{report.effort})"

    directory = Rails.root.join("tmp/ai_evaluation")
    FileUtils.mkdir_p(directory)
    last = directory.glob("*.json").max_by(&:mtime)
    if last
      previous = JSON.parse(last.read)
      verdict = report.rate >= previous["rate"] && report.type_rate >= previous["type_rate"] ? "pode seguir" : "NÃO siga: a taxa caiu"
      puts "Última: #{previous["rate"]}% dos campos, #{previous["type_rate"]}% dos tipos (#{previous["prompt_version"]}). #{verdict}."
    end
    directory.join("#{Time.current.strftime("%Y%m%d%H%M%S")}.json").write({ rate: report.rate, type_rate: report.type_rate,
      prompt_version: report.prompt_version, model: report.model, effort: report.effort }.to_json)
  end
end
