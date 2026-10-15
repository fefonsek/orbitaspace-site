# Gera o site completo (PT, ES, EN) na pasta docs/.
# Uso, no PowerShell, dentro da pasta do site:  .\render.ps1
#
# Por que este script existe: cada idioma é um perfil do Quarto, e uma
# renderização completa normalmente APAGA a pasta de saída antes de
# começar. Aqui a limpeza é feita uma única vez, no início, e os três
# perfis rodam com --no-clean, então nenhum idioma apaga a saída dos outros.

Set-Location $PSScriptRoot
# Avisa scripts\aviso_render.py que a renderização parcial é intencional.
$env:ORBITA_RENDER_COMPLETO = "1"
$temp = Join-Path $env:TEMP "orbitaspace-sitemaps"
New-Item -ItemType Directory -Force $temp | Out-Null

# 0. Caso TCC: a análise em R roda uma vez e grava um .rds que as três
#    versões da página (PT, ES, EN) leem. Ela só roda de novo se os dados ou
#    o script da análise mudaram. Se o .rds, os textos ou os gráficos mudaram,
#    o resultado congelado (_freeze) das três páginas é descartado, para que
#    elas sejam refeitas com o conteúdo novo.
$caso = "projetos\caso-tcc-rotatividade"
$rds = "$caso\resultados\analise.rds"
$fontesAnalise = Get-ChildItem "$caso\dados\*.csv", "$caso\scripts\analise.R"
if (-not (Test-Path $rds) -or ($fontesAnalise | Where-Object { $_.LastWriteTime -gt (Get-Item $rds).LastWriteTime })) {
    $rscript = Get-ChildItem "$env:ProgramFiles\R\R-*\bin\Rscript.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName | Select-Object -Last 1
    if (-not $rscript) { Write-Host "Rscript não encontrado em $env:ProgramFiles\R." -ForegroundColor Red; exit 1 }
    Write-Host "`n=== Caso TCC: rodando a análise em R ===" -ForegroundColor Cyan
    & $rscript.FullName "$caso\scripts\analise.R"
    if ($LASTEXITCODE -ne 0) { Write-Host "Falha na análise do caso TCC." -ForegroundColor Red; exit 1 }
}
$ultimaMudanca = (Get-ChildItem $rds, "$caso\scripts\rotulos.R", "$caso\scripts\apresentacao.R" |
    Sort-Object LastWriteTime | Select-Object -Last 1).LastWriteTime
foreach ($congelado in "_freeze\$caso", "_freeze\es\proyectos\tesis-rotacion", "_freeze\en\projects\thesis-turnover") {
    $json = "$congelado\index\execute-results\html.json"
    if ((Test-Path $json) -and (Get-Item $json).LastWriteTime -lt $ultimaMudanca) {
        Remove-Item $congelado -Recurse -Force
        Write-Host "Caso TCC: $congelado descartado; a página será refeita."
    }
}

# 0b. Caso Indicadores: as três taxas de absenteísmo, mês a mês, vêm da base do
#     Radar (pasta do painel ao lado do site, ou ORBITA_ORIGEM_PAINEL). O
#     agregar_radar.R só lê essa base e grava um CSV agregado de 72 linhas; ele
#     roda só quando o CSV não existe ou quando a base ou o script mudaram. Sem
#     a pasta do Radar, o CSV que já está no site é usado. Se os dados ou os
#     scripts mudaram, o resultado congelado da página é descartado.
$indicadores = "projetos\governanca-indicadores"
$csvTaxas = "$indicadores\dados\taxa_tres_definicoes.csv"
$origemPainel = if ($env:ORBITA_ORIGEM_PAINEL) { $env:ORBITA_ORIGEM_PAINEL } else { Join-Path (Split-Path $PSScriptRoot -Parent) "radar-absenteismo-powerbi" }
$baseRadar = Join-Path $origemPainel "data\raw"
if (Test-Path $baseRadar) {
    $fontesTaxas = @(Get-ChildItem "$baseRadar\*.csv") + @(Get-Item "$indicadores\scripts\agregar_radar.R")
    if (-not (Test-Path $csvTaxas) -or ($fontesTaxas | Where-Object { $_.LastWriteTime -gt (Get-Item $csvTaxas).LastWriteTime })) {
        $rscript = Get-ChildItem "$env:ProgramFiles\R\R-*\bin\Rscript.exe" -ErrorAction SilentlyContinue |
            Sort-Object FullName | Select-Object -Last 1
        if (-not $rscript) { Write-Host "Rscript não encontrado em $env:ProgramFiles\R." -ForegroundColor Red; exit 1 }
        Write-Host "`n=== Caso Indicadores: agregando as taxas da base do Radar ===" -ForegroundColor Cyan
        & $rscript.FullName "$indicadores\scripts\agregar_radar.R"
        if ($LASTEXITCODE -ne 0) { Write-Host "Falha ao agregar as taxas do caso Indicadores." -ForegroundColor Red; exit 1 }
    }
} elseif (-not (Test-Path $csvTaxas)) {
    Write-Host "Caso Indicadores: base do Radar não encontrada em $baseRadar e o CSV agregado não existe." -ForegroundColor Red
    exit 1
}
$ultimaMudanca = (Get-ChildItem "$indicadores\dados\*", "$indicadores\scripts\*" |
    Sort-Object LastWriteTime | Select-Object -Last 1).LastWriteTime
foreach ($congelado in "_freeze\$indicadores", "_freeze\es\proyectos\gobernanza-indicadores", "_freeze\en\projects\kpi-governance") {
    $json = "$congelado\index\execute-results\html.json"
    if ((Test-Path $json) -and (Get-Item $json).LastWriteTime -lt $ultimaMudanca) {
        Remove-Item $congelado -Recurse -Force
        Write-Host "Caso Indicadores: $congelado descartado; a página será refeita."
    }
}

# 0c. Caso Auditoria (PT, ES e EN): a auditoria (scripts/auditoria.R), a
#     conferência com o gabarito do gerador (scripts/conferir.R) e os CSVs de
#     casos traduzidos (scripts/traduzir_casos.R) rodam só quando os dados ou
#     os scripts mudaram. O relatório em PDF (relatorio/, projeto à parte, em
#     Typst) é refeito nas três línguas quando os resultados, os textos ou os
#     gráficos mudaram; se algum passar de 4 páginas, o Typst para com erro e
#     o render também. O PT é gerado por último: o render de uma língua apaga
#     a saída padrão (relatorio.pdf) do mesmo arquivo.
#     Os dados não são gerados de novo aqui: para isso, rode o gerar_dados.R.
$auditoria = "projetos\auditoria-alimentacao"
$rdsAud = "$auditoria\resultados\auditoria.rds"
$fontesAud = @(Get-ChildItem "$auditoria\dados\*") + @(Get-Item "$auditoria\scripts\auditoria.R",
    "$auditoria\scripts\conferir.R", "$auditoria\scripts\traduzir_casos.R", "$auditoria\scripts\rotulos.R")
$csvTraduzidos = "$auditoria\resultados\casos_revisar_es.csv", "$auditoria\resultados\casos_revisar_en.csv"
$faltaCsv = $csvTraduzidos | Where-Object { -not (Test-Path $_) }
if ($faltaCsv -or -not (Test-Path $rdsAud) -or ($fontesAud | Where-Object { $_.LastWriteTime -gt (Get-Item $rdsAud).LastWriteTime })) {
    $rscript = Get-ChildItem "$env:ProgramFiles\R\R-*\bin\Rscript.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName | Select-Object -Last 1
    if (-not $rscript) { Write-Host "Rscript não encontrado em $env:ProgramFiles\R." -ForegroundColor Red; exit 1 }
    Write-Host "`n=== Caso Auditoria: rodando a auditoria, a conferência e os CSVs traduzidos ===" -ForegroundColor Cyan
    foreach ($script in "auditoria.R", "conferir.R", "traduzir_casos.R") {
        & $rscript.FullName "$auditoria\scripts\$script"
        if ($LASTEXITCODE -ne 0) { Write-Host "Falha em $script do caso Auditoria." -ForegroundColor Red; exit 1 }
    }
}
$fontesPdf = @(Get-Item "$auditoria\resultados\auditoria.rds", "$auditoria\resultados\conferencia.rds",
    "$auditoria\relatorio\relatorio.qmd", "$auditoria\scripts\apresentacao.R", "$auditoria\scripts\rotulos.R") +
    @(Get-ChildItem "$auditoria\relatorio\textos_*.yml")
$pdfs = [ordered]@{ es = "relatorio-es.pdf"; en = "relatorio-en.pdf"; pt = "relatorio.pdf" }
$refazerPdf = $false
foreach ($arquivo in $pdfs.Values) {
    $pdf = "$auditoria\relatorio\$arquivo"
    if (-not (Test-Path $pdf) -or ($fontesPdf | Where-Object { $_.LastWriteTime -gt (Get-Item $pdf).LastWriteTime })) { $refazerPdf = $true }
}
if ($refazerPdf) {
    # O --output grava na pasta de onde o quarto é chamado: por isso o render
    # roda de dentro de relatorio/.
    Push-Location "$auditoria\relatorio"
    foreach ($idioma in $pdfs.Keys) {
        Write-Host "`n=== Caso Auditoria: gerando o relatório em PDF ($idioma) ===" -ForegroundColor Cyan
        quarto render relatorio.qmd -P "idioma:$idioma" --output $pdfs[$idioma]
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            Write-Host "Falha ao gerar o relatório em PDF ($idioma) do caso Auditoria." -ForegroundColor Red; exit 1
        }
    }
    Pop-Location
}
$ultimaAud = (Get-ChildItem "$auditoria\resultados\*", "$auditoria\scripts\*" |
    Sort-Object LastWriteTime | Select-Object -Last 1).LastWriteTime
foreach ($congelado in "_freeze\$auditoria", "_freeze\es\proyectos\auditoria-alimentacion", "_freeze\en\projects\meal-allowance-audit") {
    $jsonAud = "$congelado\index\execute-results\html.json"
    if ((Test-Path $jsonAud) -and (Get-Item $jsonAud).LastWriteTime -lt $ultimaAud) {
        Remove-Item $congelado -Recurse -Force
        Write-Host "Caso Auditoria: $congelado descartado; a página será refeita."
    }
}

# 1. Limpa a saída anterior (assim páginas removidas não ficam esquecidas).
if (Test-Path docs) { Remove-Item docs -Recurse -Force }

# 2. Renderiza cada idioma sem limpar a pasta e guarda o sitemap de cada um,
#    porque cada perfil sobrescreve docs/sitemap.xml com só as suas páginas.
foreach ($perfil in "pt", "es", "en") {
    Write-Host "`n=== Renderizando perfil $perfil ===" -ForegroundColor Cyan
    quarto render --profile $perfil --no-clean
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Falha ao renderizar o perfil $perfil." -ForegroundColor Red
        exit 1
    }
    Copy-Item docs\sitemap.xml (Join-Path $temp "sitemap-$perfil.xml") -Force
}

# 3. Junta os três sitemaps e confere se todas as páginas existem.
python scripts\pos_render.py $temp
if ($LASTEXITCODE -ne 0) { exit 1 }
