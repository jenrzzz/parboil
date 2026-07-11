class CreateIdeas < ActiveRecord::Migration[8.1]
  def change
    create_table :ideas do |t|
      t.string  :title                    # derived during the interview; nil at seed time
      t.text    :seed, null: false        # the itch, in the user's own words
      t.integer :status, null: false, default: 0   # seeded / interviewing / ripe
      t.string  :head_hash, limit: 64     # current head of the interview DAG (single-branch pointer)
      t.timestamps
    end

    add_index :ideas, :status
    add_index :ideas, :updated_at
  end
end
