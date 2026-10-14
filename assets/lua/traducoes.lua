-- Gera <link rel="alternate" hreflang="..."> para as versões da página
-- nos três idiomas, a partir de _traducoes.yml e do campo "traducao"
-- no cabeçalho da página.

local SITE = "https://orbitaspace.com.br"
local CODIGOS = { { "pt", "pt-BR" }, { "es", "es" }, { "en", "en" } }

local function ler_tabela()
  local caminho = pandoc.path.join({ quarto.project.directory, "_traducoes.yml" })
  local arquivo = io.open(caminho, "r")
  if not arquivo then
    return nil
  end
  local texto = arquivo:read("a")
  arquivo:close()
  return pandoc.read("---\n" .. texto .. "\n---\n", "markdown").meta
end

function Meta(meta)
  if not quarto.doc.is_format("html") or meta.traducao == nil then
    return
  end
  local chave = pandoc.utils.stringify(meta.traducao)
  local tabela = ler_tabela()
  local versoes = tabela and tabela[chave]
  if versoes == nil then
    quarto.log.warning("traducao '" .. chave .. "' não existe em _traducoes.yml")
    return
  end

  local linhas = {}
  for _, par in ipairs(CODIGOS) do
    local idioma, codigo = par[1], par[2]
    if versoes[idioma] then
      local url = SITE .. pandoc.utils.stringify(versoes[idioma])
      table.insert(linhas, string.format('<link rel="alternate" hreflang="%s" href="%s">', codigo, url))
      if idioma == "pt" then
        table.insert(linhas, string.format('<link rel="alternate" hreflang="x-default" href="%s">', url))
      end
    end
  end
  quarto.doc.include_text("in-header", table.concat(linhas, "\n"))
end
