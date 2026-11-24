# Site da Orbita Space

Site de Felipe Fonseca, feito em [Quarto](https://quarto.org), em três línguas:
português na raiz, espanhol em `/es/` e inglês em `/en/`. Publicado em
<https://orbitaspace.com.br>.

## Como ver a prévia

**Não use `quarto preview` nem `quarto render` sozinhos.** Cada língua é um
perfil do Quarto, e esses comandos renderizam um perfil só: os outros idiomas
somem de `docs/`. Se isso acontecer, o próprio Quarto mostra um aviso no fim
e basta rodar o `render.ps1` de novo.

A prévia oficial tem dois passos:

1. Gerar o site completo, no PowerShell, dentro desta pasta:

   ```powershell
   .\render.ps1
   ```

2. Servir a pasta `docs/` numa **janela separada do PowerShell**, que fica
   aberta enquanto você navega:

   ```powershell
   python -m http.server 4321 --directory docs
   ```

   Abra <http://localhost:4321>. Para ver uma mudança, rode o `render.ps1` de
   novo na primeira janela e recarregue a página (Ctrl+F5). O servidor não
   precisa ser reiniciado. Para encerrá-lo, use Ctrl+C na janela dele.

## Como publicar

```powershell
.\publicar.ps1
```

Ele roda o `render.ps1` e **se recusa a continuar** se encontrar em `docs/`
algum marcador provisório (`[VÍDEO AQUI]`, `[LINK DO REPOSITÓRIO]`), travessão,
imagem citada que não existe ou a foto original. O envio ao GitHub ainda não
faz parte do script.

## O que o `render.ps1` faz

1. Atualiza os casos TCC, Indicadores e Auditoria, se for preciso (veja as
   seções de cada caso abaixo).
2. Apaga `docs/` uma única vez, no início.
3. Renderiza os perfis `pt`, `es` e `en` com `--no-clean`, para que um idioma
   não apague a saída dos outros.
4. Roda `scripts/pos_render.py`, descrito abaixo.

## Checagens e ajustes do `scripts/pos_render.py`

Roda sozinho no fim de todo `render.ps1`:

- **Sitemap:** junta os sitemaps dos três perfis num só (`docs/sitemap.xml`).
- **Páginas:** confere se cada página de `_traducoes.yml` existe e está no
  sitemap.
- **Títulos:** troca a meia-risca que o Quarto põe como separador no título
  da aba por um ponto médio: "Projetos · Orbita Space". Vale também para as
  apresentações em revealjs, em que o Quarto põe o nome do site na frente.
  Um título que já traz "Orbita Space" ou "Felipe Fonseca" (o da página
  inicial) fica como está.
- **Um endereço por página (sem `index.html`):** cada página de uma pasta tem
  um endereço só, o da pasta com barra no final
  (`https://orbitaspace.com.br/en/projects/kpi-governance/`), para o Google
  não ver a mesma página com e sem `index.html`.
  - O Quarto sempre escreve `index.html` nos links para um `index.qmd` (menu,
    listagens, links entre páginas) e não tem opção para mudar isso. Os
    `.qmd` continuam apontando para `index.qmd`, para o Quarto conferir se a
    página existe, e o script tira o `index.html` do fim dos links internos
    em `docs/`: HTML, sitemap, `<link>` dos feeds e `href` da busca. O
    `<guid>` dos feeds fica como está, para os leitores de RSS não
    repetirem posts antigos.
  - Endereços escritos à mão já usam a pasta: o menu, o logo e o rodapé nos
    `_quarto-*.yml` (`/`, `/es/`, `/en/`) e as páginas em `_traducoes.yml`,
    que viram os links hreflang e o seletor de idioma.
  - `canonical-url: true` no `_quarto.yml` põe `<link rel="canonical">` em
    cada página. O script confere que cada página do sitemap aponta para o
    próprio endereço e que não sobrou link interno para `index.html`; se
    sobrar, é erro.
- **Sufixo de versão nas imagens:** toda imagem passa a ser carregada como
  `foto.jpg?v=a21fb6a1`, onde o código é um resumo (hash) do conteúdo do
  arquivo. Quando uma imagem é trocada, o código muda e o navegador baixa a
  nova em vez de mostrar a antiga do cache; imagens que não mudaram mantêm o
  mesmo endereço e continuam vindo do cache. Não é preciso fazer nada à mão.
- **Travessão:** qualquer travessão (U+2014) ou meia-risca (U+2013) no texto
  do site é erro.
- **Imagem não encontrada:** imagem citada no HTML que não existe em `docs/`
  é erro.
- **Foto original:** `assets/img/felipe-original.jpeg` não pode ir para
  `docs/`; o site usa só os recortes.
- **Marcadores provisórios:** no render comum aparecem como aviso em
  vermelho; no `publicar.ps1` bloqueiam a publicação.

## Outros scripts

- `scripts/preparar_imagens.py`: gera os logos, o favicon, as imagens de
  compartilhamento, os recortes da foto e as versões web das telas do painel.
  Rode depois de trocar algum logo, a foto ou uma tela:
  `python scripts\preparar_imagens.py`.
- `scripts/auditoria.py`: só lê `docs/` e lista o peso das imagens, o título
  de cada página, links internos quebrados (inclusive âncoras `#...`) e a
  reciprocidade dos `hreflang`. Rode depois do render:
  `python scripts\auditoria.py`.

## Caso TCC (páginas com código R)

O caso de consultoria para TCC existe em três línguas, mas a análise em R roda
uma vez só:

- `projetos/caso-tcc-rotatividade/scripts/gerar_dados.R` gera os dados
  fictícios (`dados/`), com semente fixa. Só precisa rodar de novo se o
  desenho dos dados mudar. O R não está no PATH, então use o caminho completo:
  `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" projetos\caso-tcc-rotatividade\scripts\gerar_dados.R`.
- `scripts/analise.R` faz toda a análise e grava `resultados/analise.rds`.
- `scripts/rotulos.R` tem os textos dos gráficos e das tabelas em PT, ES e EN e
  o formato dos números de cada idioma (em inglês, a regra da APA: p < .001).
- `scripts/apresentacao.R` desenha as tabelas e os gráficos, e também a capa
  de cada página (`img/capa.png`, no estilo da capa do Radar: fundo azul
  profundo, título e um gráfico pequeno, com os textos de `rotulos.R`).
- As páginas `projetos/caso-tcc-rotatividade/index.qmd`,
  `es/proyectos/tesis-rotacion/index.qmd` e `en/projects/thesis-turnover/index.qmd`
  só leem o `.rds` e chamam essas funções; o texto de cada uma é traduzido à mão.

O `render.ps1` cuida do resto: roda o `analise.R` quando os dados ou o script
mudaram e, quando o `.rds`, os textos ou os gráficos mudaram, descarta o
resultado congelado das três páginas em `_freeze/`, para que sejam refeitas. O
`_freeze/` vai para o Git: sem mudanças, o render não precisa do R.

Os termos usados nas traduções ficam em `_rascunhos/glossario_pt_es_en.md`.

## Caso Indicadores (governança de indicadores)

O caso "Um número, três respostas" existe em três línguas:
`projetos/governanca-indicadores/`, `es/proyectos/gobernanza-indicadores/` e
`en/projects/kpi-governance/`, ligadas pela chave `indicadores` do
`_traducoes.yml`. Os dados e os scripts ficam só na pasta em português; as
páginas em ES e EN leem os mesmos arquivos. O roteiro aprovado está em
`_rascunhos/caso_indicadores_roteiro.md`, e os rascunhos das traduções em
`_rascunhos/caso_indicadores_es.md` e `_en.md`.

Como no TCC, o texto da página não tem nenhum número digitado: tudo vem dos
arquivos de `dados/` e é conferido por `stopifnot` antes de a página sair.

- `dados/taxa_tres_definicoes.csv`: as três taxas de absenteísmo (RH,
  Operação, Financeiro), 24 meses × 3 definições, só somas da empresa
  inteira. É gerado por `scripts/agregar_radar.R`.
- `dados/inventario.csv`, `fichas.yml`, `criterios.csv`, `definicoes.csv`,
  `raci.csv` e `versoes.csv`: inventário dos 40 indicadores, as 14 fichas,
  critérios de situação e destino, textos da tabela das três definições, papéis
  e registro de versões. São editados à mão.
- `scripts/dados.R` lê esses arquivos e roda as checagens (40 indicadores,
  13 bem definidos, 14 na diretoria, fichas completas, RH em 3,77%...).
- `scripts/apresentacao.R` desenha os gráficos (com uma versão para o
  celular), as partes em HTML e a capa; `scripts/inventario.js` faz a busca
  e os filtros do inventário.
- `scripts/rotulos.R` tem os formatos de número e de data e os rótulos curtos
  de cada língua (como o do TCC); os textos dos dados em espanhol e inglês
  (inventário, fichas, critérios, RACI, versões, definições) ficam em
  `scripts/textos_es.yml` e `textos_en.yml`, presos às chaves dos arquivos em
  português. Em inglês, número que abre a frase sai por extenso
  (`tx$extenso(n, inicio = TRUE)`).

O `agregar_radar.R` lê a base do Radar de Absenteísmo **só para leitura**, na
pasta `data/raw` do projeto `radar-absenteismo-powerbi` ao lado do site (ou no
caminho de `ORBITA_ORIGEM_PAINEL`), nunca lê `_privado/` e nunca copia arquivo
do Radar para o site. Ele roda sozinho no passo 0b do `render.ps1`, só quando
o CSV não existe ou quando a base do Radar ou o script mudaram; sem a pasta do
Radar, o render usa o CSV que já está no site. Se os dados ou os scripts do
caso mudam, o `render.ps1` descarta o `_freeze/` das três páginas.

## Caso Auditoria (benefício de alimentação em campo)

O caso existe em três línguas: `projetos/auditoria-alimentacao/`,
`es/proyectos/auditoria-alimentacion/` e `en/projects/meal-allowance-audit/`,
ligadas pela chave `auditoria` do `_traducoes.yml`, na frente `relatorios`. Os
dados, os scripts e os resultados ficam só na pasta em português. O roteiro
aprovado está em `_rascunhos/caso_auditoria_roteiro.md`, e os rascunhos das
traduções, em `_rascunhos/caso_auditoria_es.md` e `_en.md`.

- `scripts/gerar_dados.R` gera as cinco tabelas fictícias em `dados/` (com
  semente fixa; `recargas.csv.gz` compactado) e o gabarito do que plantou em
  `resultados/gabarito.csv.gz`. Não roda no render: rode à mão se precisar
  gerar os dados de novo.
- `scripts/auditoria.R` aplica as seis etapas do método, sem ler o gabarito,
  e grava `resultados/auditoria.rds`, `classificacao.rds` e
  `casos_revisar.csv`. `scripts/conferir.R` compara o resultado com o
  gabarito (`conferencia.rds`). `scripts/traduzir_casos.R` grava
  `casos_revisar_es.csv` e `_en.csv`.
- `scripts/rotulos.R` tem os formatos e os textos curtos das três línguas;
  `scripts/apresentacao.R`, os gráficos, as tabelas e a capa.
- O relatório em PDF é um projeto Quarto à parte em `relatorio/` (Typst): um
  só `relatorio.qmd` com o parâmetro `idioma` e o texto em
  `textos_pt.yml`, `textos_es.yml` e `textos_en.yml`. Ele gera
  `relatorio.pdf`, `relatorio-es.pdf` e `relatorio-en.pdf`, e para com erro
  se algum passar de 4 páginas.

O passo 0c do `render.ps1` roda a auditoria, a conferência e os CSVs
traduzidos quando os dados ou os scripts mudaram, refaz os três PDFs quando
os resultados, os textos ou os gráficos mudaram (o PT por último, porque o
render de uma língua apaga a saída padrão do arquivo) e descarta o `_freeze/`
das três páginas. As tabelas brutas e o gabarito não são publicados; o site
publica só os PDFs e os CSVs de casos.

## Caso Motivação de desligamento (Cestária Supermercados)

O caso existe em três línguas: `projetos/motivacao-desligamento/`,
`es/proyectos/motivos-de-salida/` e `en/projects/turnover-exit-reasons/`,
ligadas pela chave `desligamento` do `_traducoes.yml`, na frente `relatorios`.
A base, os scripts e os resultados ficam só na pasta em português; as páginas
em ES e EN leem os mesmos arquivos e gravam a própria capa. É a etapa 1 de 2:
a etapa 2 é um painel de turnover em Power BI com a mesma base.

- `dados/` tem a base fictícia num esquema estrela pronto para o Power BI:
  `dim_colaborador`, `dim_estrutura` (uma linha por gerência e vigência de
  gestor), `dim_tempo`, `fato_headcount_mensal` (pessoa × mês),
  `fato_desligamentos` e `fato_entrevista_desligamento`. A base vai para o
  repositório, mas não é publicada no site.
- **O gerador e o gabarito não ficam neste repositório.** Estão num
  repositório privado, sem remoto, em `D:\Projetos\cestaria-turnover` (ao
  lado da pasta do site): `gerar_dados.R` (gera a base com semente fixa e
  planta seis padrões), `gabarito.rds` (o que foi plantado) e `conferir.R`
  (compara a análise com o gabarito e para o render se algum padrão não for
  recuperado). Se o repositório estiver em outro lugar, defina
  `ORBITA_GERADOR_DESLIGAMENTO`; sem ele, o render pula a conferência com um
  aviso.
- `scripts/analise.R` lê só `dados/` e grava `resultados/desligamento.rds` e
  `resultados/prioridades_gerencias.csv` (só agregados; grupos com menos de 10
  pessoas viram "<10"). `scripts/traduzir_prioridades.R` grava o mesmo CSV em
  ES e EN (`prioridades_gerencias_es.csv` e `_en.csv`). `scripts/rotulos.R`
  tem os formatos e textos curtos das três línguas (inclusive os nomes das
  gerências: "CD Expedição" vira "CD Despacho" e "DC Shipping");
  `scripts/apresentacao.R`, os gráficos, as tabelas e a capa.
- O relatório em PDF é um projeto Quarto à parte em `relatorio/` (Typst), com
  o parâmetro `idioma` e o texto em `textos_pt.yml`, `textos_es.yml` e
  `textos_en.yml`. Gera `relatorio.pdf`, `relatorio-es.pdf` e
  `relatorio-en.pdf`, cada um com quatro páginas (resumo, motivos, onde agir,
  prioridades), e para com erro se algum passar disso.

O passo 0d do `render.ps1` roda a análise (e a conferência, se o repositório
do gerador existir) quando a base ou o script mudaram, refaz o PDF quando os resultados,
os textos ou os gráficos mudaram e descarta o `_freeze/` da página. O site
publica só o PDF e o CSV de prioridades.

## Marca

- **Felipe Fonseca** é o nome principal: título da página inicial e nome no
  menu (`navbar.title` nos `_quarto-*.yml`), ao lado do logo da Orbita.
- **Orbita Space** é a empresa por trás do trabalho: logo no menu e no
  rodapé, CNPJ, e-mail e o fim do título das abas (`website.title`).
- Na página inicial, o texto visível não usa "consultor" nem "consultoria";
  essas palavras ficam só no título de SEO e na meta description.
- **Rodapé** (fora das páginas da Saline): nome e profissão à esquerda,
  Orbita Space com logo e CNPJ no centro (`.rodape-cnpj`, dentro do `center`
  do `page-footer`) e os links à direita; a frase da Saline fica numa linha
  própria, embaixo. O CSS usa `display: contents` na coluna do centro para
  separar o CNPJ (primeira linha) da frase (linha de baixo).
- **Mentoria em grupo:** por enquanto só lista de espera, pelo WhatsApp, no
  cartão `#mentoria` da página inicial (o botão "Conhecer a mentoria" leva
  até ele).

## Política de Privacidade

`privacidade/index.qmd`, no endereço `/privacidade/` (canônica com barra no
final). Só em português: o texto é o de Felipe, sem mudanças; ao atualizar,
troque também a data de "Última atualização". O link fica numa linha própria
no fim do rodapé, centralizada, abaixo da frase da Saline e no mesmo tamanho
dela, em todas as páginas (as duas marcas) e nas três línguas; em ES e EN,
com o aviso "(página en portugués)" / "(page in Portuguese)". É um `<span>`
com o estilo no próprio atributo, no fim do `center` do `page-footer` dos
`_quarto-*.yml`: assim a mudança fica só no rodapé, sem trocar a folha de
estilo (e o `<head>`) de todas as páginas.

## Mini-kit (página oculta)

`mini-kit/index.qmd`, no endereço `/mini-kit/` (canônica com barra no final):
"10 prompts para descobrir os indicadores da sua empresa para 2027", material gratuito
que leva à pré-venda do Kit de Indicadores com IA. Só em português, sem
tradução e sem entrada no `_traducoes.yml` (ES e EN levam às páginas
iniciais). O link é enviado pelo WhatsApp; nenhuma página do site leva a ela.

- **Oculta:** `draft: true` (com o `draft-mode: unlinked` do `_quarto.yml`)
  deixa a página fora do sitemap, da busca e das listagens, mas ela é gerada
  em `docs/` e vai para o ar. O filtro `mini-kit/mini-kit.lua` acrescenta
  `<meta name="robots" content="noindex, nofollow">`, e o `mini-kit.css`
  esconde a faixa "Rascunho" que o Quarto põe nas páginas com `draft: true`.
- **Ano:** o campo `ano` ("2027") entra no título, pelo shortcode
  `{{< meta ano >}}` do Quarto (assim chega também ao `og:title`, a prévia do
  link no WhatsApp), e no texto, por `[ano]{.campo}`; `[ano_anterior]{.campo}`
  é o ano menos 1 (o filtro calcula). Para o ano seguinte, troque só o campo.
- **Campos:** ficam no front matter de `mini-kit/index.qmd`. Campo vazio
  esconde a parte que depende dele:
  - `link_video` (endereço do YouTube): vazio, o vídeo não aparece;
  - `link_planilha` (`arquivos/planilha_padrao_indicadores.xlsx`, a planilha
    padrão em branco, para baixar): vazio, o botão do fim da página mostra
    "Planilha em breve" e o botão do prompt 8 não aparece;
  - `link_planilha_exemplo` (`arquivos/planilha_padrao_indicadores_exemplo.xlsx`):
    vazio, o botão da versão com exemplo não aparece;
  - `data_lancamento`, `preco_cheio`, `preco_pre_venda`, `data_fim_pre_venda`:
    com qualquer um vazio, a frase de preços vira "A pré-venda abre em
    breve..."; escreva os valores como devem aparecer ("19/01/2027", "R$97");
  - `link_kit`: vazio, o botão da pré-venda abre o `link_whatsapp` (mensagem
    "KIT"); quando a página do kit existir, use `https://orbitaspace.com.br/kit/`.
- **Prompts:** cada bloco ```` ```{.texto-prompt} ```` vira texto com quebra de
  linha (sem rolagem lateral), com os `[colchetes]` destacados e o botão
  "Copiar prompt" (script no fim do `index.qmd`, com alternativa para
  navegadores sem `navigator.clipboard`).
- **Estilos:** ficam em `mini-kit/mini-kit.css`, e não em `orbita.scss`, para
  não trocar a folha de estilo das outras páginas. A tabela da Pedra Lisa
  aparece no computador e vira cartões no celular (os dois estão no
  `index.qmd`; ao mudar um número, mude nos dois). No computador, a tabela usa
  a largura da página (`.column-page`), e as larguras das colunas vêm da linha
  de traços da tabela.
- **Planilha padrão:** as duas planilhas ficam no próprio site, para baixar:
  `mini-kit/arquivos/planilha_padrao_indicadores.xlsx` (em branco) e
  `mini-kit/arquivos/planilha_padrao_indicadores_exemplo.xlsx`, versionadas. O
  `resources: arquivos/*.xlsx` do front matter copia as duas para
  `docs/mini-kit/arquivos/`, e os botões usam o atributo `download`. O
  gerador é `mini-kit/planilha/gerar_planilha_padrao.py` (Python com
  openpyxl); para atualizar as planilhas, rode-o com essa pasta como saída:
  `python mini-kit/planilha/gerar_planilha_padrao.py mini-kit/arquivos`.
  (O `.gitignore` de `mini-kit/planilha/` só ignora `.xlsx` gerados naquela
  pasta.) Abas: Leia-me, Indicadores (um card por linha), Lançamentos (uma
  linha por período e indicador) e Painel (último resultado de cada
  indicador, com a cor da situação). A versão de exemplo traz os 3
  indicadores gerais (CX, quanto do faturado virou caixa; TM, ticket médio;
  SP, saldo projetado para 30 dias), com lançamentos fictícios de março a
  outubro de 2026. As fórmulas funcionam no Excel 2010 em diante e no Google
  Planilhas.
- **Sem analytics:** a página não tem a tag do Google Ads. Os cliques são
  medidos pelos pedidos com "KIT" no WhatsApp. Com as planilhas no próprio
  site, os downloads não são contados (o GitHub Pages não tem relatório de
  acessos). Quando `/kit/` existir, os links para a Kiwify levam UTM.

## Caso Mentoria (Padaria Grão Dourado)

`projetos/mentoria-padaria/` (PT), `es/proyectos/mentoria-panaderia/` e
`en/projects/mentoring-bakery/`: exemplo de encontro da mentoria, com dados
fictícios, na frente `mentoria` do filtro de Projetos.

- `scripts/gerar_dados.R` (semente fixa) grava `dados/gabarito.csv` e
  `dados/planilha_baguncada.xlsx`. Não roda no render; rode à mão para
  refazer os dados.
- `scripts/organizar.R` limpa a planilha bagunçada e para com erro se o
  resultado não bater com o gabarito; `scripts/indicadores.R` calcula os três
  indicadores e a faixa de economia (`resultados/padaria.rds`);
  `scripts/planilha_modelo.R` grava as planilhas modelo das três línguas em
  `resultados/`. O `render.ps1` roda os três quando os dados ou os scripts
  mudam.
- `scripts/conferir_planilha.R` calcula as fórmulas das planilhas modelo com o
  pycel (`scripts/calcular_planilha.py`; `pip install pycel`, ou a pasta do
  pacote em `ORBITA_PYCEL`) e compara com a página. Sem o pycel, o render
  pula a conferência com um aviso.
- As planilhas modelo só usam SUMIFS, IF, SUM e contas por linha, para
  funcionar no Excel e no Google Planilhas. `scripts/xlsx.R` grava os .xlsx
  sem as relações para arquivos ausentes que o openxlsx 4.2.8.1 deixa.
- "Margem", e não "lucro", sempre que o valor não desconta aluguel,
  salários e energia (indicador 3: participação na margem total).
- Em inglês, as fornadas aparecem como 6 a.m., 10 a.m., 2 p.m. e 5 p.m.
  (texto, gráficos e planilha); em PT e ES, 6h, 10h, 14h e 17h.

## Página de Serviços

`servicos.qmd`, `es/servicios.qmd` e `en/services.qmd` em três caminhos:

- **Projetos sob medida** (`#projetos`, `#proyectos`, `#projects`): passos de
  "Como funciona" numa linha do tempo (`::: passos`, lista numerada), as três
  frentes para empresas em cartões `.servico` (título h3 com a âncora de
  sempre: `#paineis`, `#indicadores`, `#relatorios` e equivalentes em ES/EN) e
  o botão "Conversar 30 minutos" depois dos passos e no fim do bloco.
- **Mentoria em grupo** (`#mentoria`): formato, passos e lista de espera.
- **Para pesquisas acadêmicas** (`#pesquisas`, `#investigaciones`,
  `#research`, as âncoras antigas da frente de pesquisa): em PT, as duas
  modalidades com os mesmos valores da página do TCC (atualize os dois
  lugares juntos); em ES e EN, só o texto e o link para a página do TCC, em
  português.

## Estrutura

```text
index.qmd, projetos.qmd, servicos.qmd ...   páginas em português (raiz)
es/  en/                                     páginas em espanhol e inglês
_quarto.yml                                  configuração comum (tema, imagens, filtros)
_quarto-pt.yml, _quarto-es.yml, _quarto-en.yml  navbar, rodapé e páginas de cada língua
_traducoes.yml                               qual página corresponde a qual nas três línguas
_freeze/                                     resultados congelados do código R (vai para o Git)
assets/css/orbita.scss                       tema (cores, fontes, componentes)
assets/html/idiomas.html                     seletor PT | ES | EN, faixa de idioma, copiar e-mail
assets/lua/                                  filtro de hreflang, shortcodes da galeria e das frentes
assets/html/frentes.html                     filtro da página de Projetos por frente de serviço
blog/posts/                                  posts em português
privacidade/, mini-kit/                      Política de Privacidade e mini-kit (página oculta)
docs/                                        site gerado (é o que vai ao ar; não edite à mão)
_rascunhos/                                  rascunhos de texto (fora do Git)
```

## Tarefas comuns

- **Novo projeto:** além de entrar na listagem, o projeto precisa de
  `frente:` no cabeçalho, com uma ou mais destas chaves (iguais nas três
  línguas): `paineis`, `pesquisas`, `indicadores`. Exemplo: `frente: [paineis]`.
  É o que alimenta os botões de filtro em Projetos (`{{< frentes >}}`) e os
  botões "Ver projetos de..." em Serviços (`{{< ver-projetos paineis >}}`),
  ambos em `assets/lua/frentes.lua`. Botão de frente sem projeto não aparece;
  projeto sem `frente` ou com chave desconhecida interrompe o render. O filtro
  aceita links como `projetos.html?frente=pesquisas`, e o seletor de idioma
  leva o `?frente=` junto.
- **Novo post:** crie `blog/posts/<nome>/index.qmd` com `title`, `date`,
  `description` e `categories`. Ele aparece no blog em português. Posts em
  espanhol ou inglês vão em `es/blog/posts/` ou `en/blog/posts/`.
  - A imagem da listagem (`image` e `image-alt`) é um print 640x360 de um
    projeto. A do post de indicadores é o gráfico das três taxas do caso,
    gerado por `python scripts/miniatura_post_indicadores.py pt es en`
    depois do render (cada língua usa o gráfico da sua versão do caso).
- **Post traduzido:** acrescente uma entrada em `_traducoes.yml` com os
  endereços das versões e ponha `traducao: <chave>` no cabeçalho de cada uma;
  o seletor de idioma passa a levar à versão correspondente.
- **Vídeo e link do repositório do Radar:** as duas seções estão ligadas nas
  três páginas do projeto (`projetos/radar-absenteismo/index.qmd`,
  `es/proyectos/radar-ausentismo/index.qmd` e
  `en/projects/absenteeism-radar/index.qmd`), com `mostrar-video: true` e
  `mostrar-repositorio: true` no cabeçalho; `false` esconde a seção.
  - O vídeo é um iframe do `youtube-nocookie.com` (não grava cookies antes de
    a pessoa dar o play), dentro de `<div class="video">`, que mantém 16:9 na
    largura da coluna. Para trocar o vídeo, troque o código depois de
    `/embed/` nas três páginas e ajuste o `title` do iframe, que é o nome lido
    por leitores de tela.
  - O vídeo é em português; em ES e EN, a linha
    `[Video en portugués.]{.nota-idioma .nota-video}` (ou `Video in
    Portuguese.`) fica logo abaixo dele.
- **Link do feed RSS do Blog:** está escondido com `mostrar-rss: false` no
  cabeçalho do `blog.qmd`; `true` volta a mostrar "Assinar o feed RSS". O
  feed continua sendo gerado (`feed: true` no `listing`), em `docs/blog.xml`,
  `docs/es/blog.xml` e `docs/en/blog.xml`. As páginas em ES e EN não têm link
  visível para o feed.
- **Painel interativo do Radar:** a seção "Explore o painel" fica logo abaixo
  do vídeo nas mesmas três páginas e liga com `mostrar-painel: true` no
  cabeçalho (`false` esconde).
  - O link "Publicar na Web" do Power BI fica num lugar só: a chave
    `painel-pbi` do `_quarto.yml`. Para trocar o painel, troque esse link.
  - O argumento opcional `chave="..."` escolhe outra chave do `_quarto.yml`
    (sem ele, vale `painel-pbi`). O painel de turnover do caso Motivação de
    desligamento usa `chave="painel-pbi-cestaria"`, nas três línguas da página
    do caso e na landing de People Analytics, sempre com a imagem antes do
    clique.
  - O shortcode `{{< painel-pbi titulo="..." botao="..." >}}`
    (`assets/lua/painel_pbi.lua`) monta a seção: no computador, um iframe
    16:9 mais 60 px para a barra inferior do Power BI; no celular (até
    600 px), um botão que abre o painel numa nova aba. `titulo` é o nome do
    iframe lido por leitores de tela e `botao` é o texto do botão.
  - O painel é em português; em ES e EN, a linha
    `[Tablero en portugués.]{.nota-idioma .nota-painel}` (ou `Dashboard in
    Portuguese.`) fica logo abaixo dele.
- **Página Saline Astral** (`saline-astral.qmd`, `es/saline-astral.qmd` e
  `en/saline-astral.qmd`, ligadas pela chave `saline` do `_traducoes.yml`):
  fica fora do menu principal; o acesso é pela frase do rodapé (`center` do
  `page-footer` em `_quarto-pt.yml`, `_quarto-es.yml` e `_quarto-en.yml`, com
  link para a página na mesma língua) e por link direto. Os textos em ES e EN
  vêm de `_rascunhos/saline_astral_es_en.md`.
  - O visual próprio vem de `body-classes: pagina-saline` no cabeçalho e das
    regras `.pagina-saline` e `.saline-*` em `assets/css/orbita.scss`.
  - Topo: o logo, à esquerda, com link para a página inicial da mesma língua,
    e o nome "Saline Astral" no lugar de "Felipe Fonseca" (troca feita pelo
    script de `assets/html/idiomas.html`; sem JavaScript, fica o nome do site);
    do menu fica só "Início", que o script de `assets/html/idiomas.html` faz
    apontar para a própria página da Saline e marca como atual; o seletor
    PT | ES | EN fica à direita. Sem hambúrguer no celular.
  - Rodapé: o texto da esquerda e os links da direita das duas marcas ficam
    em spans no `page-footer` (`.rodape-marca-felipe` e
    `.rodape-marca-saline`); nas páginas da Saline aparecem os da Saline
    (Planeta Terra; e-mail saline.astral@orbitaspace.com.br, YouTube, TikTok
    e Instagram da Saline). A frase da Saline dá lugar à frase espelhada,
    "Também trabalho com dados e estatística como Felipe Fonseca", que leva à
    página inicial da mesma língua (`.rodape-saline` e `.rodape-dados`).
  - Seções **Artes** e **Poemas**, entre Música e o curso: escondidas com
    `mostrar-artes: false` e `mostrar-poemas: false` no cabeçalho das três
    páginas, até o conteúdo existir. Para mostrar, troque por `true` e
    preencha a seção: a galeria das colagens no lugar do comentário de Artes
    (imagens geradas por `scripts/imagens_artes.py`, nunca copiadas à mão) e
    cada poema num bloco `::: saline-poema`, com os versos começando por
    `| ` para manter as quebras de linha. Na página da Saline a linha do CNPJ
    do rodapé não aparece.
  - Abaixo do nome, no topo, o apelido ("ou apenas Sal para os íntimos",
    `.saline-apelido`). Em "Onde acompanhar", um rótulo por tipo de conteúdo
    (`.saline-canal-tipo`): autoconhecimento em @salineastral (Instagram,
    TikTok e YouTube); poemas e colagens em @fonsekando (Instagram e TikTok).
  - A playlist do curso fica embutida logo abaixo do texto do curso, no mesmo
    padrão do vídeo do Radar (`youtube-nocookie.com/embed/videoseries?list=`).
  - As duas imagens são geradas por `python scripts/imagens_artes.py` (veja
    a faixa de arte, abaixo), em `assets/img/saline/`.
  - Os links das frases do rodapé são HTML (`<a href="/saline-astral.html">`):
    em Markdown, o Quarto no Windows reescreve o endereço com barra invertida.
- **Landing page de estatística para TCC** (`analise-estatistica-tcc.qmd`, só
  em PT): página para os anúncios do Google, fora do menu e das listagens,
  mas no sitemap. O roteiro está em `_rascunhos/landing_tcc.md`. Os três
  botões de WhatsApp usam a referência `[whatsapp]` do fim do arquivo (o link
  e a mensagem ficam num lugar só) e têm a classe fixa `cta-whatsapp-tcc`,
  usada pelo Google Ads para medir as conversões.
  - A tag do Google Ads (`AW-18527658136`) e o script da conversão ficam em
    `assets/html/google-ads.html`, incluído só nas landing pages
    (`include-in-header` no cabeçalho do `.qmd`, que repete o `head.html` do
    site). A conversão dispara só no clique em `.cta-whatsapp-tcc`, com
    `transport_type: beacon`, sem segurar o link; com o Google bloqueado, o
    botão abre o WhatsApp do mesmo jeito.
  - O `scripts/pos_render.py` leva o bloco marcado com
    `<!-- inicio-do-head -->` para logo depois de `<head>`.
- **Landing page de People Analytics** (`people-analytics-power-bi.qmd`, só
  em PT): mesma estrutura e estilo da landing de TCC, fora do menu e das
  listagens, no sitemap. Roteiro em `_rascunhos/landing_people_analytics.md`.
  Os quatro botões de WhatsApp usam a referência `[whatsapp]` do fim do
  arquivo e têm a classe `cta-whatsapp-rh`; a tag do Google Ads e a
  conversão são as mesmas da landing de TCC (`assets/html/google-ads.html`).
  - O painel do Radar entra com `{{< painel-pbi ... imagem="..." imagem-mini="..." alt="..." >}}`:
    com `imagem`, o shortcode mostra a imagem do painel com o botão, e o
    iframe só é inserido no clique (script em `assets/html/idiomas.html`).
    No celular e sem JavaScript, o clique abre o painel numa nova aba. A
    página do Radar continua com o iframe direto (sem `imagem`).
  - O segundo exemplo, ligado ao turnover, é o caso Motivação de desligamento,
    com o painel de turnover da Cestária no mesmo formato clicável
    (`chave="painel-pbi-cestaria"`, imagem `assets/img/painel-turnover-visao-executiva.png`,
    o print da visão executiva). Os números do texto da landing são fixos: se
    a base do caso mudar, atualize à mão.
- **Bordão e faixa de arte no fim das páginas:** o filtro
  `assets/lua/faixa.lua` acrescenta no fim de cada página o bordão do lado de
  dados ("Decifre os sinais dos seus dados.", na língua da página) e a faixa
  `assets/img/faixa_orbita.jpg`; o script de `assets/html/idiomas.html` leva o
  bloco para logo acima do rodapé, na largura total da tela. A faixa tem
  90 px de altura no computador e 60 px no celular, com o centro da imagem.
  Na página da Saline só entra a faixa.
  - A faixa e as aquarelas da Saline vêm de `python scripts/imagens_artes.py`,
    que lê só os arquivos citados no script, da pasta `orbita-marcas/artes`
    ao lado do site (ou `ORBITA_ARTES`), e grava JPGs leves.
- **Trocar a foto:** substitua `assets/img/felipe-original.jpeg`, ajuste as
  medidas do rosto em `scripts/preparar_imagens.py` (função `foto`) e rode o
  script e o `render.ps1`.
