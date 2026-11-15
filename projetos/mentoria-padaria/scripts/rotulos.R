# Caso Mentoria (Padaria Grão Dourado): formatos e textos curtos de cada língua.
# - Formatos de número, porcentagem e dinheiro (sempre em reais: a padaria é
#   brasileira).
# - Nomes dos produtos e das fornadas. As chaves internas (frances, queijo...;
#   6h, 10h...) são as mesmas em toda a análise; só o nome mostrado muda. Em
#   inglês, as fornadas aparecem como 6 a.m., 10 a.m., 2 p.m. e 5 p.m.
# - "Margem", e não "lucro": os valores não descontam aluguel, salários e
#   energia.
# - Rótulos dos gráficos, da capa e da planilha modelo.
# O texto corrido fica em cada index.qmd.

PRODUTOS <- c("frances", "queijo", "fuba", "sonho", "forma", "salgado")
FORNADAS <- c("6h", "10h", "14h", "17h")

rotulos <- function(idioma = c("pt", "es", "en")) {
  idioma <- match.arg(idioma)
  ingles <- idioma == "en"
  num <- function(x, d = 0) formatC(x, format = "f", digits = d, big.mark = if (ingles) "," else ".",
                                    decimal.mark = if (ingles) "." else ",")
  pct <- function(x, d = 0) paste0(num(x, d), "%")
  reais <- function(x, d = 0) paste0("R$ ", num(x, d))
  list(
    idioma = idioma, num = num, pct = pct, reais = reais,
    produtos = setNames(switch(idioma,
      pt = c("Pão francês", "Pão de queijo", "Bolo de fubá", "Sonho", "Pão de forma", "Salgado assado"),
      es = c("Pan francés", "Pan de queso", "Bizcocho de maíz", "Berlinesa", "Pan de molde", "Salado horneado"),
      en = c("French roll", "Cheese bread", "Cornmeal cake", "Cream donut", "Sandwich loaf", "Baked savory")),
      PRODUTOS),
    fornada = switch(idioma, pt = "Fornada", es = "Horneada", en = "Batch"),
    fornadas = setNames(if (ingles) c("6 a.m.", "10 a.m.", "2 p.m.", "5 p.m.") else FORNADAS, FORNADAS),
    g_sobra = switch(idioma, pt = "Sobra (% do que foi produzido)", es = "Sobrante (% de lo producido)",
                     en = "Leftovers (% of what was baked)"),
    g_margem = switch(idioma, pt = "Margem real em 12 semanas (R$)", es = "Margen real en 12 semanas (R$)",
                      en = "Real margin over 12 weeks (R$)"),
    g_participacao = switch(idioma, pt = "Participação na margem total", es = "Participación en el margen total",
                            en = "Share of total margin"),
    capa_titulo = switch(idioma, pt = "Os 3 números\nde uma padaria", es = "Los 3 números\nde una panadería",
                         en = "The 3 numbers\nof a bakery"),
    capa_subtitulo = switch(idioma, pt = "Exemplo de encontro\nda mentoria", es = "Ejemplo de encuentro\nde la mentoría",
                            en = "A sample mentoring\nsession"),
    capa_frase = switch(idioma,
      pt = "Da planilha bagunçada\nà decisão da fornada das 17h.",
      es = "De la hoja de cálculo desordenada\na la decisión de la horneada de las 17h.",
      en = "From a messy spreadsheet\nto the 5 p.m. batch decision."),
    capa_grafico = switch(idioma, pt = "Sobra do pão francês por fornada", es = "Sobrante del pan francés por horneada",
                          en = "French roll leftovers by batch"),
    capa_rodape = switch(idioma,
      pt = "Material de exemplo da mentoria, com dados fictícios · Felipe Fonseca · @fefonsek",
      es = "Material de ejemplo de la mentoría, con datos ficticios · Felipe Fonseca · @fefonsek",
      en = "Sample mentoring material with fictional data · Felipe Fonseca · @fefonsek"),
    # Planilha modelo: nomes das abas, cabeçalhos e textos.
    planilha = switch(idioma,
      pt = list(arquivo = "planilha_modelo_padaria.xlsx", abas = c("Lançamentos", "Indicadores", "Listas", "Como usar"),
                colunas = c("data", "dia_semana", "fornada", "produto", "produzido", "vendido", "preco_unitario",
                            "custo_unitario", "sobra", "receita", "custo_total", "margem"),
                ind = list(t1 = "1. Taxa de sobra por fornada e produto (sobra ÷ produzido)",
                           t2 = "2. Margem real por produto (receita menos o custo de tudo o que foi produzido)",
                           t3 = "3. Participação de cada produto na margem total",
                           produto = "Produto", produzido = "Produzido", vendido = "Vendido", sobra = "Sobra",
                           receita = "Receita", custo = "Custo total", margem = "Margem real",
                           participacao = "Participação", total = "Total"),
                como = c("Como usar esta planilha",
                         "1. Na aba Lançamentos, cada linha é um dia, um produto e uma fornada.",
                         "2. Preencha data, fornada, produto (escolha na lista), quanto foi produzido, quanto foi vendido, o preço e o custo de uma unidade.",
                         "3. As colunas sobra, receita, custo_total e margem se calculam sozinhas: copie as fórmulas para as linhas novas.",
                         "4. A aba Indicadores mostra os três números. Para trocar produtos ou fornadas, edite a aba Listas e os nomes na aba Indicadores.",
                         "5. As linhas que já estão aqui são da Padaria Grão Dourado, uma padaria fictícia. Apague e use as suas.",
                         "Funciona no Excel e no Google Planilhas: só usa SOMASES e contas simples, sem fórmulas de matriz.",
                         "Material de exemplo da mentoria, com dados fictícios. Felipe Fonseca · orbitaspace.com.br")),
      es = list(arquivo = "planilla_modelo_panaderia.xlsx", abas = c("Registros", "Indicadores", "Listas", "Cómo usar"),
                colunas = c("fecha", "dia_semana", "horneada", "producto", "producido", "vendido", "precio_unitario",
                            "costo_unitario", "sobrante", "ingreso", "costo_total", "margen"),
                ind = list(t1 = "1. Tasa de sobrante por horneada y producto (sobrante ÷ producido)",
                           t2 = "2. Margen real por producto (ingreso menos el costo de todo lo producido)",
                           t3 = "3. Participación de cada producto en el margen total",
                           produto = "Producto", produzido = "Producido", vendido = "Vendido", sobra = "Sobrante",
                           receita = "Ingreso", custo = "Costo total", margem = "Margen real",
                           participacao = "Participación", total = "Total"),
                como = c("Cómo usar esta hoja de cálculo",
                         "1. En la hoja Registros, cada fila es un día, un producto y una horneada.",
                         "2. Completa fecha, horneada, producto (elige de la lista), cuánto se produjo, cuánto se vendió, el precio y el costo de una unidad.",
                         "3. Las columnas sobrante, ingreso, costo_total y margen se calculan solas: copia las fórmulas a las filas nuevas.",
                         "4. La hoja Indicadores muestra los tres números. Para cambiar productos u horneadas, edita la hoja Listas y los nombres en la hoja Indicadores.",
                         "5. Las filas que ya están aquí son de la Padaria Grão Dourado, una panadería ficticia. Bórralas y usa las tuyas.",
                         "Funciona en Excel y en Google Sheets: solo usa SUMAR.SI.CONJUNTO y cuentas simples, sin fórmulas matriciales.",
                         "Material de ejemplo de la mentoría, con datos ficticios. Felipe Fonseca · orbitaspace.com.br")),
      en = list(arquivo = "template_bakery.xlsx", abas = c("Entries", "KPIs", "Lists", "How to use"),
                colunas = c("date", "weekday", "batch", "product", "baked", "sold", "unit_price", "unit_cost",
                            "leftover", "revenue", "total_cost", "margin"),
                ind = list(t1 = "1. Leftover rate by batch and product (leftover ÷ baked)",
                           t2 = "2. Real margin by product (revenue minus the cost of everything baked)",
                           t3 = "3. Each product's share of total margin",
                           produto = "Product", produzido = "Baked", vendido = "Sold", sobra = "Leftover",
                           receita = "Revenue", custo = "Total cost", margem = "Real margin",
                           participacao = "Share", total = "Total"),
                como = c("How to use this spreadsheet",
                         "1. On the Entries sheet, each row is one day, one product and one batch.",
                         "2. Fill in the date, batch, product (pick from the list), how many were baked, how many were sold, and the price and cost of one unit.",
                         "3. The leftover, revenue, total_cost and margin columns calculate themselves: copy the formulas down to new rows.",
                         "4. The KPIs sheet shows the three numbers. To change products or batches, edit the Lists sheet and the names on the KPIs sheet.",
                         "5. The rows already here belong to Padaria Grão Dourado, a fictional bakery. Delete them and use your own.",
                         "Works in Excel and Google Sheets: it only uses SUMIFS and simple arithmetic, no array formulas.",
                         "Sample mentoring material with fictional data. Felipe Fonseca · orbitaspace.com.br"))),
    dias = switch(idioma,
      pt = c("segunda", "terça", "quarta", "quinta", "sexta", "sábado", "domingo"),
      es = c("lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"),
      en = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"))
  )
}
