class AddHomepageSkillsCommentsToResidents < ActiveRecord::Migration[8.0]
  def change
    add_column :residents, :homepage, :string
    add_column :residents, :skills, :text
    add_column :residents, :comments, :text
  end
end
