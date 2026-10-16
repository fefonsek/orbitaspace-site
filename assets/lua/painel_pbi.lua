-- Shortcode {{< painel-pbi titulo="..." botao="..." >}}: painel do Power BI
-- publicado na web ("Publicar na Web").
--
-- O link fica num lugar só: a chave painel-pbi do _quarto.yml.
-- No computador, mostra o painel num iframe; no celular (até 600 px), troca
-- o iframe por um botão que abre o painel em tela cheia numa nova aba.
--   titulo: nome do iframe lido por leitores de tela
--   botao:  texto do botão do celular

local function escapar(texto)
  return (texto:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

return {
  ["painel-pbi"] = function(_args, kwargs, meta)
    local url = escapar(pandoc.utils.stringify(meta["painel-pbi"] or ""))
    if url == "" then
      error("painel-pbi: falta o link na chave painel-pbi do _quarto.yml")
    end
    local titulo = escapar(pandoc.utils.stringify(kwargs["titulo"] or ""))
    local botao = escapar(pandoc.utils.stringify(kwargs["botao"] or ""))
    return pandoc.RawBlock("html", string.format(
      '<div class="painel-pbi so-computador">\n'
        .. '<iframe src="%s" title="%s" loading="lazy" allowfullscreen></iframe>\n'
        .. "</div>\n"
        .. '<p class="painel-pbi-botao so-celular">'
        .. '<a class="btn btn-primary" href="%s" target="_blank" rel="noopener">%s</a></p>',
      url, titulo, url, botao))
  end,
}
