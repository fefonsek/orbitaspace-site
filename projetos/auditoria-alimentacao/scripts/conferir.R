# Caso Auditoria: compara o que a auditoria achou com o que o gerador plantou.
#
# Roda depois de scripts/auditoria.R. A auditoria não lê o gabarito; só este
# script junta os dois, para medir quanto do que foi plantado ela encontrou,
# quantos falsos alarmes deu e se os casos que parecem erro (e não são)
# terminaram como Regular. Grava resultados/conferencia.rds.
#
# Uso, a partir da pasta do site:
#   Rscript projetos/auditoria-alimentacao/scripts/conferir.R

arquivo <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
setwd(normalizePath(file.path(dirname(arquivo), ".."), winslash = "/"))
suppressPackageStartupMessages(library(tidyverse))

gabarito <- read_csv("resultados/gabarito.csv.gz", show_col_types = FALSE, na = "")
classif <- readRDS("resultados/classificacao.rds")
aud <- readRDS("resultados/auditoria.rds")
junto <- classif |> left_join(gabarito, "id")

# O que cada defeito plantado deveria disparar na auditoria.
esperado <- c(duplicidade = "Duplicidade", fora_do_trabalho = "Pessoa fora do trabalho",
              jantar_sem_pernoite = "Jantar sem pernoite", acima_do_teto = "Acima do teto",
              justificativa_ausente = "Extra sem justificativa")
achou <- function(plantado, motivo_regra, sem_lastro, justificativa_fraca) {
  case_when(plantado %in% names(esperado) ~ motivo_regra %in% esperado[plantado] & !is.na(motivo_regra),
            plantado == "sem_lastro" ~ sem_lastro,
            plantado == "justificativa_vaga" ~ justificativa_fraca)
}
deteccao <- junto |>
  filter(!is.na(plantado)) |>
  mutate(encontrado = achou(plantado, motivo_regra, sem_lastro, justificativa_fraca)) |>
  group_by(plantado) |>
  summarise(plantados = n(), encontrados = sum(encontrado), .groups = "drop") |>
  mutate(pct = 100 * encontrados / plantados)

# Falso alarme: recarga sem nenhum defeito plantado que terminou em Indevido
# ou Revisar.
falsos_alarmes <- junto |>
  filter(is.na(plantado), conclusao %in% c("Indevido", "Revisar")) |>
  count(conclusao)

# Casos que parecem erro e não são: devem terminar como Regular. Os que caem
# numa base e mês acima da faixa ganham o ponto do grupo (Atenção), que não tem
# a ver com o atraso nem com a digitação; fora desses grupos, todos são Regular.
casos_falsos <- junto |>
  filter(!is.na(falso)) |>
  count(falso, grupo_acima_da_faixa = fora_da_faixa, conclusao) |>
  pivot_wider(names_from = conclusao, values_from = n, values_fill = 0)

# Achados que o roteiro pede.
dup <- aud$dup_mes |> mutate(semestre = if_else(mes <= "2025-07", "até julho", "agosto em diante"))
achados <- list(
  dup_ate_julho = sum(dup$valor[dup$semestre == "até julho"]),
  dup_depois = sum(dup$valor[dup$semestre != "até julho"]),
  ferias_primeiros_5 = with(aud$ferias_dia, sum(n[dia_do_periodo <= 5]) / sum(n)),
  jantar_duas_bases = with(aud$jantar_base, sum(head(valor, 2)) / sum(valor)),
  bases_jantar = head(aud$jantar_base$base, 2),
  meses_fora = aud$jantar_base |> slice_head(n = 2) |> pull(meses_fora)
)

print(deteccao)
print(falsos_alarmes)
print(casos_falsos)
str(achados)
str(aud$salto)

stopifnot(
  "os casos que parecem erro terminam como Regular" =
    all(junto$conclusao[!is.na(junto$falso) & !junto$fora_da_faixa] == "Regular"),
  "nenhum caso que parece erro vira Indevido ou Revisar" =
    !any(junto$conclusao[!is.na(junto$falso)] %in% c("Indevido", "Revisar")),
  "nenhum falso alarme em Indevido" = sum(falsos_alarmes$n[falsos_alarmes$conclusao == "Indevido"]) == 0
)
saveRDS(list(deteccao = deteccao, falsos_alarmes = falsos_alarmes, casos_falsos = casos_falsos,
             achados = achados), "resultados/conferencia.rds")
