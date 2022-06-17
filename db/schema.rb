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

ActiveRecord::Schema.define(version: 2022_04_10_100652) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "assistants_course_instances", id: false, force: :cascade do |t|
    t.integer "user_id"
    t.integer "course_instance_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", limit: 255
    t.integer "position", default: 0
    t.float "weight", default: 1.0
    t.integer "exercise_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "course_instances", force: :cascade do |t|
    t.integer "course_id"
    t.string "name", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.boolean "active", default: true
    t.string "locale", limit: 255
    t.string "submission_policy", limit: 255
    t.string "feedback_delivery_mode", limit: 255
    t.integer "pricing_id"
    t.string "lti_consumer", limit: 255
    t.string "lti_context_id", limit: 255
    t.string "lti_resource_link_id", limit: 255
    t.index ["lti_consumer", "lti_context_id"], name: "index_course_instances_on_lti_consumer_and_lti_context_id"
  end

  create_table "course_instances_students", id: false, force: :cascade do |t|
    t.integer "user_id"
    t.integer "course_instance_id"
  end

  create_table "courses", force: :cascade do |t|
    t.string "code", limit: 255
    t.string "name", limit: 255
    t.string "css", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email", limit: 255
    t.integer "organization_id"
    t.string "time_zone", limit: 255
  end

  create_table "courses_teachers", id: false, force: :cascade do |t|
    t.integer "user_id"
    t.integer "course_id"
  end

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer "priority", default: 0
    t.integer "attempts", default: 0
    t.text "handler"
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "queue", limit: 255
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "delayed_jobs_edge", force: :cascade do |t|
    t.integer "priority", default: 0
    t.integer "attempts", default: 0
    t.text "handler"
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by", limit: 255
    t.string "queue", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["priority", "run_at"], name: "delayed_jobs_edge_priority"
  end

  create_table "exercises", force: :cascade do |t|
    t.string "name", limit: 255
    t.integer "course_instance_id"
    t.datetime "deadline"
    t.integer "position", default: 0
    t.integer "groupsizemax", default: 1
    t.integer "groupsizemin", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "groups_from_exercise"
    t.string "feedbackgrouping", limit: 255, default: "sections"
    t.text "finalcomment"
    t.string "positive_caption", limit: 255
    t.string "negative_caption", limit: 255
    t.string "neutral_caption", limit: 255
    t.text "xml"
    t.boolean "anonymous_graders", default: false
    t.boolean "anonymous_submissions", default: false
    t.text "submit_post_message"
    t.text "submit_pre_message"
    t.boolean "grader_can_email", default: false
    t.boolean "unregistered_can_submit"
    t.boolean "submit_without_login", default: false
    t.string "grading_mode", limit: 255
    t.boolean "autoassign", default: true
    t.text "rubric"
    t.string "review_mode", limit: 255
    t.boolean "share_rubric", default: false
    t.string "lti_consumer", limit: 255
    t.string "lti_context_id", limit: 255
    t.string "lti_resource_link_id", limit: 255
    t.integer "peer_review_goal"
    t.string "collaborative_mode", limit: 255, default: ""
    t.string "submission_type", limit: 255
    t.string "peer_review_timing", limit: 255
    t.string "lti_resource_link_id_review", limit: 255
    t.string "lti_resource_link_id_feedback", limit: 255
    t.string "allowed_extensions", limit: 255, default: "", null: false
    t.boolean "reviewers_see_all_submissions", default: false
    t.index ["lti_consumer", "lti_context_id"], name: "index_exercises_on_lti_consumer_and_lti_context_id"
  end

  create_table "feedbacks", force: :cascade do |t|
    t.integer "review_id"
    t.integer "section_id"
    t.text "good"
    t.text "bad"
    t.text "neutral"
    t.integer "section_grading_option_id"
    t.string "status", limit: 16
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "group_invitations", force: :cascade do |t|
    t.integer "group_id"
    t.integer "exercise_id"
    t.string "token", limit: 255
    t.string "email", limit: 255
    t.date "expires_at"
    t.index ["group_id", "token"], name: "index_group_invitations_on_group_id_and_token"
  end

  create_table "group_members", force: :cascade do |t|
    t.integer "group_id", null: false
    t.integer "user_id"
    t.integer "group_invitation_id"
    t.string "email", limit: 255
    t.string "studentnumber", limit: 255
    t.string "access_token", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["access_token"], name: "index_group_members_on_access_token"
    t.index ["group_id"], name: "index_group_members_on_group_id"
    t.index ["user_id"], name: "index_group_members_on_user_id"
  end

  create_table "group_reviewers", force: :cascade do |t|
    t.integer "group_id", null: false
    t.integer "user_id", null: false
    t.index ["group_id"], name: "index_group_reviewers_on_group_id"
    t.index ["user_id"], name: "index_group_reviewers_on_user_id"
  end

  create_table "groups", force: :cascade do |t|
    t.integer "exercise_id"
    t.text "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "course_instance_id"
    t.string "access_token", limit: 255
    t.integer "min_size", default: 1, null: false
    t.integer "max_size", default: 1, null: false
    t.index ["access_token"], name: "index_groups_on_access_token"
  end

  create_table "groups_users", id: false, force: :cascade do |t|
    t.integer "group_id"
    t.integer "user_id"
    t.string "studentnumber", limit: 255
    t.string "email", limit: 255
  end

  create_table "infos", id: false, force: :cascade do |t|
    t.integer "exercise_id"
    t.string "studentnumber", limit: 255
    t.text "content"
    t.index ["exercise_id", "studentnumber"], name: "index_infos_on_exercise_id_and_studentnumber"
  end

  create_table "invitations", force: :cascade do |t|
    t.string "token", limit: 255, null: false
    t.string "type", limit: 255
    t.string "email", limit: 255
    t.integer "target_id"
    t.integer "inviter_id"
    t.date "expires_at"
    t.index ["token"], name: "index_invitations_on_token"
  end

  create_table "item_grades", id: false, force: :cascade do |t|
    t.integer "feedback_id"
    t.integer "item_grading_option_id"
  end

  create_table "item_grading_options", force: :cascade do |t|
    t.integer "item_id"
    t.string "text", limit: 255
    t.integer "points"
    t.integer "position", default: 0
  end

  create_table "items", force: :cascade do |t|
    t.string "name", limit: 255
    t.integer "position", default: 0
    t.integer "section_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "instructions", limit: 255
  end

  create_table "orders", force: :cascade do |t|
    t.integer "user_id"
    t.string "payment_id", limit: 255
    t.string "state", limit: 255
    t.string "amount", limit: 255
    t.string "description", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "domain", limit: 255
    t.string "name", limit: 255
  end

  create_table "phrases", force: :cascade do |t|
    t.text "content"
    t.integer "position", default: 0
    t.string "feedbacktype", limit: 32
    t.integer "item_id"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "pricings", force: :cascade do |t|
    t.string "type", limit: 255
    t.integer "paid_students", default: 0, null: false
    t.integer "planned_students", default: 0, null: false
  end

  create_table "review_ratings", force: :cascade do |t|
    t.integer "review_id"
    t.integer "user_id"
    t.integer "rating", limit: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["review_id", "user_id"], name: "index_review_ratings_on_review_id_and_user_id", unique: true
  end

  create_table "reviews", force: :cascade do |t|
    t.integer "user_id"
    t.integer "submission_id"
    t.text "feedback"
    t.string "grade", limit: 255
    t.string "status", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "calculated_grade"
    t.integer "final_grade"
    t.text "notes_to_teacher"
    t.text "notes_to_grader"
    t.text "payload"
    t.string "filename", limit: 255
    t.string "extension", limit: 255
    t.string "type", limit: 255, default: "Review", null: false
    t.text "lti_launch_params"
    t.string "language"
  end

  create_table "roles", id: false, force: :cascade do |t|
    t.integer "user_id"
    t.integer "course_id"
    t.string "role", limit: 255
  end

  create_table "section_grades", id: false, force: :cascade do |t|
    t.integer "feedback_id"
    t.integer "section_grading_option_id"
  end

  create_table "section_grading_options", force: :cascade do |t|
    t.integer "section_id"
    t.string "text", limit: 255
    t.integer "points"
    t.integer "position", default: 0
  end

  create_table "sections", force: :cascade do |t|
    t.string "name", limit: 255
    t.integer "position", default: 0
    t.text "instructions"
    t.integer "category_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "weight", default: 1.0
  end

  create_table "sessions", force: :cascade do |t|
    t.string "session_id", limit: 255, null: false
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_sessions_on_session_id"
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "submissions", force: :cascade do |t|
    t.integer "exercise_id"
    t.string "extension", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "group_id", null: false
    t.string "filename", limit: 255
    t.boolean "book_mode"
    t.integer "page_count"
    t.float "page_width"
    t.float "page_height"
    t.boolean "authenticated", default: false, null: false
    t.string "type", limit: 255
    t.string "aplus_feedback_url", limit: 255
    t.boolean "annotatable", default: false
    t.string "conversion", limit: 255
    t.text "page_sizes"
    t.text "payload"
    t.text "lti_launch_params"
    t.index ["group_id"], name: "index_submissions_on_group_id"
  end

  create_table "submissions_users", id: false, force: :cascade do |t|
    t.integer "user_id"
    t.integer "submission_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "login", limit: 255
    t.string "crypted_password", limit: 255
    t.string "salt", limit: 255
    t.string "firstname", limit: 255
    t.string "lastname", limit: 255
    t.string "email", limit: 255
    t.string "studentnumber", limit: 255
    t.boolean "admin"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "organization", limit: 255
    t.string "persistence_token", limit: 255
    t.string "perishable_token", limit: 255
    t.string "locale", limit: 255
    t.integer "login_count", default: 0, null: false
    t.datetime "last_request_at"
    t.datetime "last_login_at"
    t.datetime "current_login_at"
    t.integer "organization_id"
    t.integer "failed_login_count", default: 0, null: false
    t.integer "zoom_preference"
    t.string "submission_sort_preference", limit: 255
    t.string "tester", limit: 255
    t.integer "course_count", default: 0, null: false
    t.string "lti_consumer", limit: 255
    t.string "lti_user_id", limit: 255
    t.text "knowledge"
    t.index ["last_request_at"], name: "index_users_on_last_request_at"
    t.index ["login"], name: "index_users_on_login"
    t.index ["lti_consumer", "lti_user_id"], name: "index_users_on_lti_consumer_and_lti_user_id"
    t.index ["persistence_token"], name: "index_users_on_persistence_token"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
