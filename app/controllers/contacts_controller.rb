class ContactsController < ApplicationController
  PER_PAGE = 20

  def index
    @per_page = PER_PAGE

    @filters = {
      pagina: params[:page] || 1,
      limite: PER_PAGE
    }

    permitted_params = params.permit(
      :pesquisa,
      :criterio,
      :dataInclusaoInicial,
      :dataInclusaoFinal,
      :dataAlteracaoInicial,
      :dataAlteracaoFinal,
      :idTipoContato,
      :idVendedor,
      :uf,
      :telefone,
      :numeroDocumento,
      :page
    ).to_h.compact

    @filters.merge!(permitted_params)

    if params[:idsContatos].present?
      @filters[:idsContatos] = params[:idsContatos].split(',')
    end

    response = Bling::Contacts.all(@filters)
    @contacts = response['data'] || []
    @total_contacts = response.dig('pagination', 'total') || 0

    @current_page = @filters[:pagina].to_i
    @next_page = @current_page + 1 if @contacts.size >= PER_PAGE
    @prev_page = @current_page - 1 if @current_page > 1

    @criteria_options = [
      ['Todos', 1],
      ['Excluídos', 2],
      ['Últimos incluídos', 3],
      ['Sem movimento', 4]
    ]

    @uf_options = [
      'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO',
      'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI',
      'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'
    ]
  end
end