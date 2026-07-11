class CreateIdeaNodes < ActiveRecord::Migration[8.1]
  def change
    # The typed idea graph — nodes extracted from interview answers. Distinct
    # from message_nodes (the conversation): these are the *content* the
    # linearizer orders into an outline. parent_id gives the nested-list view.
    create_table :idea_nodes do |t|
      t.references :idea, null: false, foreign_key: true
      t.integer    :node_type, null: false   # claim / example / question / counterpoint / reference / hook
      t.text       :body, null: false        # the user's own words, extracted verbatim
      t.integer    :status, null: false, default: 0   # settled / open (open = unanswered question)
      t.references :parent, foreign_key: { to_table: :idea_nodes }   # nesting for the outline
      t.integer    :position, null: false, default: 0
      t.string     :source_message_hash, limit: 64   # provenance: which answer this came from
      t.timestamps
    end

    add_index :idea_nodes, [ :idea_id, :position ]
    add_index :idea_nodes, [ :idea_id, :node_type ]
    add_foreign_key :idea_nodes, :message_nodes, column: :source_message_hash, primary_key: :content_hash, on_delete: :nullify
  end
end
