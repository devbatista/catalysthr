# Block 14a of spec 14 (D-670): the base of every AI function. The calls are recorded without
# their content (RN-14-131); the credits go to a ledger by contract that feeds the month's usage
# (RN-14-110, RN-14-111); each company has its functions turned on or off (RN-14-010) and a daily
# safety cap (RN-14-114).
class CreateAiBase < ActiveRecord::Migration[8.1]
  def change
    # A function turned off by the HR administrator; without a row, it is on (RN-14-011).
    create_table :company_ai_settings, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: false
      t.string :feature, null: false
      t.boolean :enabled, null: false, default: true
      t.references :updated_by, type: :uuid, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :company_ai_settings, %i[company_id feature], unique: true

    # The weights the CatalystHR team changes, with the date they start; before the first one,
    # the weight of the spec's table holds (RN-14-110, P-14-05).
    create_table :ai_credit_weights, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :feature, null: false
      t.integer :credits, null: false
      t.string :unit, null: false, default: "request"
      t.date :valid_from, null: false
      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :ai_credit_weights, %i[feature valid_from], unique: true

    # Each call to Claude or to Voyage, without the content sent nor the raw answer
    # (RN-14-131, CA-14-014). Without a company, the call is the platform's.
    create_table :ai_requests, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, foreign_key: true, index: false
      t.references :user, type: :uuid, foreign_key: true
      t.string :feature, null: false
      t.string :provider, null: false, default: "anthropic"
      t.string :model, null: false
      t.string :prompt_version
      t.string :subject_type
      t.uuid :subject_id
      t.string :status, null: false
      t.integer :attempt, null: false, default: 1
      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.integer :cache_read_tokens, null: false, default: 0
      t.integer :cache_write_tokens, null: false, default: 0
      t.bigint :cost_usd_micros, null: false, default: 0
      t.integer :credits, null: false, default: 0
      t.integer :latency_ms
      t.string :provider_request_id
      t.string :error_code
      t.datetime :created_at, null: false
    end
    add_index :ai_requests, %i[company_id created_at]
    add_index :ai_requests, %i[subject_type subject_id]
    add_index :ai_requests, %i[provider created_at]

    # The credits by contract: the base of the quota and of the excess (RN-14-111, D-384).
    create_table :ai_credit_entries, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :billing_account, type: :uuid, foreign_key: true, index: false
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :ai_request, type: :uuid, foreign_key: true, index: { unique: true }
      t.string :period, null: false
      t.integer :credits, null: false
      t.string :kind, null: false, default: "usage"
      t.datetime :created_at, null: false
    end
    add_index :ai_credit_entries, %i[billing_account_id period]
    add_index :ai_credit_entries, %i[company_id created_at]

    # The company's day against its safety cap (RN-14-114, D-395).
    create_table :ai_daily_caps, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: false
      t.date :date, null: false
      t.integer :cap_credits, null: false
      t.integer :used_credits, null: false, default: 0
      t.datetime :paused_at
      t.datetime :released_at
      t.references :released_by, type: :uuid, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :ai_daily_caps, %i[company_id date], unique: true

    # The cap the CatalystHR team sets for the company, in place of the computed one.
    add_column :companies, :ai_daily_cap_credits, :integer
    # The quota's 80% and 100% notices, once each in the month (RN-14-112).
    add_column :usage_periods, :ai_alerted_percent, :integer
  end
end
