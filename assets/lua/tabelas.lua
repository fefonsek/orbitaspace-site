-- Envolve cada tabela num bloco .tabela-rolavel. Em telas estreitas a tabela
-- fica mais compacta (assets/css/orbita.scss); se ainda não couber, só esse
-- bloco rola na horizontal, sem empurrar o resto da página.

function Table(tabela)
  if not quarto.doc.is_format("html") then
    return nil
  end
  return pandoc.Div({ tabela }, pandoc.Attr("", { "tabela-rolavel" }))
end
