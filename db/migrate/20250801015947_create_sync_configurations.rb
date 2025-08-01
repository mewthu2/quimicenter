class CreateSyncConfigurations < ActiveRecord::Migration[7.2]
  def change
    create_table :sync_configurations do |t|
      t.date :sync_start_date, null: false
      t.text :schedule_data, null: false
      t.boolean :active, default: true
      t.datetime :last_sync_at
      t.text :notes
      
      t.timestamps
    end
    
    add_index :sync_configurations, :active
    add_index :sync_configurations, :sync_start_date
  end
end
