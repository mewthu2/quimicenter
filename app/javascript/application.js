//= require jquery/dist/jquery.min.js
//= require datatables/media/js/jquery.dataTables.min.js
//= require apexcharts

document.addEventListener('DOMContentLoaded', function() {
  // Lógica para carregar itens via AJAX se preferir
  $('.toggle-items').on('click', function(e) {
    e.preventDefault();
    const orderId = $(this).data('order-id');
    $(`#items-order-${orderId}`).toggle();
  });
});