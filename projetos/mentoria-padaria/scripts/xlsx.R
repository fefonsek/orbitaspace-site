# Caso Mentoria: grava planilhas .xlsx válidas com o openxlsx.
#
# O openxlsx 4.2.8.1 instalado aqui grava, em cada aba, relações para
# arquivos que não põe no pacote (drawingN.xml, printerSettingsN.bin,
# vmlDrawingN.vml). Arquivo assim faz o Excel pedir reparo ao abrir e
# outros leitores (openpyxl, pycel) recusarem. salvar_xlsx() grava com o
# openxlsx e depois tira do pacote as relações que apontam para arquivos
# ausentes e as referências a elas nas abas. O resto do arquivo não muda.

salvar_xlsx <- function(wb, arquivo) {
  openxlsx::saveWorkbook(wb, arquivo, overwrite = TRUE)
  pasta <- tempfile("xlsx_")
  dir.create(pasta)
  on.exit(unlink(pasta, recursive = TRUE), add = TRUE)
  utils::unzip(arquivo, exdir = pasta)
  existe <- function(alvo, base) file.exists(normalizePath(file.path(base, alvo), mustWork = FALSE))

  rels <- list.files(file.path(pasta, "xl", "worksheets", "_rels"), pattern = "\\.rels$", full.names = TRUE)
  for (r in rels) {
    xml <- paste(readLines(r, warn = FALSE, encoding = "UTF-8"), collapse = "")
    entradas <- regmatches(xml, gregexpr("<Relationship [^>]*/>", xml))[[1]]
    base <- file.path(pasta, "xl", "worksheets")
    removidos <- character()
    for (e in entradas) {
      alvo <- sub('.*Target="([^"]+)".*', "\\1", e)
      if (!existe(alvo, base)) {
        removidos <- c(removidos, sub('.*Id="([^"]+)".*', "\\1", e))
        xml <- sub(e, "", xml, fixed = TRUE)
      }
    }
    writeLines(xml, r, useBytes = TRUE)
    if (length(removidos)) {
      aba <- file.path(base, sub("\\.rels$", "", basename(r)))
      s <- paste(readLines(aba, warn = FALSE, encoding = "UTF-8"), collapse = "")
      for (id in removidos) {
        s <- gsub(sprintf('<(drawing|legacyDrawing)\\s+r:id="%s"\\s*/>', id), "", s)
        s <- gsub(sprintf('\\s+r:id="%s"', id), "", s)
      }
      writeLines(s, aba, useBytes = TRUE)
    }
  }
  arquivos <- list.files(pasta, recursive = TRUE, all.files = TRUE)
  unlink(arquivo)
  zip::zip(arquivo, files = arquivos, root = pasta, mode = "mirror")
  invisible(arquivo)
}

# Confere que nenhuma relação das abas aponta para arquivo ausente.
xlsx_valido <- function(arquivo) {
  conteudo <- utils::unzip(arquivo, list = TRUE)$Name
  rels <- grep("^xl/worksheets/_rels/.*\\.rels$", conteudo, value = TRUE)
  for (r in rels) {
    con <- unz(arquivo, r)
    xml <- paste(readLines(con, warn = FALSE), collapse = "")
    close(con)
    alvos <- regmatches(xml, gregexpr('Target="[^"]+"', xml))[[1]]
    alvos <- sub('Target="\\.\\./([^"]+)"', "xl/\\1", alvos)
    if (any(!alvos %in% conteudo)) return(FALSE)
  }
  TRUE
}
