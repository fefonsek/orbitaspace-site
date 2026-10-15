# Tabelas e gráficos do caso TCC, iguais nas três línguas. Cada função
# recebe os resultados (res, lidos de resultados/analise.rds) e os textos do
# idioma (tx, de rotulos.R). Não há cálculo estatístico aqui: só apresentação.

## ---- tema ----
# Paleta da marca, só tons frios.
cor <- c(profundo = "#1a1a2e", azul = "#3473C0", medio = "#7a90c4",
         lavanda = "#cacfee", cinza = "#4a4a63", grade = "#e4e6ef")
preparar <- function(tx) {
  theme_set(
    theme_minimal(base_family = "Montserrat", base_size = 12) +
      theme(text = element_text(colour = cor[["profundo"]]),
            axis.text = element_text(colour = cor[["cinza"]]),
            panel.grid.minor = element_blank(),
            panel.grid.major = element_line(colour = cor[["grade"]], linewidth = 0.4),
            plot.background = element_blank(), panel.background = element_blank(),
            strip.text = element_text(face = "bold", hjust = 0, colour = cor[["profundo"]]),
            plot.title.position = "plot", legend.position = "top")
  )
  ingles <- tx$idioma == "en"
  invisible(theme_gtsummary_language(tx$gtsummary, decimal.mark = if (ingles) "." else ",",
                                     big.mark = if (ingles) "," else "."))
}

# Troca os valores em português dos dados pelos do idioma. Sem "ordem", as
# categorias seguem a ordem alfabética do original (como o factor() faria).
traduzir <- function(x, mapa, ordem = FALSE) {
  x <- as.character(x)
  niveis <- if (ordem) unname(mapa) else unname(mapa[sort(unique(x))])
  factor(unname(mapa[x]), levels = niveis)
}

## ---- tabelas-limpeza ----
tabela_fluxo <- function(res, tx) {
  tibble(etapa = tx$etapas,
         excluidas = c("", res$excluidas, ""),
         restam = c(res$n_bruto, res$n_bruto - cumsum(res$excluidas), res$n_validas)) |>
    setNames(tx$fluxo) |>
    kable(align = c("l", "c", "c"))
}

tabela_grafias <- function(res, tx) {
  res$grafias |>
    transmute(padronizada = unname(tx$faixa[padronizada]),
              escritas = map_chr(escritas, \(e) paste0('"', e, '"', collapse = ", ")),
              pessoas) |>
    setNames(tx$grafias) |>
    kable(align = c("l", "l", "c"))
}

## ---- tabela-perfil ----
tabela_perfil <- function(res, tx) {
  res$d |>
    transmute(sexo = traduzir(sexo, tx$sexo),
              faixa = traduzir(faixa_etaria, tx$faixa),
              escolaridade = traduzir(escolaridade, tx$escolaridade, ordem = TRUE),
              funcao = traduzir(funcao, tx$funcao),
              turno = traduzir(turno, tx$turno, ordem = TRUE),
              tempo = traduzir(tempo_casa, tx$tempo, ordem = TRUE)) |>
    setNames(tx$perfil[c("sexo", "faixa", "escolaridade", "funcao", "turno", "tempo")]) |>
    tbl_summary(statistic = all_categorical() ~ "{n} ({p}%)") |>
    modify_header(label = tx$perfil[["titulo"]], stat_0 = tx$perfil[["n"]]) |>
    modify_footnote(everything() ~ NA) |>
    as_kable()
}

## ---- tabelas-escalas ----
tabela_confiab <- function(res, tx) {
  res$conf |>
    transmute(bloco = c(tx$blocos, REM_sem4 = tx$rem_sem4)[bloco], itens,
              alfa = tx$num1(alfa), omega = tx$num1(omega)) |>
    setNames(tx$conf) |>
    kable(align = c("l", "c", "c", "c"))
}

tabela_cargas <- function(res, tx) {
  as_tibble(res$cargas, rownames = "Item") |>
    mutate(across(-Item, \(v) if_else(abs(v) < 0.30, "", tx$num(v)))) |>
    setNames(c(tx$item, tx$abrev)) |>
    kable(align = c("l", rep("c", 5)))
}

## ---- tabelas-grupos ----
tabela_grupos <- function(res, tx) {
  res$grupos |>
    transmute(grupo = unname(c(tx$turno_grupo, tx$tempo)[grupo]), n, mediana = tx$num(mediana),
              iiq = paste(tx$num(q1), tx$ate, tx$num(q3))) |>
    setNames(tx$grupos) |>
    kable(align = c("l", "c", "c", "c"))
}

tabela_correl <- function(res, tx) {
  mat <- matrix(tx$num1(res$rho), nrow(res$rho), dimnames = list(tx$blocos, tx$abrev))
  mat[upper.tri(mat, diag = TRUE)] <- ""
  as_tibble(mat, rownames = tx$bloco) |>
    kable(align = c("l", rep("c", 5)))
}

## ---- tabelas-regressao ----
tabela_hipoteses <- function(res, tx) {
  res$hipoteses |>
    transmute(hipotese = unname(tx$hipoteses[termo]), beta = tx$num(beta), ic = tx$ic(li, ls),
              p = tx$p_tab(p), resultado = unname(tx$decisao[decisao])) |>
    setNames(tx$hip) |>
    kable(align = c("l", "c", "c", "c", "l"))
}

tabela_apa <- function(res, tx) {
  res$resultado |>
    transmute(preditor = unname(tx$termos[termo]), beta = tx$num(beta), ep = tx$num(ep),
              ic = tx$ic(li, ls), p = tx$p_tab(p)) |>
    setNames(tx$apa) |>
    kable(align = c("l", "c", "c", "c", "c"))
}

## ---- grafico-likert ----
grafico_likert <- function(res, tx) {
  enunciados <- if (is.null(tx$enunciados)) setNames(res$itens$enunciado, res$itens$codigo) else tx$enunciados
  cod <- res$itens$codigo
  inv <- if_else(res$itens$invertido == "sim", paste0(" (", tx$invertido, ")"), "")
  rotulos_itens <- setNames(paste0(cod, inv, ": ", enunciados[cod]), cod)
  cores_likert <- setNames(c("#6a4fa3", "#b9aee0", "#d9dbe1", "#9dbde8", cor[["azul"]]), tx$likert)

  # Barras divergentes: a resposta neutra fica metade de cada lado do zero.
  lik <- res$respostas |>
    pivot_longer(everything(), names_to = "codigo", values_to = "resposta") |>
    drop_na() |>
    count(codigo, resposta) |>
    group_by(codigo) |>
    complete(resposta = 1:5, fill = list(n = 0)) |>
    arrange(resposta, .by_group = TRUE) |>
    mutate(p = n / sum(n),
           inicio = -(p[1] + p[2] + p[3] / 2) + lag(cumsum(p), default = 0),
           fim = inicio + p, meio = (inicio + fim) / 2) |>
    ungroup() |>
    mutate(nivel = factor(tx$likert[resposta], tx$likert),
           bloco = factor(tx$blocos[substr(codigo, 1, 3)], tx$blocos),
           item = factor(rotulos_itens[codigo], rev(rotulos_itens)))
  totais <- lik |>
    group_by(item, bloco) |>
    summarise(discorda = sum(p[resposta <= 2]), concorda = sum(p[resposta >= 4]), .groups = "drop")
  rotulados <- filter(lik, p >= 0.12)

  ggplot(lik, aes(y = item)) +
    geom_segment(aes(x = inicio, xend = fim, yend = item, colour = nivel), linewidth = 7) +
    geom_vline(xintercept = 0, colour = "white", linewidth = 0.6) +
    geom_text(data = rotulados, aes(x = meio, label = tx$pct(p)), size = 3, family = "Montserrat",
              colour = if_else(rotulados$resposta %in% c(1, 5), "white", cor[["profundo"]])) +
    geom_text(data = totais, aes(x = -0.82, label = tx$pct(discorda)), hjust = 1, size = 2.8,
              family = "Montserrat", colour = cor[["cinza"]]) +
    geom_text(data = totais, aes(x = 0.82, label = tx$pct(concorda)), hjust = 0, size = 2.8,
              family = "Montserrat", colour = cor[["cinza"]]) +
    facet_grid(rows = vars(bloco), scales = "free_y", space = "free_y", labeller = label_wrap_gen(14)) +
    scale_colour_manual(values = cores_likert, drop = FALSE) +
    scale_x_continuous(limits = c(-0.92, 0.92), breaks = c(-0.5, 0, 0.5), labels = \(x) tx$pct(abs(x))) +
    scale_y_discrete(labels = label_wrap_gen(40)) +
    guides(colour = guide_legend(nrow = 2, byrow = TRUE, override.aes = list(linewidth = 4))) +
    labs(x = NULL, y = NULL, colour = NULL) +
    theme(strip.text.y = element_text(angle = 0, hjust = 0, face = "bold"),
          axis.text.y = element_text(size = 10, colour = cor[["profundo"]], lineheight = 0.95),
          legend.text = element_text(size = 10), legend.justification = "left", legend.location = "plot",
          panel.grid.major.y = element_blank(), panel.spacing.y = unit(10, "pt"))
}

## ---- grafico-grupos ----
grafico_grupos <- function(res, tx) {
  d <- res$d |>
    mutate(turno_grupo = traduzir(turno_grupo, tx$turno_grupo, ordem = TRUE),
           tempo_casa = traduzir(tempo_casa, tx$tempo, ordem = TRUE))
  caixa <- function(var, destaque, titulo, subtitulo, eixo_y = tx$g_eixo_int) {
    ggplot(d, aes(x = .data[[var]], y = INT)) +
      geom_boxplot(aes(fill = .data[[var]] == destaque), width = 0.55, outlier.shape = NA,
                   colour = cor[["profundo"]], linewidth = 0.4, alpha = 0.85) +
      geom_jitter(width = 0.14, height = 0.06, size = 1.3, alpha = 0.35, colour = cor[["profundo"]]) +
      scale_fill_manual(values = c(`TRUE` = cor[["azul"]], `FALSE` = cor[["lavanda"]]), guide = "none") +
      scale_y_continuous(limits = c(0.85, 5.15), breaks = 1:5) +
      scale_x_discrete(labels = label_wrap_gen(10)) +
      labs(title = titulo, subtitle = subtitulo, x = NULL, y = eixo_y) +
      theme(plot.title = element_text(face = "bold", size = 12),
            plot.subtitle = element_text(size = 10, colour = cor[["cinza"]]),
            panel.grid.major.x = element_blank())
  }
  set.seed(1)  # mesmo espalhamento dos pontos nas três línguas
  caixa("turno_grupo", tx$turno_grupo[["Noturno"]], tx$g_turno,
        paste0("Mann-Whitney, ", tx$p_txt(res$mw[["p"]]), "; r = ", tx$num1(res$mw[["r"]]))) +
    caixa("tempo_casa", tx$tempo[["Até 1 ano"]], tx$g_tempo,
          paste0("Kruskal-Wallis, ", tx$p_txt(res$kw[["p"]]), "; ε² = ", tx$num1(res$kw[["eps2"]], 3)),
          eixo_y = NULL) +
    plot_layout(widths = c(1, 2))
}

## ---- grafico-coeficientes ----
grafico_coef <- function(res, tx, base = 12, rotulo = 3.6) {
  res$resultado |>
    mutate(nome = factor(tx$termos[termo], rev(tx$termos[termo])),
           grupo = if_else(p < 0.05, tx$g_detectado, tx$g_sem_efeito)) |>
    ggplot(aes(x = beta, y = nome, colour = grupo)) +
    geom_vline(xintercept = 0, colour = cor[["cinza"]], linewidth = 0.5, linetype = "dashed") +
    geom_errorbar(aes(xmin = li, xmax = ls), width = 0, linewidth = 1.6) +
    geom_point(size = 3.6, shape = 21, fill = "white", stroke = 2) +
    geom_text(aes(label = tx$num(beta)), vjust = -1.1, size = rotulo, family = "Montserrat",
              colour = cor[["profundo"]], show.legend = FALSE) +
    scale_colour_manual(values = setNames(c(cor[["azul"]], cor[["medio"]]), c(tx$g_detectado, tx$g_sem_efeito))) +
    scale_x_continuous(labels = \(x) tx$num(x)) +
    labs(x = tx$g_eixo_coef, y = NULL, colour = NULL) +
    theme_minimal(base_family = "Montserrat", base_size = base) +
    theme(text = element_text(colour = cor[["profundo"]]),
          axis.text.y = element_text(colour = cor[["profundo"]]),
          panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(),
          panel.grid.major.x = element_line(colour = cor[["grade"]], linewidth = 0.4),
          plot.background = element_blank(), panel.background = element_blank(),
          legend.position = "top", legend.justification = "left")
}

# Capa da página (listagem e compartilhamento), no estilo da capa do Radar:
# fundo azul profundo, logo, título, subtítulo e uma versão pequena do gráfico
# de coeficientes. A listagem mostra só a faixa do meio da imagem (cerca de
# 2/3 da altura), então título e gráfico ficam nessa faixa.
salvar_capa <- function(res, tx, arquivo = "img/capa.png", logo) {
  claro <- c(texto = "#ffffff", sub = "#cacfee", apoio = "#9aa3c7", linha = "#34344f",
             detectado = "#9dbde8", sem_efeito = "#6b7299")
  grafico <- res$resultado |>
    mutate(nome = factor(tx$termos[termo], rev(tx$termos[termo])),
           detectado = p < 0.05) |>
    ggplot(aes(x = beta, y = nome, colour = detectado)) +
    geom_vline(xintercept = 0, colour = claro[["apoio"]], linewidth = 0.5, linetype = "dashed") +
    geom_errorbar(aes(xmin = li, xmax = ls), width = 0, linewidth = 1.8) +
    geom_point(size = 3.8, shape = 21, fill = cor[["profundo"]], stroke = 2) +
    scale_colour_manual(values = c(`TRUE` = claro[["detectado"]], `FALSE` = claro[["sem_efeito"]]), guide = "none") +
    scale_x_continuous(labels = \(x) tx$num(x)) +
    labs(title = tx$capa_grafico, x = NULL, y = NULL) +
    theme_minimal(base_family = "Montserrat", base_size = 15) +
    theme(text = element_text(colour = claro[["sub"]]),
          axis.text.y = element_text(colour = claro[["sub"]], size = 14),
          axis.text.x = element_text(colour = claro[["apoio"]], size = 12),
          plot.title = element_text(colour = claro[["apoio"]], size = 14, margin = margin(b = 10)),
          plot.title.position = "plot",
          panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(),
          panel.grid.major.x = element_line(colour = claro[["linha"]], linewidth = 0.5),
          plot.background = element_blank(), panel.background = element_blank())

  texto <- function(rotulo, y, tamanho, cor_texto, peso = "plain", altura = 1.15) {
    grid::grid.text(rotulo, x = grid::unit(72, "native"), y = grid::unit(675 - y, "native"),
                    just = c("left", "top"),
                    gp = grid::gpar(fontfamily = "Montserrat", fontface = peso, fontsize = tamanho,
                                    col = cor_texto, lineheight = altura),
                    vp = grid::viewport(xscale = c(0, 1200), yscale = c(0, 675)))
  }

  dir.create(dirname(arquivo), showWarnings = FALSE)
  ragg::agg_png(arquivo, width = 1200, height = 675, res = 72, background = cor[["profundo"]])
  on.exit(grDevices::dev.off())
  grid::grid.raster(png::readPNG(logo), x = grid::unit(72, "points"), y = grid::unit(675 - 48, "points"),
                    width = grid::unit(64, "points"), just = c("left", "top"))
  linhas <- function(x) lengths(strsplit(x, "\n"))
  y_titulo <- 175
  texto(tx$capa_titulo, y_titulo, 46, claro[["texto"]], "bold", 1.1)
  y_sub <- y_titulo + 51 * linhas(tx$capa_titulo) + 22
  texto(tx$capa_subtitulo, y_sub, 22, claro[["sub"]], altura = 1.25)
  y_frase <- y_sub + 28 * linhas(tx$capa_subtitulo) + 26
  texto(tx$capa_frase, y_frase, 17, claro[["apoio"]], altura = 1.4)
  texto(tx$capa_rodape, 630, 12, claro[["apoio"]])
  print(grafico, vp = grid::viewport(x = grid::unit(1150, "points"), y = grid::unit(675 / 2, "points"),
                                     width = grid::unit(500, "points"), height = grid::unit(410, "points"),
                                     just = c("right", "center")))
}
