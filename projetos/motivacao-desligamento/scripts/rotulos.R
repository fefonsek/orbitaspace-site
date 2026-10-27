# Caso Motivação de desligamento: formatos e textos curtos de cada língua, no
# mesmo espírito do rotulos.R do caso Auditoria.
# - Formatos de número, de porcentagem e de data.
# - Nomes dos motivos, dos grupos e das prioridades. As chaves são os valores
#   em português que scripts/analise.R grava; os números continuam vindo de
#   resultados/desligamento.rds.
# - Rótulos dos gráficos e da capa e cabeçalhos das tabelas.
# O texto corrido fica em cada index.qmd (página) e em relatorio/textos_*.yml
# (relatório em PDF). Por enquanto só o português; ES e EN entram depois.

rotulos <- function(idioma = c("pt", "es", "en")) {
  idioma <- match.arg(idioma)
  ingles <- idioma == "en"
  num <- function(x, d = 0) formatC(x, format = "f", digits = d, big.mark = if (ingles) "," else ".",
                                    decimal.mark = if (ingles) "." else ",")
  pct <- function(x, d = 1) paste0(num(x, d), "%")
  # Intervalo de confiança: "de 22,5% a 28,9%".
  ic <- function(inf, sup, d = 1) paste0(num(inf, d), "% a ", num(sup, d), "%")
  meses_nome <- c("janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro",
                  "outubro", "novembro", "dezembro")
  meses_abrev <- c("jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez")
  mes_ano <- function(m) {
    d <- as.Date(paste0(substr(m, 1, 7), "-01"))
    paste(meses_nome[as.integer(format(d, "%m"))], "de", format(d, "%Y"))
  }
  data_longa <- function(d) {
    d <- as.Date(d)
    paste(as.integer(format(d, "%d")), "de", meses_nome[as.integer(format(d, "%m"))], "de", format(d, "%Y"))
  }

  t <- list(
    motivos = c(`Salário e benefícios` = "Salário e benefícios", `Proposta de outra empresa` = "Proposta de outra empresa",
                `Liderança e gestor` = "Liderança e gestor", `Jornada e escala` = "Jornada e escala",
                Deslocamento = "Deslocamento", `Crescimento e carreira` = "Crescimento e carreira",
                `Ambiente e equipe` = "Ambiente e equipe", `Motivos pessoais e família` = "Motivos pessoais e família",
                `Outros motivos` = "Outros motivos"),
    grupos = c(`Demais gerências` = "Demais gerências", `Outras gerências de Vendas` = "Outras gerências de Vendas",
               `Noite, 6x1` = "Noite, escala 6x1", `Noite, outras escalas` = "Noite, outras escalas",
               `Dia, 6x1` = "Dia, escala 6x1", `Dia, outras escalas` = "Dia, outras escalas"),
    prioridades = c(Alta = "Alta", `Média` = "Média", Acompanhar = "Acompanhar"),
    sinais = c(`Taxa voluntária` = "Taxa voluntária", `Saídas até 90 dias` = "Saídas até 90 dias",
               `Liderança e gestor` = "Liderança e gestor", `Jornada e escala` = "Jornada e escala"),
    tipos = c(`Pedido de demissão` = "Pedido de demissão", Acordo = "Acordo",
              `Dispensa sem justa causa` = "Dispensa sem justa causa", `Término de experiência` = "Término de experiência"),
    g_total = "Total", g_voluntaria = "Voluntária", g_todas = "Todas as respostas",
    g_nota_baixa = "Nota 1 ou 2 ao gestor", g_coorte = \(a) paste("Admitidos em", a), g_dias = "Dias de casa",
    g_90 = "90 dias", g_troca = "troca de gestor", g_mm3 = "Saídas voluntárias por 100 pessoas, média de 3 meses",
    g_taxa_mes = "Desligamentos por 100 pessoas no mês", g_inc = "Saíram por vontade própria",
    g_resposta = "Taxa de resposta", g_jornada = "Jornada e escala como motivo principal",
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
    # Por que uma gerência com sinal continua em "Acompanhar".
    frase_acompanhar = \(g, motivo, taxa, emp, taxa_acima, p90, emp90, p90_acima) paste0(
      "A ", g, " tem um destaque de \"", tolower(motivo), "\" no cruzamento de motivo com gerência, mas continua em ",
      "\"Acompanhar\": em 2025, a taxa voluntária (", taxa, " ao mês) fica ",
      if (taxa_acima) "acima da empresa (" else "abaixo da empresa (", emp, ")",
      if (taxa_acima) " só na estimativa" else "", ", as saídas até 90 dias (", p90, ") ficam ",
      if (p90_acima) "acima" else "abaixo", " da empresa (", emp90, "), e a parte de \"", tolower(motivo),
      "\" entre as respostas de 2025 não passa da empresa no limite inferior do intervalo."),
    voluntarias = "Voluntárias (pedido ou acordo)", involuntarias = "Involuntárias (dispensa ou término de experiência)",
    menos_de_10 = "<10"
  )
  c(t, list(idioma = idioma, num = num, pct = pct, ic = ic, meses_nome = meses_nome, meses_abrev = meses_abrev,
            mes_ano = mes_ano, data_longa = data_longa))
}

# Traduz um vetor de valores em português com um dos dicionários acima; o que
# não estiver no dicionário fica como está.
traduzir <- function(x, dicionario) {
  x <- as.character(x)
  ifelse(x %in% names(dicionario), unname(dicionario[x]), x)
}
