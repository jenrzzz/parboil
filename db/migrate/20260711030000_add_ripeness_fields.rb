class AddRipenessFields < ActiveRecord::Migration[8.1]
  def change
    # Both captured by the extractor from the writer's own words, never
    # invented: the thesis is a claim the writer flagged by stating their core
    # position; the audience is stored when the writer names who it's for.
    add_column :ideas, :audience, :string
    add_column :idea_nodes, :thesis, :boolean, null: false, default: false
  end
end
