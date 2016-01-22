class GenerateAplusSubmissions < ActiveRecord::Migration
  def change
    create_table :aplus_submissions, id: false do |t|
      t.references :submission, :null => false
      t.string :submission_url
    end
  end
end