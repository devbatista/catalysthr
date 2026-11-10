module Documents
  # The person of a batch's file, found by the system and never by the AI (spec 14, RN-14-031,
  # P-14-09, D-672), only among the people of the scope of who sent the batch, with an open
  # employment, as on the screen's choice. A valid CPF read that is one of them is the
  # suggestion; without it, the names alike, by PostgreSQL's text similarity (pg_trgm), without
  # accents nor case, with the score. The people's list never goes to the AI: the AI only read
  # the name and the CPF from the file.
  class BatchPerson
    Result = Data.define(:match, :profile, :score, :candidates)

    # The lowest score that counts as alike (pg_trgm's own default) and how many are shown.
    MIN_SCORE = 0.3
    MAX_CANDIDATES = 5

    def self.call(...) = new(...).call

    def initialize(ability:, cpf:, name:)
      @ability = ability
      @cpf = Cpf.normalize(cpf)
      @name = name.to_s.squish.first(200).presence
    end

    def call
      by_cpf || by_name || Result.new(match: "none", profile: nil, score: nil, candidates: [])
    end

    private

    def scope
      WorkerProfile.accessible_by(@ability, :read).where(id: Employment.open.select(:worker_profile_id))
    end

    # A person outside the scope with the CPF is not said to exist (RN-03-006).
    def by_cpf
      return unless @cpf.present? && Cpf.valid?(@cpf)

      user = User.find_by(cpf: @cpf) or return
      profile = scope.joins(:membership).find_by(memberships: { user_id: user.id }) or return
      Result.new(match: "cpf", profile: profile, score: 1.0, candidates: [])
    end

    def by_name
      return if @name.nil?

      score = WorkerProfile.sanitize_sql_array([ <<~SQL.squish, @name, @name ])
        GREATEST(similarity(lower(unaccent(users.name)), lower(unaccent(?))),
          COALESCE(similarity(lower(unaccent(worker_profiles.social_name)), lower(unaccent(?))), 0))
      SQL
      rows = scope.joins(:user).where("#{score} >= ?", MIN_SCORE)
        .order(Arel.sql("#{score} DESC"), :id).limit(MAX_CANDIDATES).pluck(:id, Arel.sql(score))
      return if rows.empty?

      candidates = rows.map { |id, value| { "id" => id, "score" => value.to_f.round(3) } }
      Result.new(match: "name", profile: nil, score: candidates.first["score"], candidates: candidates)
    end
  end
end
