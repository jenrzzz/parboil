class CreateLLMUsages < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_usages do |t|
      t.string  :operation, null: false
      t.string  :role                        # hob-style model role, when the call went through the gateway
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
    end

    add_index :llm_usages, [ :operation, :created_at ]
    add_index :llm_usages, [ :role, :created_at ]
  end
end
