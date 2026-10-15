-- Filtro de Projetos por frente de serviço.
--
-- Cada projeto diz no cabeçalho a que frente pertence (pode ser mais de uma):
--   frente: [paineis]
-- As chaves são as mesmas nas três línguas: paineis, pesquisas, indicadores,
-- relatorios.
--
-- Shortcodes:
--   {{< frentes >}}             na página de Projetos: fileira de botões
--                               (Todos + as frentes que têm projeto) e o mapa
--                               pasta do projeto -> frentes, lido pelo
--                               assets/html/frentes.html.
--   {{< ver-projetos paineis >}} na página de Serviços: botão que leva a
--                               Projetos já filtrada; some se a frente ainda
--                               não tem projeto.
--
-- Projeto sem "frente" ou com uma chave desconhecida interrompe o render.

local FRENTES = { "paineis", "pesquisas", "indicadores", "relatorios" }

-- Pasta dos projetos e página de Projetos de cada idioma.
local IDIOMAS = {
  pt = { pasta = "projetos", pagina = "projetos.html" },
  es = { pasta = "es/proyectos", pagina = "proyectos.html" },
  en = { pasta = "en/projects", pagina = "projects.html" },
}

local TEXTOS = {
  pt = {
    grupo = "Filtrar projetos por frente de serviço",
    todos = "Todos",
    paineis = "Painéis em Power BI",
    pesquisas = "Análise estatística para pesquisas acadêmicas",
    indicadores = "Consultoria em indicadores",
    relatorios = "Relatórios e auditorias de dados",
    ver = {
      paineis = "Ver projetos de painéis",
      pesquisas = "Ver projetos de pesquisa",
      indicadores = "Ver projetos de indicadores",
      relatorios = "Ver relatórios e auditorias",
    },
  },
  es = {
    grupo = "Filtrar proyectos por área de servicio",
    todos = "Todos",
    paineis = "Tableros en Power BI",
    pesquisas = "Análisis estadístico para investigaciones académicas",
    indicadores = "Consultoría en indicadores",
    relatorios = "Informes y auditorías de datos",
    ver = {
      paineis = "Ver proyectos de tableros",
      pesquisas = "Ver proyectos de investigación",
      indicadores = "Ver proyectos de indicadores",
      relatorios = "Ver informes y auditorías",
    },
  },
  en = {
    grupo = "Filter projects by service",
    todos = "All",
    paineis = "Power BI dashboards",
    pesquisas = "Statistical analysis for academic research",
    indicadores = "KPI consulting",
    relatorios = "Data reports and audits",
    ver = {
      paineis = "See dashboard projects",
      pesquisas = "See research projects",
      indicadores = "See KPI projects",
      relatorios = "See reports and audits",
    },
  },
}

local function idioma()
  local entrada = quarto.doc.input_file:gsub("\\", "/")
  local raiz = quarto.project.directory:gsub("\\", "/")
  local relativo = entrada:sub(#raiz + 2)
  local primeiro = relativo:match("^([^/]+)/")
  if primeiro == "es" or primeiro == "en" then
    return primeiro
  end
  return "pt"
end

local function conhecida(chave)
  for _, f in ipairs(FRENTES) do
    if f == chave then
      return true
    end
  end
  return false
end

-- Lê só o cabeçalho YAML do index.qmd (o resto pode ter código R).
local function cabecalho(caminho)
  local arquivo = io.open(caminho, "r")
  if not arquivo then
    return nil
  end
  local texto = arquivo:read("a")
  arquivo:close()
  local yaml = texto:match("^%-%-%-\r?\n(.-)\r?\n%-%-%-")
  if not yaml then
    return nil
  end
  return pandoc.read("---\n" .. yaml .. "\n---\n", "markdown").meta
end

-- { pasta do projeto = { frentes } } e o conjunto de frentes com projeto.
local function projetos(lang)
  local base = pandoc.path.join({ quarto.project.directory, IDIOMAS[lang].pasta })
  local mapa, usadas = {}, {}
  for _, pasta in ipairs(pandoc.system.list_directory(base)) do
    local meta = cabecalho(pandoc.path.join({ base, pasta, "index.qmd" }))
    if meta then
      local lista = meta.frente
      if lista == nil then
        error("frentes.lua: " .. IDIOMAS[lang].pasta .. "/" .. pasta .. " não tem 'frente' no cabeçalho")
      end
      if pandoc.utils.type(lista) ~= "List" then
        lista = { lista }
      end
      mapa[pasta] = {}
      for _, item in ipairs(lista) do
        local chave = pandoc.utils.stringify(item)
        if not conhecida(chave) then
          error("frentes.lua: frente '" .. chave .. "' desconhecida em " .. IDIOMAS[lang].pasta .. "/" .. pasta
            .. " (use paineis, pesquisas, indicadores ou relatorios)")
        end
        table.insert(mapa[pasta], chave)
        usadas[chave] = true
      end
    end
  end
  return mapa, usadas
end

local function json(mapa)
  local partes = {}
  local pastas = {}
  for pasta in pairs(mapa) do
    table.insert(pastas, pasta)
  end
  table.sort(pastas)
  for _, pasta in ipairs(pastas) do
    table.insert(partes, string.format('"%s":["%s"]', pasta, table.concat(mapa[pasta], '","')))
  end
  return "{" .. table.concat(partes, ",") .. "}"
end

return {
  ["frentes"] = function()
    if not quarto.doc.is_format("html") then
      return pandoc.Null()
    end
    local lang = idioma()
    local tx = TEXTOS[lang]
    local mapa, usadas = projetos(lang)
    local html = {
      string.format('<div class="filtro-frentes" role="group" aria-label="%s" hidden>', tx.grupo),
      string.format('<button type="button" class="filtro-frente" data-frente="" aria-pressed="true">%s</button>', tx.todos),
    }
    for _, chave in ipairs(FRENTES) do
      if usadas[chave] then
        table.insert(html, string.format(
          '<button type="button" class="filtro-frente" data-frente="%s" aria-pressed="false">%s</button>',
          chave, tx[chave]))
      end
    end
    table.insert(html, "</div>")
    table.insert(html, '<script type="application/json" id="frentes-projetos">' .. json(mapa) .. "</script>")
    quarto.doc.include_file("after-body", "../html/frentes.html")
    return pandoc.RawBlock("html", table.concat(html, "\n"))
  end,

  ["ver-projetos"] = function(args)
    if not quarto.doc.is_format("html") then
      return pandoc.Null()
    end
    local chave = pandoc.utils.stringify(args[1] or "")
    if not conhecida(chave) then
      error("frentes.lua: ver-projetos com frente desconhecida '" .. chave .. "'")
    end
    local lang = idioma()
    local _, usadas = projetos(lang)
    if not usadas[chave] then
      return pandoc.Null()
    end
    return pandoc.RawBlock("html", string.format(
      '<p class="ver-projetos"><a class="btn btn-outline-primary" href="%s?frente=%s">%s</a></p>',
      IDIOMAS[lang].pagina, chave, TEXTOS[lang].ver[chave]))
  end,
}
