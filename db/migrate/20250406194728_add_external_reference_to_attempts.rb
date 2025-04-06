class AddExternalReferenceToAttempts < ActiveRecord::Migration[7.2]
  def change
    add_column :attempts, :external_reference, :string
    add_index :attempts, [:kinds, :external_reference, :status], name: 'index_attempts_on_kinds_and_external_reference_and_status'
  end
end