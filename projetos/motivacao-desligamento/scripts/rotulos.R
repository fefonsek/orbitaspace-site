# Caso Motivação de desligamento: formatos e textos curtos de cada língua (PT,
# ES, EN), no mesmo espírito do rotulos.R do caso Auditoria.
# - Formatos de número, de porcentagem, de p-valor e de data. Em inglês, o
#   p-valor segue a APA (sem zero à esquerda: p < .001).
# - Nomes dos motivos, das gerências, dos grupos, das prioridades e dos sinais.
#   As chaves são os valores em português que scripts/analise.R grava; os
#   números continuam vindo de resultados/desligamento.rds.
# - Rótulos dos gráficos e da capa, cabeçalhos das tabelas e colunas do CSV.
# O texto corrido fica em cada index.qmd (página) e em relatorio/textos_*.yml
# (relatório em PDF).

rotulos <- function(idioma = c("pt", "es", "en")) {
  idioma <- match.arg(idioma)
  ingles <- idioma == "en"
  num <- function(x, d = 0) formatC(x, format = "f", digits = d, big.mark = if (ingles) "," else ".",
                                    decimal.mark = if (ingles) "." else ",")
  pct <- function(x, d = 1) paste0(num(x, d), "%")
  ate <- switch(idioma, pt = " a ", es = " a ", en = " to ")
  # Intervalo de confiança de uma porcentagem ("22,5% a 28,9%") e de uma razão ("1,4 a 4,4").
  ic <- function(inf, sup, d = 1) paste0(num(inf, d), "%", ate, num(sup, d), "%")
  num_ic <- function(inf, sup, d = 1) paste0(num(inf, d), ate, num(sup, d))
  # p-valor no texto ("p = 0,45") e na tabela ("0,450"); em inglês, sem o zero.
  p_tab <- function(p, d = 3) {
    v <- if_else(p < 0.001, paste0("< ", num(0.001, 3)), num(p, d))
    if (ingles) sub("^(< )?0\\.", "\\1.", v) else v
  }
  p_valor <- function(p, d = 2) if (p < 0.001) paste("p", p_tab(p)) else paste("p =", p_tab(p, d))
  meses_nome <- switch(idioma,
    pt = c("janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro",
           "novembro", "dezembro"),
    es = c("enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre",
           "noviembre", "diciembre"),
    en = c("January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
           "November", "December"))
  meses_abrev <- switch(idioma,
    pt = c("jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"),
    es = c("ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"),
    en = substr(meses_nome, 1, 3))
  mes_ano <- function(m) {
    d <- as.Date(paste0(substr(m, 1, 7), "-01"))
    mes <- meses_nome[as.integer(format(d, "%m"))]
    if (ingles) paste(mes, format(d, "%Y")) else paste(mes, "de", format(d, "%Y"))
  }
  data_longa <- function(d) {
    d <- as.Date(d)
    mes <- meses_nome[as.integer(format(d, "%m"))]
    if (ingles) paste0(mes, " ", as.integer(format(d, "%d")), ", ", format(d, "%Y"))
    else paste(as.integer(format(d, "%d")), "de", mes, "de", format(d, "%Y"))
  }

  t <- switch(idioma,
    pt = list(
      motivos = c(`Salário e benefícios` = "Salário e benefícios", `Proposta de outra empresa` = "Proposta de outra empresa",
                  `Liderança e gestor` = "Liderança e gestor", `Jornada e escala` = "Jornada e escala",
                  Deslocamento = "Deslocamento", `Crescimento e carreira` = "Crescimento e carreira",
                  `Ambiente e equipe` = "Ambiente e equipe", `Motivos pessoais e família` = "Motivos pessoais e família",
                  `Outros motivos` = "Outros motivos"),
      unidades = c(CD = "CD", ESC = "ESC"),
      areas = c(Vendas = "Vendas", `Operações` = "Operações", Recebimento = "Recebimento", `Expedição` = "Expedição",
                Administrativo = "Administrativo"),
      grupos = c(`Demais gerências` = "Demais gerências", `Outras gerências de Vendas` = "Outras gerências de Vendas",
                 `Noite, 6x1` = "Noite, escala 6x1", `Noite, outras escalas` = "Noite, outras escalas",
                 `Dia, 6x1` = "Dia, escala 6x1", `Dia, outras escalas` = "Dia, outras escalas"),
      prioridades = c(Alta = "Alta", `Média` = "Média", Acompanhar = "Acompanhar"),
      sinais = c(`Taxa voluntária` = "Taxa voluntária", `Saídas até 90 dias` = "Saídas até 90 dias"),
      sufixos = c(`na estimativa` = "na estimativa", `cruzamento com a gerência` = "cruzamento com a gerência"),
      g_total = "Total", g_voluntaria = "Voluntária", g_todas = "Todas as respostas",
      g_nota_baixa = "Nota 1 ou 2 ao gestor", g_dias = "Dias de casa", g_troca = "troca de gestor",
      capa_titulo = "Motivação de\ndesligamento",
      capa_subtitulo = "Cestária Supermercados, 2024 e 2025",
      capa_frase = \(lid, sal) paste0("Com nota baixa ao gestor, liderança\ne gestor é o motivo de ", lid,
                                     " das saídas;\nsalário, de ", sal, "."),
      capa_grafico = "Motivo principal das saídas voluntárias",
      capa_rodape = "Empresa, pessoas e dados fictícios · Felipe Fonseca · @fefonsek",
      nomes_prioridades = c("Ordem", "Gerência", "Prioridade", "Sinais", "Taxa voluntária ao mês", "Saídas até 90 dias",
                            "Resposta", "Liderança e gestor"),
      nomes_prioridades_pdf = c("", "Gerência", "Prioridade", "Sinais", "Taxa vol./mês", "Até 90 dias", "Liderança"),
      nomes_ponderacao = c("Motivo", "Sem ponderação", "Ponderado"),
      nomes_or = c("Termo", "Razão de chances", "IC 95%", "p"),
      nomes_resposta = c("Grupo", "Saídas", "Responderam", "Taxa de resposta (IC 95%)"),
      frase_acompanhar = \(g, motivo, taxa, emp, taxa_acima, p90, emp90, p90_acima) paste0(
        "A ", g, " tem um destaque de \"", tolower(motivo), "\" no cruzamento de motivo com gerência, mas continua em ",
        "\"Acompanhar\": em 2025, a taxa voluntária (", taxa, " ao mês) fica ",
        if (taxa_acima) "acima da empresa (" else "abaixo da empresa (", emp, ")",
        if (taxa_acima) " só na estimativa" else "", ", as saídas até 90 dias (", p90, ") ficam ",
        if (p90_acima) "acima" else "abaixo", " da empresa (", emp90, "), e a parte de \"", tolower(motivo),
        "\" entre as respostas de 2025 não passa da empresa no limite inferior do intervalo."),
      voluntarias = "Voluntárias (pedido ou acordo)", involuntarias = "Involuntárias (dispensa ou término de experiência)",
      csv_colunas = NULL),
    es = list(
      motivos = c(`Salário e benefícios` = "Salario y beneficios", `Proposta de outra empresa` = "Oferta de otra empresa",
                  `Liderança e gestor` = "Liderazgo y jefatura", `Jornada e escala` = "Jornada y escala",
                  Deslocamento = "Traslado", `Crescimento e carreira` = "Crecimiento y carrera",
                  `Ambiente e equipe` = "Ambiente y equipo", `Motivos pessoais e família` = "Motivos personales y familia",
                  `Outros motivos` = "Otros motivos"),
      unidades = c(CD = "CD", ESC = "OC"),
      areas = c(Vendas = "Ventas", `Operações` = "Operaciones", Recebimento = "Recepción", `Expedição` = "Despacho",
                Administrativo = "Administración"),
      grupos = c(`Demais gerências` = "Demás gerencias", `Outras gerências de Vendas` = "Otras gerencias de Ventas",
                 `Noite, 6x1` = "Noche, escala 6x1", `Noite, outras escalas` = "Noche, otras escalas",
                 `Dia, 6x1` = "Día, escala 6x1", `Dia, outras escalas` = "Día, otras escalas"),
      prioridades = c(Alta = "Alta", `Média` = "Media", Acompanhar = "Seguimiento"),
      sinais = c(`Taxa voluntária` = "Tasa voluntaria", `Saídas até 90 dias` = "Salidas hasta 90 días"),
      sufixos = c(`na estimativa` = "en la estimación", `cruzamento com a gerência` = "cruce con la gerencia"),
      g_total = "Total", g_voluntaria = "Voluntaria", g_todas = "Todas las respuestas",
      g_nota_baixa = "Nota 1 o 2 al líder", g_dias = "Días de antigüedad", g_troca = "cambio de líder",
      capa_titulo = "Motivos de\ndesvinculación",
      capa_subtitulo = "Cestária Supermercados, 2024 y 2025",
      capa_frase = \(lid, sal) paste0("Con nota baja al líder, liderazgo y\njefatura es el motivo de ", lid,
                                     " de las salidas;\nsalario, de ", sal, "."),
      capa_grafico = "Motivo principal de las salidas voluntarias",
      capa_rodape = "Empresa, personas y datos ficticios · Felipe Fonseca · @fefonsek",
      nomes_prioridades = c("Orden", "Gerencia", "Prioridad", "Señales", "Tasa voluntaria al mes", "Salidas hasta 90 días",
                            "Respuesta", "Liderazgo y jefatura"),
      nomes_prioridades_pdf = c("", "Gerencia", "Prioridad", "Señales", "Tasa vol./mes", "Hasta 90 días", "Liderazgo"),
      nomes_ponderacao = c("Motivo", "Sin ponderación", "Ponderado"),
      nomes_or = c("Término", "Razón de probabilidades", "IC 95%", "p"),
      nomes_resposta = c("Grupo", "Salidas", "Respondieron", "Tasa de respuesta (IC 95%)"),
      frase_acompanhar = \(g, motivo, taxa, emp, taxa_acima, p90, emp90, p90_acima) paste0(
        "La gerencia ", g, " tiene un destacado en \"", tolower(motivo), "\" en el cruce de motivo con gerencia, pero ",
        "sigue en \"Seguimiento\": en 2025, la tasa voluntaria (", taxa, " al mes) queda ",
        if (taxa_acima) "por encima de la empresa (" else "por debajo de la empresa (", emp, ")",
        if (taxa_acima) " solo en la estimación" else "", ", las salidas hasta 90 días (", p90, ") quedan ",
        if (p90_acima) "por encima" else "por debajo", " de la empresa (", emp90, "), y la parte de \"", tolower(motivo),
        "\" entre las respuestas de 2025 no supera a la empresa en el límite inferior del intervalo."),
      voluntarias = "Voluntarias (renuncia o acuerdo)",
      involuntarias = "Involuntarias (despido o fin del período de prueba)",
      csv_colunas = c(ordem = "orden", gerencia = "gerencia", unidade = "unidad", prioridade = "prioridad",
                      sinais = "senales", headcount_medio = "dotacion_media", saidas_voluntarias = "salidas_voluntarias",
                      taxa_voluntaria_mensal_pct = "tasa_voluntaria_mensual_pct", taxa_ic95_inf = "tasa_ic95_inf",
                      taxa_ic95_sup = "tasa_ic95_sup", admitidos = "contratados",
                      saidas_ate_90_dias_pct = "salidas_hasta_90_dias_pct", saidas_90_ic95_inf = "salidas_90_ic95_inf",
                      saidas_90_ic95_sup = "salidas_90_ic95_sup", taxa_resposta_pct = "tasa_respuesta_pct",
                      lideranca_gestor_pct = "liderazgo_jefatura_pct", jornada_escala_pct = "jornada_escala_pct",
                      nota_media_gestor = "nota_media_lider")),
    en = list(
      motivos = c(`Salário e benefícios` = "Pay and benefits", `Proposta de outra empresa` = "Offer from another company",
                  `Liderança e gestor` = "Leadership and manager", `Jornada e escala` = "Hours and schedule",
                  Deslocamento = "Commute", `Crescimento e carreira` = "Growth and career",
                  `Ambiente e equipe` = "Work environment and team", `Motivos pessoais e família` = "Personal and family reasons",
                  `Outros motivos` = "Other reasons"),
      unidades = c(CD = "DC", ESC = "HQ"),
      areas = c(Vendas = "Sales", `Operações` = "Operations", Recebimento = "Receiving", `Expedição` = "Shipping",
                Administrativo = "Administration"),
      grupos = c(`Demais gerências` = "Other departments", `Outras gerências de Vendas` = "Other Sales departments",
                 `Noite, 6x1` = "Night, 6x1 schedule", `Noite, outras escalas` = "Night, other schedules",
                 `Dia, 6x1` = "Day, 6x1 schedule", `Dia, outras escalas` = "Day, other schedules"),
      prioridades = c(Alta = "High", `Média` = "Medium", Acompanhar = "Monitor"),
      sinais = c(`Taxa voluntária` = "Voluntary rate", `Saídas até 90 dias` = "Exits within 90 days"),
      sufixos = c(`na estimativa` = "point estimate", `cruzamento com a gerência` = "reason by department"),
      g_total = "Total", g_voluntaria = "Voluntary", g_todas = "All responses",
      g_nota_baixa = "Manager rated 1 or 2", g_dias = "Days of tenure", g_troca = "manager change",
      capa_titulo = "Why people\nleave",
      capa_subtitulo = "Cestária Supermercados, 2024 and 2025",
      capa_frase = \(lid, sal) paste0("When the manager is rated low,\nleadership and manager is the reason\nfor ", lid,
                                     " of exits; pay, for ", sal, "."),
      capa_grafico = "Main reason for voluntary exits",
      capa_rodape = "Fictional company, people and data · Felipe Fonseca · @fefonsek",
      nomes_prioridades = c("Rank", "Department", "Priority", "Signals", "Monthly voluntary rate", "Exits within 90 days",
                            "Response", "Leadership and manager"),
      nomes_prioridades_pdf = c("", "Department", "Priority", "Signals", "Vol. rate/month", "Within 90 days", "Leadership"),
      nomes_ponderacao = c("Reason", "Unweighted", "Weighted"),
      nomes_or = c("Term", "Odds ratio", "95% CI", "p"),
      nomes_resposta = c("Group", "Exits", "Responded", "Response rate (95% CI)"),
      frase_acompanhar = \(g, motivo, taxa, emp, taxa_acima, p90, emp90, p90_acima) paste0(
        g, " stands out for \"", tolower(motivo), "\" in the reason by department cross-tab, but stays at \"Monitor\": ",
        "in 2025, its voluntary rate (", taxa, " a month) is ",
        if (taxa_acima) "above the company (" else "below the company (", emp, ")",
        if (taxa_acima) " only in the point estimate" else "", ", its exits within 90 days (", p90, ") are ",
        if (p90_acima) "above" else "below", " the company (", emp90, "), and the share of \"", tolower(motivo),
        "\" among its 2025 responses does not exceed the company at the lower bound of the interval."),
      voluntarias = "Voluntary (resignation or mutual agreement)",
      involuntarias = "Involuntary (dismissal or end of probation)",
      csv_colunas = c(ordem = "rank", gerencia = "department", unidade = "site", prioridade = "priority",
                      sinais = "signals", headcount_medio = "average_headcount", saidas_voluntarias = "voluntary_exits",
                      taxa_voluntaria_mensal_pct = "monthly_voluntary_rate_pct", taxa_ic95_inf = "rate_ci95_low",
                      taxa_ic95_sup = "rate_ci95_high", admitidos = "hires",
                      saidas_ate_90_dias_pct = "exits_within_90_days_pct", saidas_90_ic95_inf = "exits_90_ci95_low",
                      saidas_90_ic95_sup = "exits_90_ci95_high", taxa_resposta_pct = "response_rate_pct",
                      lideranca_gestor_pct = "leadership_manager_pct", jornada_escala_pct = "hours_schedule_pct",
                      nota_media_gestor = "average_manager_rating"))
  )

  # Nome de uma gerência ou de um grupo na língua: "L3 Operações" vira
  # "L3 Operaciones" ou "L3 Operations"; "CD Expedição", "DC Shipping".
  unidade <- function(x) traduzir(x, t$unidades)
  gerencia <- function(x) {
    x <- as.character(x)
    vapply(x, function(g) {
      if (g %in% names(t$grupos)) return(unname(t$grupos[g]))
      partes <- strsplit(g, " ", fixed = TRUE)[[1]]
      if (length(partes) == 2 && partes[2] %in% names(t$areas)) paste(unidade(partes[1]), t$areas[[partes[2]]]) else g
    }, "", USE.NAMES = FALSE)
  }
  # Um sinal na língua: "Taxa voluntária (na estimativa)" vira
  # "Tasa voluntaria (en la estimación)"; motivos usam o dicionário de motivos.
  sinal <- function(x) {
    vapply(as.character(x), function(s) {
      base <- sub(" \\(.*\\)$", "", s)
      sufixo <- if (grepl("\\(.*\\)$", s)) sub(".*\\((.*)\\)$", "\\1", s) else NA
      base <- traduzir(base, c(t$sinais, t$motivos))
      if (is.na(sufixo)) base else paste0(base, " (", traduzir(sufixo, t$sufixos), ")")
    }, "", USE.NAMES = FALSE)
  }
  c(t, list(idioma = idioma, num = num, pct = pct, ic = ic, num_ic = num_ic, p_tab = p_tab, p_valor = p_valor,
            meses_nome = meses_nome, meses_abrev = meses_abrev, mes_ano = mes_ano, data_longa = data_longa,
            unidade = unidade, gerencia = gerencia, sinal = sinal, menos_de_10 = "<10"))
}

# Traduz um vetor de valores em português com um dos dicionários acima; o que
# não estiver no dicionário fica como está.
traduzir <- function(x, dicionario) {
  x <- as.character(x)
  ifelse(x %in% names(dicionario), unname(dicionario[x]), x)
}
