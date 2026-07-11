# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_11_010300) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "idea_nodes", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "idea_id", null: false
    t.integer "node_type", null: false
    t.bigint "parent_id"
    t.integer "position", default: 0, null: false
    t.string "source_message_hash", limit: 64
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["idea_id", "node_type"], name: "index_idea_nodes_on_idea_id_and_node_type"
    t.index ["idea_id", "position"], name: "index_idea_nodes_on_idea_id_and_position"
    t.index ["idea_id"], name: "index_idea_nodes_on_idea_id"
    t.index ["parent_id"], name: "index_idea_nodes_on_parent_id"
  end

  create_table "ideas", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "head_hash", limit: 64
    t.text "seed", null: false
    t.integer "status", default: 0, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_ideas_on_status"
    t.index ["updated_at"], name: "index_ideas_on_updated_at"
  end

  create_table "llm_usages", force: :cascade do |t|
    t.decimal "cost", precision: 10, scale: 6
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.text "error_message"
    t.integer "input_tokens", default: 0, null: false
    t.jsonb "metadata", default: {}
    t.string "model", null: false
    t.string "operation", null: false
    t.integer "output_tokens", default: 0, null: false
    t.text "prompt"
    t.text "response"
    t.string "role"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["operation", "created_at"], name: "index_llm_usages_on_operation_and_created_at"
    t.index ["role", "created_at"], name: "index_llm_usages_on_role_and_created_at"
  end

  create_table "message_nodes", primary_key: "content_hash", id: { type: :string, limit: 64 }, force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.bigint "idea_id", null: false
    t.string "parent_hash", limit: 64
    t.integer "role", default: 0, null: false
    t.string "speaker_name"
    t.index ["idea_id", "created_at"], name: "index_message_nodes_on_idea_id_and_created_at"
    t.index ["parent_hash"], name: "index_message_nodes_on_parent_hash"
  end

  add_foreign_key "idea_nodes", "idea_nodes", column: "parent_id"
  add_foreign_key "idea_nodes", "ideas"
  add_foreign_key "idea_nodes", "message_nodes", column: "source_message_hash", primary_key: "content_hash", on_delete: :nullify
  add_foreign_key "message_nodes", "ideas"
  add_foreign_key "message_nodes", "message_nodes", column: "parent_hash", primary_key: "content_hash", on_delete: :nullify
end
