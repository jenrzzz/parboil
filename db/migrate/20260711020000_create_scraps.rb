class CreateScraps < ActiveRecord::Migration[8.1]
  def change
    # Raw material the writer drops into an idea — pasted text or a URL.
    # Context for the interviewer (hob's "surface context" stage), never
    # extracted as the writer's own claims. Mutable, unlike the interview DAG.
    create_table :scraps do |t|
      t.references :idea, null: false, foreign_key: true
      t.integer :kind, null: false, default: 0   # paste / link
      t.string  :url
      t.string  :title
      t.text    :body                             # pasted text, or fetched page text (nil = fetch failed)
      t.timestamps
    end

    add_index :scraps, [ :idea_id, :created_at ]
  end
end
