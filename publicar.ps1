# Prepara o site para publicação. Uso, no PowerShell, dentro da pasta do site:
#   .\publicar.ps1
#
# 1. Roda o render.ps1 completo (PT, ES e EN em docs/).
# 2. Recusa continuar se houver em docs/:
#    - marcador provisório ([VÍDEO AQUI], [LINK DO REPOSITÓRIO]);
#    - travessão ou meia-risca (U+2014 ou U+2013);
#    - imagem citada que não existe;
#    - a foto original (felipe-original.jpeg).
#    No render comum o marcador só gera aviso; aqui ele bloqueia.
#
# Ainda não envia nada ao GitHub: o envio entra na etapa 6.

Set-Location $PSScriptRoot
$env:ORBITA_PUBLICAR = "1"

.\render.ps1
$resultado = $LASTEXITCODE
Remove-Item Env:ORBITA_PUBLICAR

if ($resultado -ne 0) {
    Write-Host ""
    Write-Host "PUBLICAÇÃO RECUSADA: corrija os problemas listados acima e rode .\publicar.ps1 de novo." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Checagens aprovadas: docs/ está pronto para publicar." -ForegroundColor Green
Write-Host "(O envio ao GitHub ainda não está configurado; isso fica para a etapa 6.)"
