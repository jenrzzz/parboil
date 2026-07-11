class CreateMessageNodes < ActiveRecord::Migration[8.1]
  def change
    # The interview conversation as a content-addressed immutable DAG (hob's
    # conversation plane, lifted from kat's MessageNode). Scoped to one idea:
    # parboil has exactly one interview per idea, so hob's Conversation table
    # collapses into the idea's head_hash pointer.
    create_table :message_nodes, id: false do |t|
      t.string     :content_hash, limit: 64, null: false, primary_key: true
      t.string     :parent_hash, limit: 64
      t.references :idea, null: false, foreign_key: true, index: false
      t.integer    :role, null: false, default: 0   # user / interviewer / system
      t.string     :speaker_name
      t.text       :content, null: false
      t.datetime   :created_at, null: false          # immutable: no updated_at
    end

    add_index :message_nodes, [ :idea_id, :created_at ]
    add_index :message_nodes, :parent_hash
    add_foreign_key :message_nodes, :message_nodes, column: :parent_hash, primary_key: :content_hash, on_delete: :nullify
  end
end
