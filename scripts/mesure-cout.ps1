# Mesure : ce que coute, a chaque lancement d'owl, un projet genere par kit (slim, api).
#
# Pourquoi : OWL analyse TOUS les .owl du projet a chaque lancement (pas de cache), donc chaque classe ajoutee a la bibliotheque d'un module se paie dans tous les projets qui l'embarquent.
# Un projet slim (coeur seul) et un projet api (coeur, base, jetons) font apparaitre cet ecart ; le suivre d'un jalon a l'autre montre une derive avant qu'elle ne pese.
# Idee reprise de la mesure de taille d'applications types de MyGo : "les applications ne paient que ce qu'elles utilisent".
#
# Le script cree un projet de chaque kit dans un dossier temporaire du systeme (jamais sous le depot), lance "owl --check projet.owl" N fois dans chacun, et affiche le nombre de fichiers .owl,
# la mediane et l'etendue des durees. Il ne modifie rien dans le depot. INFORMATIF : code 0 meme si le projet api est plus lent ; code 1 seulement si un projet ne peut pas etre cree ou ne compile pas.
# Une duree ne se compare qu'a une autre mesuree dans les memes conditions : le script avertit quand la machine n'est pas au repos (charge du processeur), et ne conclut rien.
#
# Usage : .\scripts\mesure-cout.ps1 [-Repetitions 3]       Windows seulement (bin\ebony.cmd). Duree : environ 1 minute. Ce fichier reste ASCII.

param([int]$Repetitions = 3)

$ErrorActionPreference = 'Stop'
$racine = Split-Path $PSScriptRoot -Parent
$lanceur = Join-Path $racine 'bin\ebony.cmd'
if ($Repetitions -lt 1) { Write-Host "ECHEC : -Repetitions doit etre au moins 1" -ForegroundColor Red; exit 1 }
if (-not (Test-Path -LiteralPath $lanceur)) { Write-Host "ECHEC : bin\ebony.cmd introuvable (script pour Windows)" -ForegroundColor Red; exit 1 }

function Mediane([double[]]$Valeurs) {
    $tri = @($Valeurs | Sort-Object)
    $milieu = [int][Math]::Floor($tri.Count / 2)
    if ($tri.Count % 2 -eq 1) { return $tri[$milieu] }
    return ($tri[$milieu - 1] + $tri[$milieu]) / 2
}

# Charge du processeur : deux echantillons espaces de quelques secondes (une mesure faite machine chargee ne vaut rien).
$charges = @()
foreach ($i in 1..2) { $charges += [double](Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average; if ($i -eq 1) { Start-Sleep -Seconds 4 } }
$chargeMoyenne = [Math]::Round(($charges | Measure-Object -Average).Average, 0)
if ($chargeMoyenne -gt 25) { Write-Host ("ATTENTION : processeur occupe a " + $chargeMoyenne + " % : les durees ci-dessous ne sont pas comparables a une mesure faite machine au repos.") -ForegroundColor Yellow }

$versionOwl = (& owl --version 2>&1 | ForEach-Object { "$_" }) -join ' '
$zone = Join-Path ([IO.Path]::GetTempPath()) ('ebony-cout-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $zone | Out-Null
$resultats = @()
$echec = $false

try {
    foreach ($kit in 'slim', 'api') {
        Push-Location $zone
        try {
            $sortie = (& $lanceur new ("cout-" + $kit) --kit $kit 2>&1 | ForEach-Object { "$_" }) -join "`n"
            if ($LASTEXITCODE -ne 0) { Write-Host ("ECHEC : ebony new --kit " + $kit + " : " + $sortie) -ForegroundColor Red; $echec = $true; continue }
        } finally { Pop-Location }

        $dossier = Join-Path $zone ("cout-" + $kit)
        $nbFichiers = @(Get-ChildItem -LiteralPath $dossier -Recurse -File -Filter *.owl).Count
        $durees = @()
        Push-Location $dossier
        try {
            foreach ($n in 1..$Repetitions) {
                $debut = Get-Date
                $sortieOwl = (& owl --check projet.owl 2>&1 | ForEach-Object { "$_" }) -join "`n"
                $duree = ((Get-Date) - $debut).TotalSeconds
                if (($LASTEXITCODE -ne 0) -or ($sortieOwl -notmatch '"errors":\[\]')) { Write-Host ("ECHEC : owl --check ne passe pas dans le projet " + $kit + " : " + $sortieOwl) -ForegroundColor Red; $echec = $true; break }
                $durees += $duree
            }
        } finally { Pop-Location }
        if ($durees.Count -gt 0) {
            $resultats += [pscustomobject]@{ Kit = $kit; Fichiers = $nbFichiers; Mediane = [Math]::Round((Mediane $durees), 2); Min = [Math]::Round(($durees | Measure-Object -Minimum).Minimum, 2); Max = [Math]::Round(($durees | Measure-Object -Maximum).Maximum, 2) }
        }
    }
}
finally {
    if (Test-Path -LiteralPath $zone) { try { Remove-Item -Recurse -Force -LiteralPath $zone -ErrorAction Stop } catch { Write-Host ("ATTENTION : dossier temporaire non supprime : " + $zone) -ForegroundColor Yellow } }
}

Write-Host ""
Write-Host ("owl " + $versionOwl + " ; " + $Repetitions + " lancement(s) de owl --check par projet ; processeur a " + $chargeMoyenne + " % avant la mesure")
$resultats | Format-Table -AutoSize | Out-String | Write-Host
$slim = @($resultats | Where-Object { $_.Kit -eq 'slim' })[0]
$api = @($resultats | Where-Object { $_.Kit -eq 'api' })[0]
if ($slim -and $api) {
    Write-Host ("api - slim : " + ($api.Fichiers - $slim.Fichiers) + " fichier(s) .owl de plus, " + [Math]::Round($api.Mediane - $slim.Mediane, 2) + " s de plus (medianes).")
}
if ($echec) { exit 1 }
exit 0
