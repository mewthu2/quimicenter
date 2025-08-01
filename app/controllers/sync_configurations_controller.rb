class SyncConfigurationsController < ApplicationController
  before_action :authenticate_user!
  
  def show
    @config = SyncConfiguration.current
  end
  
  def update
    @config = SyncConfiguration.current
    
    if @config.update(config_params)
      # Reagendar o job com as novas configurações
      reschedule_sync_job
      
      flash[:success] = 'Configurações atualizadas com sucesso!'
      redirect_to sync_configuration_path
    else
      flash[:error] = 'Erro ao atualizar configurações: ' + @config.errors.full_messages.join(', ')
      render :show
    end
  end
  
  def test_sync
    begin
      SyncSaleOrdersJob.perform_now
      flash[:success] = 'Job de sincronização iniciado com sucesso!'
    rescue StandardError => e
      flash[:error] = "Erro ao iniciar sincronização: #{e.message}"
    end
    
    redirect_to sync_configuration_path
  end
  
  def cleanup_data
    begin
      CleanupDataJob.perform_now(current_user.id)

      flash[:success] = 'Limpeza de dados iniciada! O processo será executado em background.'
    rescue StandardError => e
      Rails.logger.error "Erro ao iniciar limpeza: #{e.message}"
      flash[:error] = "Erro ao iniciar limpeza de dados: #{e.message}"
    end
    
    redirect_to sync_configuration_path
  end
  
  private
  
  def config_params
    params.require(:sync_configuration).permit(
      :sync_start_date,
      :notes,
      schedule_data: {}
    )
  end
  
  def reschedule_sync_job
    # Aqui você pode implementar a lógica para reagendar o job
    # usando whenever gem ou similar
    Rails.logger.info "Reagendando job com nova configuração: #{@config.schedule_data}"
  end
end
