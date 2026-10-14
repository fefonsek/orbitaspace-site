-- Shortcode {{< galeria >}}: grade de miniaturas que abrem no lightbox.
--
-- Lê do cabeçalho da página:
--   galeria-pasta: caminho relativo até a pasta das imagens
--   galeria:       lista de { arquivo, legenda }
-- Na grade usa <arquivo>_mini.jpg; no lightbox, <arquivo>.jpg.
--
-- O Quarto só carrega o lightbox (GLightbox) quando processa uma imagem
-- comum em Markdown. Por isso a página põe a capa como imagem Markdown com
-- group="telas" logo antes do shortcode; as miniaturas entram no mesmo grupo.

local GRUPO = "telas"

local function escapar(texto)
  return (texto:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

return {
  ["galeria"] = function(_args, _kwargs, meta)
    local pasta = pandoc.utils.stringify(meta["galeria-pasta"] or "img")
    local html = { '<div class="galeria">' }
    for _, item in ipairs(meta["galeria"] or {}) do
      local arquivo = pandoc.utils.stringify(item.arquivo)
      local legenda = escapar(pandoc.utils.stringify(item.legenda))
      table.insert(html, string.format(
        '<figure><a href="%s/%s.jpg" class="lightbox" data-gallery="%s" data-description="%s">'
          .. '<img src="%s/%s_mini.jpg" alt="%s" loading="lazy" width="800" height="450"></a>'
          .. "<figcaption>%s</figcaption></figure>",
        pasta, arquivo, GRUPO, legenda, pasta, arquivo, legenda, legenda))
    end
    table.insert(html, "</div>")
    return pandoc.RawBlock("html", table.concat(html, "\n"))
  end,
}
