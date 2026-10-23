-- Shortcode {{< painel-pbi titulo="..." botao="..." >}}: painel do Power BI
-- publicado na web ("Publicar na Web").
--
-- O link fica num lugar só: a chave painel-pbi do _quarto.yml.
-- No computador, mostra o painel num iframe; no celular (até 600 px), troca
-- o iframe por um botão que abre o painel em tela cheia numa nova aba.
--   titulo: nome do iframe lido por leitores de tela
--   botao:  texto do botão do celular
--
-- Com imagem="...", o painel só carrega no clique (usado na landing de
-- People Analytics): aparece a imagem do painel com o botão, e o iframe só é
-- inserido quando a pessoa clica (script em assets/html/idiomas.html). Sem
-- JavaScript, e no celular, o clique abre o painel numa nova aba.
--   imagem:      imagem do painel (1600 x 900), relativa à página
--   imagem-mini: versão leve da imagem (640 x 360), usada no celular
--   alt:         texto alternativo da imagem

local function escapar(texto)
  return (texto:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

local function texto(kwargs, chave)
  return escapar(pandoc.utils.stringify(kwargs[chave] or ""))
end

return {
  ["painel-pbi"] = function(_args, kwargs, meta)
    local url = escapar(pandoc.utils.stringify(meta["painel-pbi"] or ""))
    if url == "" then
      error("painel-pbi: falta o link na chave painel-pbi do _quarto.yml")
    end
    local titulo = texto(kwargs, "titulo")
    local botao = texto(kwargs, "botao")
    local imagem = texto(kwargs, "imagem")
    if imagem ~= "" then
      local mini = texto(kwargs, "imagem-mini")
      if mini == "" then
        mini = imagem
      end
      return pandoc.RawBlock("html", string.format(
        '<div class="painel-pbi-clique" data-src="%s" data-titulo="%s">\n'
          .. '<a class="painel-pbi-capa" href="%s" target="_blank" rel="noopener">'
          .. '<img src="%s" srcset="%s 640w, %s 1600w" sizes="(max-width: 600px) 100vw, 800px"'
          .. ' alt="%s" width="1600" height="900" loading="lazy">'
          .. '<span class="btn btn-primary painel-pbi-abrir">%s</span></a>\n'
          .. "</div>",
        url, titulo, url, mini, mini, imagem, texto(kwargs, "alt"), botao))
    end
    return pandoc.RawBlock("html", string.format(
      '<div class="painel-pbi so-computador">\n'
        .. '<iframe src="%s" title="%s" loading="lazy" allowfullscreen></iframe>\n'
        .. "</div>\n"
        .. '<p class="painel-pbi-botao so-celular">'
        .. '<a class="btn btn-primary" href="%s" target="_blank" rel="noopener">%s</a></p>',
      url, titulo, url, botao))
  end,
}
