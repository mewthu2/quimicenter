class AttemptsController < ApplicationController
  before_action :load_form_references, only: [:index]
  protect_from_forgery except: :verify_attempts

  def index
    @attempts = Attempt.all
    @attempts = @attempts.search(params[:search]) if params[:search].present?
    @attempts = @attempts.where(status: params[:status] || ['success', 'fail', 'error']) if params[:status].present?
    @attempts = @attempts.where(kinds: params[:kinds]) if params[:kinds].present?
    @attempts = @attempts.order(created_at: :desc)
                         .paginate(page: params[:page], per_page: params_per_page(params[:per_page]))
  end

  def reprocess
    attempt = Attempt.find(params[:id])
    if attempt.reprocess!
      flash[:success] = 'Tentativa reprocessada com sucesso.'
    else
      flash[:error] = 'Erro ao reprocessar a tentativa.'
    end
    redirect_to attempts_path
  end

  private

  def load_form_references
    @statuses = Attempt.distinct.pluck(:status)
    @kinds = Attempt.distinct.pluck(:kinds)
  end

  def params_per_page(per_page)
    per_page.to_i.positive? ? per_page.to_i : 10
  end
end
