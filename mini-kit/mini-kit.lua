-- Filtro usado só pela página do mini-kit (mini-kit/index.qmd).
--
-- 1. Acrescenta <meta name="robots" content="noindex, nofollow"> ao <head>,
--    sem substituir o head.html do site (include-in-header na página
--    substituiria a lista do projeto).
-- 2. Cada bloco ```{.texto-prompt} vira um bloco de texto com quebra de linha
--    (sem rolagem lateral), com o que está entre [colchetes] destacado, e o
--    botão "Copiar prompt" (o script fica no fim de index.qmd).
-- 3. Os campos do front matter (link_whatsapp, link_kit, link_planilha,
--    link_planilha_exemplo, data_lancamento, preco_cheio, preco_pre_venda,
--    data_fim_pre_venda e link_video) preenchem os blocos #bloco-video,
--    #botao-planilha, #frase-pre-venda e #botao-pre-venda. Campo vazio esconde
--    a parte que depende dele ou mostra a versão "em breve".
-- 4. O campo ano entra em cada [ano]{.campo} do texto, e
--    [ano_anterior]{.campo} é o ano menos 1. No título, o ano entra pelo
--    shortcode {{< meta ano >}} do próprio Quarto, que também chega ao
--    og:title (a prévia do link no WhatsApp); trocar o título neste filtro não
--    chegaria lá.

local campos = {}

local function texto(valor)
  if valor == nil then return "" end
  return (pandoc.utils.stringify(valor):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function escapar(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

local function html(s)
  return pandoc.RawBlock("html", s)
end

-- Endereço do YouTube (watch?v=, youtu.be/, embed/, shorts/, live/) -> id.
local function id_youtube(url)
  return url:match("[?&]v=([%w_-]+)")
      or url:match("youtu%.be/([%w_-]+)")
      or url:match("/embed/([%w_-]+)")
      or url:match("/shorts/([%w_-]+)")
      or url:match("/live/([%w_-]+)")
end

local contador = 0

local function bloco_prompt(bloco)
  contador = contador + 1
  local id = "prompt-texto-" .. contador
  local corpo = escapar(bloco.text):gsub("%[([^%]]*)%]", "<mark>[%1]</mark>")
  return html(
    '<div class="prompt-texto" id="' .. id .. '">' .. corpo .. '</div>\n' ..
    '<p class="prompt-acoes"><button type="button" class="btn btn-primary copiar-prompt" ' ..
    'data-alvo="' .. id .. '">Copiar prompt</button>' ..
    '<span class="copiar-aviso" aria-live="polite"></span></p>')
end

local function bloco_video()
  local url = campos.link_video
  if url == "" then return {} end
  local id = id_youtube(url)
  if not id then
    return html('<p class="mini-kit-video-link"><a href="' .. escapar(url) ..
      '" target="_blank" rel="noopener">Assista ao vídeo</a></p>')
  end
  return html(
    '<div class="video">\n<iframe src="https://www.youtube-nocookie.com/embed/' .. id ..
    '" title="Vídeo: como usar os 10 prompts" loading="lazy" allow="accelerometer; ' ..
    'clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" ' ..
    'referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>\n</div>')
end

local function botao_planilha()
  local url = campos.link_planilha
  if url == "" then
    return html('<p class="mini-kit-botao"><span class="btn btn-outline-primary btn-lg disabled" ' ..
      'aria-disabled="true">Planilha em breve</span></p>')
  end
  local exemplo = ""
  if campos.link_planilha_exemplo ~= "" then
    exemplo = '<p class="mini-kit-planilha-exemplo"><a href="' .. escapar(campos.link_planilha_exemplo) ..
      '" target="_blank" rel="noopener">Ver a versão com exemplo preenchido</a></p>'
  end
  return html('<p class="mini-kit-botao"><a class="btn btn-primary btn-lg botao-planilha" href="' ..
    escapar(url) .. '" target="_blank" rel="noopener">Fazer minha cópia da planilha</a></p>' .. exemplo)
end

local function botao_pre_venda()
  local url = campos.link_kit
  local alvo = ""
  if url == "" then
    url = campos.link_whatsapp
    alvo = ' target="_blank" rel="noopener"'
  end
  return html('<p class="mini-kit-botao"><a class="btn btn-primary btn-lg botao-pre-venda" href="' ..
    escapar(url) .. '"' .. alvo .. '>Quero garantir o preço de pré-venda</a></p>')
end

local PRECOS = { "data_lancamento", "preco_cheio", "preco_pre_venda", "data_fim_pre_venda" }

local function frase_pre_venda(div)
  for _, nome in ipairs(PRECOS) do
    if campos[nome] == "" then
      return pandoc.Para({ pandoc.Str(
        "A pré-venda abre em breve. Me chama no WhatsApp para garantir o preço de lançamento.") })
    end
  end
  -- Todos preenchidos: cada [nome]{.campo} vira o valor do campo (trocar_campo).
  return div.content
end

-- [nome]{.campo} -> valor do campo. Nome desconhecido ou campo vazio param o
-- render, para nunca sair o nome do campo na página.
local function trocar_campo(span)
  if not span.classes:includes("campo") then return nil end
  local nome = pandoc.utils.stringify(span.content)
  local valor = campos[nome]
  if valor == nil or valor == "" then
    error("mini-kit: campo [" .. nome .. "] desconhecido ou vazio")
  end
  return pandoc.Str(valor)
end

local function ler_campos(meta)
  for _, nome in ipairs({ "link_whatsapp", "link_kit", "link_planilha", "link_planilha_exemplo", "link_video",
                          "data_lancamento", "preco_cheio", "preco_pre_venda", "data_fim_pre_venda", "ano" }) do
    campos[nome] = texto(meta[nome])
  end
  if campos.link_whatsapp == "" then
    error("mini-kit: o campo link_whatsapp não pode ficar vazio")
  end
  local ano = tonumber(campos.ano)
  if not ano or not campos.ano:match("^%d%d%d%d$") then
    error("mini-kit: o campo ano precisa ser um ano com 4 dígitos, como \"2027\"")
  end
  campos.ano_anterior = tostring(ano - 1)
  quarto.doc.include_text("in-header", '<meta name="robots" content="noindex, nofollow">')
  return meta
end

local function trocar_blocos(div)
  if div.identifier == "bloco-video" then return bloco_video() end
  if div.identifier == "botao-planilha" then return botao_planilha() end
  if div.identifier == "botao-pre-venda" then return botao_pre_venda() end
  if div.identifier == "frase-pre-venda" then return frase_pre_venda(div) end
end

local function trocar_codigo(bloco)
  if bloco.classes:includes("texto-prompt") then return bloco_prompt(bloco) end
end

return {
  { Meta = ler_campos },
  { Div = trocar_blocos, CodeBlock = trocar_codigo },
  { Span = trocar_campo },
}
