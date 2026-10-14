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
