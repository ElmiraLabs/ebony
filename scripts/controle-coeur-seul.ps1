# Le coeur d'ebony seul : une copie du depot SANS les modules (burin, auth) et SANS leurs tests doit compiler, passer ses propres tests et produire un projet "slim" qui compile.
# C'est la condition pour que le coeur puisse vivre dans son propre depot : il ne depend d'aucun module, un module depend de lui.
# Etapes, dans une copie du dossier de travail (hors depot, dossier temporaire) : retirer modules/<tout sauf core> et les tests de ces modules, regenerer l'aiguillage des commandes
# (il ne cite plus que les commandes du coeur), owl --check projet.owl, test-rapide.ps1, construit-entrees.ps1, puis ebony new --kit slim et owl --check dans le projet cree.
# Usage : .\scripts\controle-coeur-seul.ps1      (code de sortie 0 si tout passe, 1 sinon). Duree : environ 3 minutes.
# Ce fichier reste ASCII.

$ErrorActionPreference = 'Stop'
$depot = Split-Path $PSScriptRoot -Parent
$programmePowerShell = (Get-Process -Id $PID).Path
$suffixe = [Guid]::NewGuid().ToString('N').Substring(0, 8)
$copie = Join-Path ([IO.Path]::GetTempPath()) ('ebony-coeur-seul-' + $suffixe)
$echecs = 0

function Verifie([string]$Titre, [bool]$Condition, [string]$Detail) {
    if ($Condition) { Write-Host ("  [OK]     " + $Titre) }
    else { Write-Host ("  [ECHEC]  " + $Titre) -ForegroundColor Red; if ($Detail) { Write-Host ("           " + $Detail) }; $script:echecs++ }
}

# Les dossiers de tests qui appartiennent a un module (sous tests\unitaires) : ils partent avec lui quand le module quitte le depot (liste : scripts\modules-tests.ps1).
. (Join-Path $PSScriptRoot 'modules-tests.ps1')
$testsDesModules = @($testsParModule.Values | ForEach-Object { $_ })

try {
    Write-Host ("Copie du depot sans .git, tmp, .commandes : " + $copie)
    New-Item -ItemType Directory -Force $copie | Out-Null
    $null = & robocopy $depot $copie /E /XD .git tmp .commandes node_modules .vitepress /XF .mcp.json /NFL /NDL /NJH /NJS /NP
    if ($LASTEXITCODE -ge 8) { throw "robocopy a echoue (code $LASTEXITCODE)" }

    $retires = @()
    foreach ($module in @(Get-ChildItem (Join-Path $copie 'modules') -Directory)) {
        if ($module.Name -ne 'core') { $retires += $module.Name; Remove-Item -LiteralPath $module.FullName -Recurse -Force }
    }
    foreach ($dossierTests in $testsDesModules) {
        $chemin = Join-Path (Join-Path $copie 'tests\unitaires') $dossierTests
        if (Test-Path -LiteralPath $chemin) { Remove-Item -LiteralPath $chemin -Recurse -Force }
    }
    Write-Host ("Modules retires : " + ($retires -join ', '))
    Verifie "au moins un module a ete retire (le controle ne verifie rien sinon)" ($retires.Count -gt 0) ''

    $sortie = (& $programmePowerShell -NoProfile -File (Join-Path $copie 'scripts\genere-aiguillage.ps1') 2>&1 | ForEach-Object { "$_" }) -join "`n"
    Verifie "l'aiguillage est regenere sans les commandes des modules" ($LASTEXITCODE -eq 0) $sortie
    $aiguillage = [IO.File]::ReadAllText((Join-Path $copie 'src\commandes\EbAiguillage.owl'))
    Verifie "l'aiguillage ne cite plus migrate, make ni token" (($aiguillage -notmatch 'EbExecuteMigrate') -and ($aiguillage -notmatch 'EbExecuteMake') -and ($aiguillage -notmatch 'EbExecuteToken')) ''

    Push-Location $copie
    try {
        $ErrorActionPreference = 'Continue'
        $sortie = (owl --check projet.owl 2>&1 | ForEach-Object { "$_" }) -join "`n"
        $codeCheck = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        Verifie "owl --check projet.owl : le coeur compile sans les modules" (($codeCheck -eq 0) -and ($sortie -match '"errors":\[\]')) $sortie

        $ErrorActionPreference = 'Continue'
        $sortie = (& $programmePowerShell -NoProfile -File (Join-Path $copie 'scripts\test-rapide.ps1') 2>&1 | ForEach-Object { "$_" }) -join "`n"
        $codeTests = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        $resume = ($sortie -split "`n" | Where-Object { $_ -match '^Suites :' } | Select-Object -Last 1)
        Verifie ("les tests du coeur passent sans les modules : " + $resume) (($codeTests -eq 0) -and ($sortie -match 'TOUT PASSE')) (($sortie -split "`n" | Where-Object { $_ -match 'ECHEC|Error' } | Select-Object -First 12) -join "`n")

        $ErrorActionPreference = 'Continue'
        $sortie = (& $programmePowerShell -NoProfile -File (Join-Path $copie 'scripts\construit-entrees.ps1') 2>&1 | ForEach-Object { "$_" }) -join "`n"
        $codeEntrees = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        Verifie "les points d'entree reduits se construisent" ($codeEntrees -eq 0) $sortie
    } finally { $ErrorActionPreference = 'Stop'; Pop-Location }

    # Un projet slim cree par ce coeur seul compile : le coeur sait generer une application sans aucun module.
    $zone = Join-Path $copie 'zone-slim'
    New-Item -ItemType Directory -Force $zone | Out-Null
    Push-Location $zone
    try {
        $ErrorActionPreference = 'Continue'
        $sortie = (& (Join-Path $copie 'bin\ebony.cmd') new petit --kit slim 2>&1 | ForEach-Object { "$_" }) -join "`n"
        $codeNew = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        Verifie "ebony new --kit slim avec le coeur seul : code 0" ($codeNew -eq 0) $sortie
        Push-Location (Join-Path $zone 'petit')
        try {
            $ErrorActionPreference = 'Continue'
            $sortie = (owl --check projet.owl 2>&1 | ForEach-Object { "$_" }) -join "`n"
            $ErrorActionPreference = 'Stop'
            Verifie "le projet slim genere compile" ($sortie -match '"errors":\[\]') $sortie
        } finally { $ErrorActionPreference = 'Stop'; Pop-Location }
    } finally { $ErrorActionPreference = 'Stop'; Pop-Location }
}
finally {
    if (Test-Path -LiteralPath $copie) {
        try { Remove-Item -Recurse -Force -LiteralPath $copie -ErrorAction Stop }
        catch { Start-Sleep -Seconds 2; try { Remove-Item -Recurse -Force -LiteralPath $copie -ErrorAction Stop } catch { Write-Host ("  [ECHEC]  nettoyage impossible de " + $copie) -ForegroundColor Red; $echecs++ } }
    }
}

Write-Host ""
if ($echecs -eq 0) { Write-Host "COEUR SEUL : TOUT PASSE" -ForegroundColor Green; exit 0 }
Write-Host ("COEUR SEUL : " + $echecs + " ECHEC(S)") -ForegroundColor Red
exit 1
