-- Fecho de todas as páginas: bordão do lado de dados e faixa de arte
-- (assets/img/faixa_orbita.jpg, gerada por scripts/imagens_artes.py).
--
-- O bloco entra no fim do <body>, fora do conteúdo (assim não aparece no
-- feed RSS dos posts), e o script de assets/html/idiomas.html o leva para
-- logo acima do rodapé, na largura total da tela. Na página da Saline Astral
-- só entra a faixa: o fecho da própria página (.saline-fecho) faz o papel do
-- bordão. A faixa é decorativa: alt vazio e aria-hidden.

local BORDAO = {
  pt = "Decifre os sinais dos seus dados.",
  es = "Descifra las señales de tus datos.",
  en = "Decode the signals in your data.",
}

-- Língua pela pasta do arquivo: es/ e en/; o resto é português.
local function idioma()
  local caminho = pandoc.path.make_relative(quarto.doc.input_file, quarto.project.directory)
  local topo = caminho:gsub("\\", "/"):match("^([^/]+)/")
  return (topo == "es" or topo == "en") and topo or "pt"
end

local function tem_fecho_proprio(blocos)
  local achou = false
  blocos:walk({
    Div = function(div)
      if div.classes:includes("saline-fecho") then
        achou = true
      end
    end,
  })
  return achou
end

function Pandoc(doc)
  if not quarto.doc.is_format("html") then
    return nil
  end
  local bordao = ""
  if not tem_fecho_proprio(doc.blocks) then
    bordao = '<p class="bordao-site">' .. BORDAO[idioma()] .. "</p>\n"
  end
  quarto.doc.include_text("after-body",
    '<div class="fecho-site">\n' .. bordao
      .. '<div class="faixa-arte" aria-hidden="true">'
      .. '<img src="/assets/img/faixa_orbita.jpg" alt="" width="2000" height="500" loading="lazy">'
      .. "</div>\n</div>")
  return nil
end
