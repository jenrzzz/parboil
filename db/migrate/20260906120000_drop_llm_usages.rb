# The usage ledger moved to hob (GET /v1/usage). Nothing read prompt/response
# back; the rows were one person's interview spend, not worth carrying over.
class DropLLMUsages < ActiveRecord::Migration[8.1]
  def change
    drop_table :llm_usages do |t|
      t.string  :operation, null: false
      t.string  :role
      t.string  :model, null: false
      t.integer :input_tokens,  null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.decimal :cost, precision: 10, scale: 6
      t.integer :duration_ms
      t.string  :status, null: false
      t.jsonb   :metadata, default: {}
      t.text    :error_message
      t.text    :prompt
      t.text    :response
      t.timestamps
      t.index [ :operation, :created_at ]
      t.index [ :role, :created_at ]
    end
  end
end
