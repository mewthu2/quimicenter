class SyncConfiguration < ApplicationRecord
  validates :sync_start_date, presence: true
  validates :schedule_data, presence: true

  serialize :schedule_data, coder: JSON

  def self.current
    first_or_create(
      sync_start_date: Date.parse('2025-06-27'),
      schedule_data: default_schedule
    )
  end

  def self.default_schedule
    {
      'monday' => { 'enabled' => true, 'hours' => ['08:00', '14:00', '20:00'] },
      'tuesday' => { 'enabled' => true, 'hours' => ['08:00', '14:00', '20:00'] },
      'wednesday' => { 'enabled' => true, 'hours' => ['08:00', '14:00', '20:00'] },
      'thursday' => { 'enabled' => true, 'hours' => ['08:00', '14:00', '20:00'] },
      'friday' => { 'enabled' => true, 'hours' => ['08:00', '14:00', '20:00'] },
      'saturday' => { 'enabled' => false, 'hours' => [] },
      'sunday' => { 'enabled' => false, 'hours' => [] }
    }
  end

  def schedule_for_day(day)
    return { 'enabled' => false, 'hours' => [] } unless schedule_data.is_a?(Hash)
    schedule_data[day.to_s] || { 'enabled' => false, 'hours' => [] }
  end

  def enabled_days
    return [] unless schedule_data.is_a?(Hash)
    schedule_data.select { |_, config| config.is_a?(Hash) && config['enabled'] }.keys
  end

  def all_scheduled_hours
    return [] unless schedule_data.is_a?(Hash)

    hours = schedule_data.values
                        .select { |config| config.is_a?(Hash) && config['hours'].is_a?(Array) }
                        .flat_map { |config| config['hours'] }
                        .compact
                        .select { |hour| hour.is_a?(String) }
                        .uniq
    
    hours.sort
  rescue StandardError => e
    Rails.logger.error "Erro ao calcular horários agendados: #{e.message}"
    []
  end
end
