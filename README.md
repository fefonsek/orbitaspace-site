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
  da aba por um ponto médio: "Projetos · Orbita Space".
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
    regras `.pagina-saline` e `.saline-*` em `assets/css/orbita.scss`. Nessa
    página o menu some (ficam o logo, à esquerda, com link para a página
    inicial da mesma língua, e o seletor PT | ES | EN, à direita), o WhatsApp do rodapé não aparece
    (`.rodape-whatsapp`) e a frase da Saline dá lugar à frase espelhada,
    "Também trabalho com dados e estatística como Felipe Fonseca", que leva à
    página inicial da mesma língua (`.rodape-saline` e `.rodape-dados`).
  - A playlist do curso fica embutida logo abaixo do texto do curso, no mesmo
    padrão do vídeo do Radar (`youtube-nocookie.com/embed/videoseries?list=`).
  - As duas imagens são geradas por `python scripts/imagens_artes.py` (veja
    a faixa de arte, abaixo), em `assets/img/saline/`.
  - Os links das frases do rodapé são HTML (`<a href="/saline-astral.html">`):
    em Markdown, o Quarto no Windows reescreve o endereço com barra invertida.
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
