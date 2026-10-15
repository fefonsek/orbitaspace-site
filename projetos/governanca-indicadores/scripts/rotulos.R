# Caso Indicadores: textos e formatos de cada idioma (PT, ES, EN), no mesmo
# espírito do rotulos.R do caso TCC.
# - rotulos(idioma) devolve os formatos de número e de data e os rótulos curtos
#   (gráficos, filtros, cabeçalhos, capa).
# - localizar(ind, tx) troca os textos dos dados pelos do idioma. As traduções
#   longas ficam em scripts/textos_es.yml e textos_en.yml, presas às chaves dos
#   arquivos em português de dados/; os números continuam vindo dos dados, e as
#   checagens de dados.R rodam antes, sobre os dados em português.

rotulos <- function(idioma = c("pt", "es", "en"), caso = ".") {
  idioma <- match.arg(idioma)
  ingles <- idioma == "en"
  num <- function(x, d = 2) formatC(x, format = "f", digits = d, big.mark = if (ingles) "," else ".",
                                    decimal.mark = if (ingles) "." else ",")
  pct <- function(x, d = 2) paste0(num(x, d), "%")

  meses <- switch(idioma,
    pt = c("janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"),
    es = c("enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"),
    en = c("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"))
  meses_abrev <- switch(idioma,
    pt = c("jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"),
    es = c("ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"),
    en = substr(meses, 1, 3))
  e <- switch(idioma, pt = "e", es = "y", en = "and")
  # "2025-06" -> "junho de 2025", "junio de 2025", "June 2025"
  mes_ano <- function(mes, ano) if (ingles) paste(mes, ano) else paste(mes, "de", ano)
  mes_extenso <- function(m) mes_ano(meses[as.integer(substr(m, 6, 7))], substr(m, 1, 4))
  # c("2024-01", "2024-02", "2025-09") -> "janeiro e fevereiro de 2024, setembro de 2025"
  lista_meses <- function(m) {
    juntar <- function(x) if (length(x) == 1) x else paste(paste(head(x, -1), collapse = ", "), e, tail(x, 1))
    por_ano <- split(m, substr(m, 1, 4))
    paste(vapply(names(por_ano), \(a) mes_ano(juntar(meses[as.integer(substr(por_ano[[a]], 6, 7))]), a), ""),
          collapse = ", ")
  }

  # Número por extenso. Em PT e ES, só de 1 a 10 (no texto corrido); em inglês,
  # de 1 a 99, porque número que abre a frase vai por extenso ("Forty...").
  extenso <- function(n, feminino = FALSE, inicio = FALSE) {
    if (ingles) {
      unidades <- c("one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven",
                    "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen")
      dezenas <- c("", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety")
      palavra <- if (n < 1 || n > 99) num(n, 0) else if (n < 20) unidades[n] else
        paste0(dezenas[n %/% 10], if (n %% 10) paste0("-", unidades[n %% 10]) else "")
      if (inicio) paste0(toupper(substr(palavra, 1, 1)), substring(palavra, 2)) else palavra
    } else {
      nomes <- switch(idioma,
        pt = c(if (feminino) c("uma", "duas") else c("um", "dois"), "três", "quatro", "cinco", "seis", "sete", "oito", "nove", "dez"),
        es = c(if (feminino) "una" else "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez"))
      if (n >= 1 && n <= 10) nomes[n] else num(n, 0)
    }
  }

  t <- switch(idioma,
    pt = list(
      nomes_def = c(rh = "RH", operacao = "Operação", financeiro = "Financeiro"),
      g_reuniao = "reunião de julho",
      g_situacao = "Situação encontrada", g_situacao_curta = "Situação", g_destino = "Destino",
      descricao = \(n, d) paste(n, "indicadores viraram", d),
      criterios_sit = c("Situação encontrada", "Critério", "Quantos"),
      criterios_dest = c("Destino", "O que significa", "Quantos"),
      inv_busca = "Buscar indicador ou observação", inv_busca_aria = "Buscar no inventário",
      inv_todas = c(area = "Todas as áreas", situacao = "Todas as situações", destino = "Todos os destinos"),
      inv_aria = c(area = "Filtrar por área", situacao = "Filtrar por situação", destino = "Filtrar por destino"),
      inv_contagem = "{n} de {total} indicadores",
      inv_colunas = c("#", "Indicador (como era chamado)", "Área", "Situação", "Destino", "Observação", "Ficha"),
      inv_ficha = "Ficha",
      campos = c(codigo = "Código", pergunta = "Pergunta que responde", objetivo = "Objetivo ligado",
                 formula = "Fórmula", numerador = "Numerador", denominador = "Denominador",
                 fora = "Fica fora dos dois", quebras = "Quebras padrão", fonte = "Fonte",
                 periodicidade = "Periodicidade", polaridade = "Polaridade", meta = "Meta e faixas",
                 dono = "Dono do resultado", responsavel_calculo = "Responsável pelo cálculo",
                 decisao = "Decisão que apoia", relacionados = "Indicadores relacionados", versao = "Versão"),
      valor_em = \(ano) paste("Valor em", ano),
      raci_colunas = c("Atividade", "Dono do indicador", "Analista de BI", "Comitê", "Diretoria"),
      raci_papeis = c(dono = "Dono", bi = "BI", comite = "Comitê", diretoria = "Diretoria"),
      versoes_colunas = c("Data", "Indicador", "Versão", "Mudança", "Motivo"),
      versao = "versão", motivo = "Motivo",
      capa_titulo = "Um número,\ntrês respostas",
      capa_subtitulo = "Governança de indicadores\nna Vallora Logística",
      capa_frase = \(n, d) paste0(n, " indicadores viraram ", d, ",\ncada um com ficha, dono e regra."),
      capa_grafico = "Absenteísmo, três cálculos",
      capa_rodape = "Empresa, pessoas e dados fictícios · Felipe Fonseca · @fefonsek"),
    es = list(
      nomes_def = c(rh = "RR. HH.", operacao = "Operaciones", financeiro = "Finanzas"),
      g_reuniao = "reunión de julio",
      g_situacao = "Situación encontrada", g_situacao_curta = "Situación", g_destino = "Destino",
      descricao = \(n, d) paste(n, "indicadores se convirtieron en", d),
      criterios_sit = c("Situación encontrada", "Criterio", "Cuántos"),
      criterios_dest = c("Destino", "Qué significa", "Cuántos"),
      inv_busca = "Buscar indicador u observación", inv_busca_aria = "Buscar en el inventario",
      inv_todas = c(area = "Todas las áreas", situacao = "Todas las situaciones", destino = "Todos los destinos"),
      inv_aria = c(area = "Filtrar por área", situacao = "Filtrar por situación", destino = "Filtrar por destino"),
      inv_contagem = "{n} de {total} indicadores",
      inv_colunas = c("#", "Indicador (como se llamaba)", "Área", "Situación", "Destino", "Observación", "Ficha"),
      inv_ficha = "Ficha",
      campos = c(codigo = "Código", pergunta = "Pregunta que responde", objetivo = "Objetivo vinculado",
                 formula = "Fórmula", numerador = "Numerador", denominador = "Denominador",
                 fora = "Queda fuera de ambos", quebras = "Desgloses estándar", fonte = "Fuente",
                 periodicidade = "Periodicidad", polaridade = "Polaridad", meta = "Meta y rangos",
                 dono = "Dueño del resultado", responsavel_calculo = "Responsable del cálculo",
                 decisao = "Decisión que apoya", relacionados = "Indicadores relacionados", versao = "Versión"),
      valor_em = \(ano) paste("Valor en", ano),
      raci_colunas = c("Actividad", "Dueño del indicador", "Analista de BI", "Comité", "Dirección"),
      raci_papeis = c(dono = "Dueño", bi = "BI", comite = "Comité", diretoria = "Dirección"),
      versoes_colunas = c("Fecha", "Indicador", "Versión", "Cambio", "Motivo"),
      versao = "versión", motivo = "Motivo",
      capa_titulo = "Un número,\ntres respuestas",
      capa_subtitulo = "Gobernanza de indicadores\nen Vallora Logística",
      capa_frase = \(n, d) paste0(n, " indicadores se convirtieron en ", d, ",\ncada uno con ficha, dueño y regla."),
      capa_grafico = "Ausentismo, tres cálculos",
      capa_rodape = "Empresa, personas y datos ficticios · Felipe Fonseca · @fefonsek"),
    en = list(
      nomes_def = c(rh = "HR", operacao = "Operations", financeiro = "Finance"),
      g_reuniao = "July meeting",
      g_situacao = "Status found", g_situacao_curta = "Status", g_destino = "Destination",
      descricao = \(n, d) paste(n, "KPIs became", d),
      criterios_sit = c("Status found", "Criterion", "Count"),
      criterios_dest = c("Destination", "What it means", "Count"),
      inv_busca = "Search KPIs or notes", inv_busca_aria = "Search the inventory",
      inv_todas = c(area = "All departments", situacao = "All statuses", destino = "All destinations"),
      inv_aria = c(area = "Filter by department", situacao = "Filter by status", destino = "Filter by destination"),
      inv_contagem = "{n} of {total} KPIs",
      inv_colunas = c("#", "KPI (as it was called)", "Department", "Status", "Destination", "Note", "Sheet"),
      inv_ficha = "Sheet",
      campos = c(codigo = "Code", pergunta = "Question it answers", objetivo = "Linked objective",
                 formula = "Formula", numerador = "Numerator", denominador = "Denominator",
                 fora = "Excluded from both", quebras = "Standard breakdowns", fonte = "Source",
                 periodicidade = "Frequency", polaridade = "Polarity", meta = "Target and thresholds",
                 dono = "Owner of the result", responsavel_calculo = "Calculated by",
                 decisao = "Decision it supports", relacionados = "Related KPIs", versao = "Version"),
      valor_em = \(ano) paste(ano, "value"),
      raci_colunas = c("Activity", "KPI owner", "BI analyst", "Committee", "Leadership"),
      raci_papeis = c(dono = "Owner", bi = "BI", comite = "Committee", diretoria = "Leadership"),
      versoes_colunas = c("Date", "KPI", "Version", "Change", "Reason"),
      versao = "version", motivo = "Reason",
      capa_titulo = "One number,\nthree answers",
      capa_subtitulo = "KPI governance\nat Vallora Logística",
      capa_frase = \(n, d) paste0(n, " KPIs became ", d, ",\neach with a sheet, an owner and a rule."),
      capa_grafico = "Absenteeism, three calculations",
      capa_rodape = "Fictional company, people and data · Felipe Fonseca · @fefonsek")
  )
  textos <- if (idioma == "pt") NULL else
    yaml::read_yaml(file.path(caso, "scripts", paste0("textos_", idioma, ".yml")))
  c(t, list(idioma = idioma, num = num, pct = pct, meses = meses, meses_abrev = meses_abrev,
            mes_extenso = mes_extenso, lista_meses = lista_meses, extenso = extenso, textos = textos))
}

# Troca os textos dos dados pelos do idioma. As colunas "situacao" e "destino"
# do inventário passam a ter os nomes traduzidos (na mesma ordem); os nomes em
# português ficam em "situacao_chave" e "destino_chave", para a lógica.
localizar <- function(ind, tx) {
  ind$tx <- tx
  inv <- ind$inventario |>
    mutate(situacao_chave = as.character(situacao), destino_chave = as.character(destino))
  ind$rotulo_diretoria <- "Diretoria"
  if (is.null(tx$textos)) {
    ind$inventario <- inv
    ind$fichas <- lapply(ind$fichas, \(f) c(f, pilar_tx = f$pilar, objetivo_tx = f$objetivo))
    ind$criterios <- ind$criterios |> mutate(nome_tx = nome, criterio_tx = criterio)
    ind$definicoes$campo_chave <- ind$definicoes$campo
    return(ind)
  }
  y <- tx$textos
  par <- function(lista, chave, i) vapply(chave, \(k) lista[[k]][[i]], "")
  niv_sit <- levels(inv$situacao); niv_dest <- levels(inv$destino)
  inv <- inv |>
    mutate(indicador = par(y$inventario, as.character(numero), 1),
           observacao = na_if(par(y$inventario, as.character(numero), 2), ""),
           area = unname(unlist(y$areas[area])),
           situacao = factor(par(y$situacoes, situacao_chave, 1), par(y$situacoes, niv_sit, 1)),
           destino = factor(par(y$destinos, destino_chave, 1), par(y$destinos, niv_dest, 1)))
  ind$inventario <- inv
  ind$rotulo_diretoria <- y$destinos[["Diretoria"]][[1]]

  criterios <- c(y$situacoes, y$destinos)
  ind$criterios <- ind$criterios |>
    mutate(nome_tx = par(criterios, nome, 1), criterio_tx = par(criterios, nome, 2))

  ind$fichas <- lapply(ind$fichas, function(f) {
    trad <- y$fichas[[f$codigo]]
    f[names(trad)] <- trad
    c(f, pilar_tx = y$pilares[[f$pilar]][[1]], objetivo_tx = y$pilares[[f$pilar]][[2]])
  })

  ind$raci$atividade <- unlist(y$raci)
  letras <- unlist(y$raci_letras)
  ind$raci <- ind$raci |> mutate(across(-atividade, \(x) ifelse(!is.na(x) & x %in% names(letras), letras[x], x)))

  v <- y$versoes
  ind$versoes <- ind$versoes |>
    mutate(data = vapply(v, \(l) l[[1]], ""), indicador = vapply(v, \(l) l[[2]], ""),
           mudanca = vapply(v, \(l) l[[3]], ""), motivo = vapply(v, \(l) l[[4]], ""))

  d <- y$definicoes
  ind$definicoes <- tibble(campo_chave = ind$definicoes$campo,
                           campo = vapply(d, \(l) l[[1]], ""), rh = vapply(d, \(l) l[[2]], ""),
                           operacao = vapply(d, \(l) l[[3]], ""), financeiro = vapply(d, \(l) l[[4]], ""))
  ind
}
