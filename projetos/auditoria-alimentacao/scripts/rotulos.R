# Caso Auditoria: formatos e textos curtos de cada língua (PT, ES, EN), no
# mesmo espírito do rotulos.R dos casos TCC e Indicadores.
# - Formatos de número, de moeda e de data.
# - Nomes das conclusões, dos motivos e dos tipos de recarga. As chaves são os
#   valores em português que scripts/auditoria.R grava; os números continuam
#   vindo de resultados/auditoria.rds.
# - Rótulos dos gráficos e da capa, cabeçalhos e linhas das tabelas fixas, a
#   frase de julho e as colunas do CSV de casos.
# O texto corrido fica em cada index.qmd (página) e em relatorio/textos_*.yml
# (relatório em PDF).

rotulos <- function(idioma = c("pt", "es", "en")) {
  idioma <- match.arg(idioma)
  ingles <- idioma == "en"
  num <- function(x, d = 0) formatC(x, format = "f", digits = d, big.mark = if (ingles) "," else ".",
                                    decimal.mark = if (ingles) "." else ",")
  pct <- function(x, d = 1) paste0(num(x, d), "%")
  # O espaço depois de "R$" é inseparável, para o valor não quebrar de linha.
  rs <- "R$ "
  palavra <- switch(idioma, pt = c(mil = "mil", milhoes = "milhões"), es = c(mil = "mil", milhoes = "millones"),
                    en = c(mil = "thousand", milhoes = "million"))
  # R$ 7,63 milhões, R$ 305 mil, R$ 7 mil, R$ 52 (e o equivalente em ES e EN)
  reais <- function(x, d_milhao = 2) {
    vapply(x, function(v) {
      if (abs(v) >= 1e6) paste0(rs, num(v / 1e6, d_milhao), " ", palavra[["milhoes"]])
      else if (abs(v) >= 1e3) paste0(rs, num(v / 1e3, 0), " ", palavra[["mil"]])
      else paste0(rs, num(v, if (v != round(v)) 2 else 0))
    }, "")
  }
  reais_exato <- function(x, d = 0) paste0(rs, num(x, d))

  meses_nome <- switch(idioma,
    pt = c("janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"),
    es = c("enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"),
    en = c("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"))
  meses_abrev <- switch(idioma,
    pt = c("jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"),
    es = c("ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"),
    en = substr(meses_nome, 1, 3))
  # Período de uma pessoa na tabela de casos. Em inglês, mês por extenso
  # abreviado, para não confundir dia e mês.
  periodo <- function(inicio, fim) {
    inicio <- as.Date(inicio); fim <- as.Date(fim)
    if (ingles) {
      md <- \(d) paste(meses_abrev[as.integer(format(d, "%m"))], as.integer(format(d, "%d")))
      ifelse(format(inicio, "%Y") == format(fim, "%Y"),
             paste0(md(inicio), " to ", md(fim), ", ", format(fim, "%Y")),
             paste0(md(inicio), ", ", format(inicio, "%Y"), " to ", md(fim), ", ", format(fim, "%Y")))
    } else {
      paste(format(inicio, "%d/%m/%Y"), "a", format(fim, "%d/%m/%Y"))
    }
  }
  data_longa <- function(d) {
    d <- as.Date(d)
    m <- meses_nome[as.integer(format(d, "%m"))]
    if (ingles) paste0(m, " ", as.integer(format(d, "%d")), ", ", format(d, "%Y"))
    else paste(as.integer(format(d, "%d")), "de", m, "de", format(d, "%Y"))
  }

  t <- switch(idioma,
    pt = list(
      conclusoes = c(Indevido = "Indevido", Revisar = "Revisar", `Atenção` = "Atenção", Regular = "Regular"),
      motivos = c(Duplicidade = "Duplicidade", `Jantar sem pernoite` = "Jantar sem pernoite",
                  `Pessoa fora do trabalho` = "Pessoa fora do trabalho", `Acima do teto` = "Acima do teto",
                  `Extra sem justificativa` = "Extra sem justificativa", `Sem lastro de campo` = "Sem lastro de campo",
                  `Justificativa vaga em base e mês acima da faixa` = "Justificativa vaga em base e mês acima da faixa",
                  `Score 2 ou mais` = "Score 2 ou mais"),
      motivos_curtos = c(Duplicidade = "Duplicidade", `Jantar sem pernoite` = "Sem pernoite",
                         `Pessoa fora do trabalho` = "Fora do trabalho", `Acima do teto` = "Acima do teto",
                         `Extra sem justificativa` = "Extra s/ justif.", `Sem lastro de campo` = "Sem lastro"),
      legenda_motivo = "Motivo",
      tipos = c(`Almoço` = "Almoço", Jantar = "Jantar", Extra = "Extra"),
      justificativas = c("deslocamento acima de 300 km", "jornada estendida em mais de 2 horas"),
      g_troca = "troca de sistema", g_pago = "Valor pago", g_sem = "Sem o indevido", g_base = "Base",
      capa_titulo = "Auditoria do benefício\nde alimentação\nem campo",
      capa_subtitulo = "Fiorena Redes Elétricas, 2025",
      capa_frase = \(valor, p) paste0(valor, " pagos fora da regra,\n", p, " do valor do ano."),
      capa_grafico = "Valor pago por dia em campo, 2025",
      capa_rodape = "Empresa, pessoas e dados fictícios · Felipe Fonseca · @fefonsek",
      tabela_conclusoes = tibble::tribble(
        ~conclusao, ~quando, ~acao,
        "Indevido", "Violou uma regra objetiva", "Estornar ou recuperar, conforme a política da empresa e com apoio do RH e do jurídico",
        "Revisar", "Nenhuma regra violada, mas sem lastro de campo ou com dois sinais ou mais", "A base confirma ou corrige em até 15 dias",
        "Atenção", "Um sinal só, sem regra violada", "Entra na amostra do próximo mês",
        "Regular", "Nenhum sinal", "Nada a fazer"),
      nomes_conclusoes = c("Conclusão", "Quando", "O que fazer"),
      recomendacoes = tibble::tribble(
        ~achado, ~correcao, ~responsavel,
        "Duplicidade depois da troca de sistema", "Bloqueio no sistema de uma recarga por tipo, pessoa e dia", "TI e fornecedor do cartão",
        "Cadastro atrasado", "Lista diária de férias, afastamentos e desligamentos enviada ao sistema de recarga", "RH",
        "Jantar sem pernoite", "Jantar só liberado quando o diário registra pernoite", "Operação e supervisores das bases",
        "Acima do teto", "Teto diário aplicado pelo próprio sistema", "TI",
        "Justificativa vaga", "Justificativa escolhida numa lista fechada, não digitada", "Controladoria",
        "Valores já pagos como indevido", "Estorno ou recuperação conforme a política da empresa", "RH, com apoio do jurídico"),
      nomes_recomendacoes = c("Achado", "Correção recomendada", "Responsável"),
      nomes_top = c("Conclusão", "Matrícula", "Base", "Período", "Recargas", "Valor", "Motivo"),
      nomes_tabela_pdf = c("Conclusão", "Recargas", "Valor", "% do valor"),
      julho = \(outro, ferias, ferias_med, pessoas, pessoas_med, de, ate) paste0(
        "A queda de julho tem causa nos dados: julho e ", outro, " são os meses com mais gente de férias (em julho, ",
        ferias, " eletricistas por dia útil, contra ", ferias_med, " na mediana do ano), e cada equipe saiu a campo com ",
        pessoas, " pessoas, contra ", pessoas_med, " na mediana. O valor por pessoa em campo não caiu: ficou entre ",
        de, " e ", ate, " de janeiro a julho."),
      csv_colunas = NULL),
    es = list(
      conclusoes = c(Indevido = "Indebido", Revisar = "Revisar", `Atenção` = "Atención", Regular = "Conforme"),
      motivos = c(Duplicidade = "Duplicidad", `Jantar sem pernoite` = "Cena sin pernocte",
                  `Pessoa fora do trabalho` = "Persona fuera de servicio", `Acima do teto` = "Por encima del tope",
                  `Extra sem justificativa` = "Extra sin justificación", `Sem lastro de campo` = "Sin respaldo de campo",
                  `Justificativa vaga em base e mês acima da faixa` = "Justificación vaga en base y mes por encima del rango",
                  `Score 2 ou mais` = "Puntaje de 2 o más"),
      motivos_curtos = c(Duplicidade = "Duplicidad", `Jantar sem pernoite` = "Sin pernocte",
                         `Pessoa fora do trabalho` = "Fuera de servicio", `Acima do teto` = "Sobre el tope",
                         `Extra sem justificativa` = "Extra s/ justif.", `Sem lastro de campo` = "Sin respaldo"),
      legenda_motivo = "Motivo",
      tipos = c(`Almoço` = "Almuerzo", Jantar = "Cena", Extra = "Extra"),
      justificativas = c("desplazamiento de más de 300 km", "jornada extendida en más de 2 horas"),
      g_troca = "cambio de sistema", g_pago = "Valor pagado", g_sem = "Sin lo indebido", g_base = "Base",
      capa_titulo = "Auditoría del beneficio\nde alimentación\nen campo",
      capa_subtitulo = "Fiorena Redes Elétricas, 2025",
      capa_frase = \(valor, p) paste0(valor, " pagados fuera de la regla,\n", p, " del valor del año."),
      capa_grafico = "Valor pagado por día en campo, 2025",
      capa_rodape = "Empresa, personas y datos ficticios · Felipe Fonseca · @fefonsek",
      tabela_conclusoes = tibble::tribble(
        ~conclusao, ~quando, ~acao,
        "Indebido", "Violó una regla objetiva", "Revertir o recuperar, según la política de la empresa y con apoyo de RR. HH. y del área legal",
        "Revisar", "Ninguna regla violada, pero sin respaldo de campo o con dos señales o más", "La base confirma o corrige en un plazo de 15 días",
        "Atención", "Una sola señal, sin regla violada", "Entra en la muestra del mes siguiente",
        "Conforme", "Ninguna señal", "Nada que hacer"),
      nomes_conclusoes = c("Conclusión", "Cuándo", "Qué hacer"),
      recomendacoes = tibble::tribble(
        ~achado, ~correcao, ~responsavel,
        "Duplicidad después del cambio de sistema", "Bloqueo en el sistema de una recarga por tipo, persona y día", "TI y proveedor de la tarjeta",
        "Registro de personal con atraso", "Lista diaria de vacaciones, ausencias y desvinculaciones enviada al sistema de recargas", "RR. HH.",
        "Cena sin pernocte", "Cena habilitada solo cuando el diario registra pernocte", "Operaciones y supervisores de las bases",
        "Por encima del tope", "Tope diario aplicado por el propio sistema", "TI",
        "Justificación vaga", "Justificación elegida de una lista cerrada, no escrita a mano", "Contraloría",
        "Valores ya pagados como indebidos", "Reversión o recuperación según la política de la empresa", "RR. HH., con apoyo del área legal"),
      nomes_recomendacoes = c("Hallazgo", "Corrección recomendada", "Responsable"),
      nomes_top = c("Conclusión", "Matrícula", "Base", "Período", "Recargas", "Valor", "Motivo"),
      nomes_tabela_pdf = c("Conclusión", "Recargas", "Valor", "% del valor"),
      julho = \(outro, ferias, ferias_med, pessoas, pessoas_med, de, ate) paste0(
        "La caída de julio tiene una causa en los datos: julio y ", outro, " son los meses con más personas de vacaciones (en julio, ",
        ferias, " electricistas por día hábil, frente a ", ferias_med, " en la mediana del año), y cada cuadrilla salió a campo con ",
        pessoas, " personas, frente a ", pessoas_med, " en la mediana. El valor por persona en campo no bajó: se mantuvo entre ",
        de, " y ", ate, " de enero a julio."),
      csv_colunas = c(id = "id", matricula = "matricula", base = "base", dia_referencia = "dia_referencia",
                      data_recarga = "fecha_recarga", tipo = "tipo", valor = "valor", valor_indevido = "valor_indebido",
                      conclusao = "conclusion", motivo = "motivo", score = "puntaje", justificativa = "justificacion")),
    en = list(
      conclusoes = c(Indevido = "Improper", Revisar = "Review", `Atenção` = "Watch", Regular = "Compliant"),
      motivos = c(Duplicidade = "Duplicate", `Jantar sem pernoite` = "Dinner, no overnight stay",
                  `Pessoa fora do trabalho` = "Person not on duty", `Acima do teto` = "Over the cap",
                  `Extra sem justificativa` = "Extra, no justification", `Sem lastro de campo` = "No field record",
                  `Justificativa vaga em base e mês acima da faixa` = "Vague justification at a base and month above the range",
                  `Score 2 ou mais` = "Score of 2 or more"),
      motivos_curtos = c(Duplicidade = "Duplicate", `Jantar sem pernoite` = "No overnight",
                         `Pessoa fora do trabalho` = "Not on duty", `Acima do teto` = "Over cap",
                         `Extra sem justificativa` = "Extra, no just.", `Sem lastro de campo` = "No field record"),
      legenda_motivo = "Reason",
      tipos = c(`Almoço` = "Lunch", Jantar = "Dinner", Extra = "Extra"),
      justificativas = c("travel of more than 300 km", "workday extended by more than 2 hours"),
      g_troca = "system switch", g_pago = "Amount paid", g_sem = "Without improper", g_base = "Base",
      capa_titulo = "Field meal\nallowance audit",
      capa_subtitulo = "Fiorena Redes Elétricas, 2025",
      capa_frase = \(valor, p) paste0(valor, " paid outside the rules,\n", p, " of the year's total."),
      capa_grafico = "Amount paid per field day, 2025",
      capa_rodape = "Fictional company, people and data · Felipe Fonseca · @fefonsek",
      tabela_conclusoes = tibble::tribble(
        ~conclusao, ~quando, ~acao,
        "Improper", "Broke an objective rule", "Reverse or recover, according to company policy and with support from HR and legal",
        "Review", "No rule broken, but no field record, or two signals or more", "The base confirms or corrects it within 15 days",
        "Watch", "A single signal, no rule broken", "Goes into next month's sample",
        "Compliant", "No signal", "Nothing to do"),
      nomes_conclusoes = c("Conclusion", "When", "What to do"),
      recomendacoes = tibble::tribble(
        ~achado, ~correcao, ~responsavel,
        "Duplicates after the system switch", "System block allowing one top-up per type, person and day", "IT and the card provider",
        "Late HR roster", "Daily list of vacations, leaves and terminations sent to the top-up system", "HR",
        "Dinner with no overnight stay", "Dinner released only when the field log records an overnight stay", "Operations and base supervisors",
        "Over the cap", "Daily cap enforced by the system itself", "IT",
        "Vague justification", "Justification picked from a closed list, not typed in", "Financial control",
        "Amounts already paid as improper", "Reversal or recovery according to company policy", "HR, with support from legal"),
      nomes_recomendacoes = c("Finding", "Recommended fix", "Owner"),
      nomes_top = c("Conclusion", "Employee ID", "Base", "Period", "Top-ups", "Amount", "Reason"),
      nomes_tabela_pdf = c("Conclusion", "Top-ups", "Amount", "% of amount"),
      julho = \(outro, ferias, ferias_med, pessoas, pessoas_med, de, ate) paste0(
        "The July dip has a cause in the data: July and ", outro, " are the months with the most people on vacation (in July, ",
        ferias, " lineworkers per business day, against ", ferias_med, " in the median month), and each crew went out with ",
        pessoas, " people, against ", pessoas_med, " in the median. The amount per person in the field did not fall: it stayed between ",
        de, " and ", ate, " from January to July."),
      csv_colunas = c(id = "id", matricula = "employee_id", base = "base", dia_referencia = "day_worked",
                      data_recarga = "topup_date", tipo = "type", valor = "amount", valor_indevido = "improper_amount",
                      conclusao = "conclusion", motivo = "reason", score = "risk_score", justificativa = "justification"))
  )
  c(t, list(idioma = idioma, num = num, pct = pct, reais = reais, reais_exato = reais_exato,
            meses_nome = meses_nome, meses_abrev = meses_abrev, periodo = periodo, data_longa = data_longa))
}

# Traduz um vetor de valores em português com um dos dicionários acima; o que
# não estiver no dicionário fica como está.
traduzir <- function(x, dicionario) {
  x <- as.character(x)
  ifelse(x %in% names(dicionario), unname(dicionario[x]), x)
}
