// Busca e filtros do inventário (área, situação, destino). Sem JavaScript,
// a tabela aparece inteira e os filtros ficam escondidos.
document.addEventListener("DOMContentLoaded", function () {
  document.querySelectorAll(".inventario").forEach(function (bloco) {
    var busca = bloco.querySelector('input[type="search"]');
    var filtros = Array.prototype.slice.call(bloco.querySelectorAll("select[data-filtro]"));
    var linhas = Array.prototype.slice.call(bloco.querySelectorAll("tbody tr"));
    var contagem = bloco.querySelector(".inventario-contagem");
    var total = contagem.getAttribute("data-total");

    function normalizar(texto) {
      return texto.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
    }

    function aplicar() {
      var termo = normalizar(busca.value.trim());
      var visiveis = 0;
      linhas.forEach(function (linha) {
        var ok = filtros.every(function (f) {
          return !f.value || linha.getAttribute("data-" + f.getAttribute("data-filtro")) === f.value;
        }) && (!termo || normalizar(linha.textContent).indexOf(termo) >= 0);
        linha.hidden = !ok;
        if (ok) visiveis++;
      });
      contagem.textContent = visiveis + " de " + total + " indicadores";
    }

    busca.addEventListener("input", aplicar);
    filtros.forEach(function (f) { f.addEventListener("change", aplicar); });
    bloco.classList.add("inventario-ativo");
  });
});
