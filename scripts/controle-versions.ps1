# Controle : le numero de version ecrit en dur dans les textes publics est celui de modules\core\execution\VERSION.
#
# Pourquoi : la version vit a un seul endroit (VERSION, lue par le lanceur, construit-archive.ps1 et ebony --version), mais la phrase "Preversion X.Y.Z" du README, de la page d'accueil et des guides
# est ecrite a la main. Apres un passage de VERSION a 0.1.2, un texte resterait a 0.1.1 sans que rien ne le dise. Idee reprise du controle de coherence des versions de MyGo.
# Il verifie, sans lancer owl :
#   1. VERSION contient un numero X.Y.Z ;
#   2. chaque mention du numero dans les textes ci-dessous (Preversion X.Y.Z, "Ebony X.Y.Z est une preversion", un dossier ebony-X.Y.Z) est ce numero ;
#   3. il y a au moins une mention par fichier attendu : un controle qui ne lit rien ne doit pas passer.
# Les numeros de version cites comme HISTOIRE ("les versions 0.1.0 et 0.1.1 notent db") ne sont pas des mentions de la version courante : ils ne sont pas lus.
#
# Usage : .\scripts\controle-versions.ps1 [-Racine <dossier>]       code de sortie 0 si tout est d'accord, 1 sinon. Ce fichier reste ASCII.

param([string]$Racine = '')

if ($Racine -eq '') { $Racine = Split-Path $PSScriptRoot -Parent }
$utf8 = New-Object System.Text.UTF8Encoding($false)
$echecs = 0

function Echec([string]$Texte) { Write-Host ("  [ECHEC]  " + $Texte) -ForegroundColor Red; $script:echecs++ }

$fichierVersion = Join-Path $Racine 'modules\core\execution\VERSION'
if (-not (Test-Path -LiteralPath $fichierVersion)) { Echec "modules\core\execution\VERSION introuvable dans $Racine"; exit 1 }
$version = $utf8.GetString([IO.File]::ReadAllBytes($fichierVersion)).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { Echec "VERSION ne contient pas un numero X.Y.Z : '$version'"; exit 1 }

# Fichier -> ce qu'on y attend : au moins une mention. Les expressions : "." tient la place du e accentue de Preversion.
$mentionsAttendues = @(
    @{ Fichier = 'README.md';                          Expression = 'Pr.version (\d+\.\d+\.\d+)' },
    @{ Fichier = 'docs\index.md';                      Expression = 'Pr.version (\d+\.\d+\.\d+)' },
    @{ Fichier = 'docs\guides\introduction.md';        Expression = 'Pr.version (\d+\.\d+\.\d+)' },
    @{ Fichier = 'docs\guides\statut-et-limites.md';   Expression = 'Ebony (\d+\.\d+\.\d+) est une' },
    @{ Fichier = 'docs\guides\installation.md';        Expression = 'ebony-(\d+\.\d+\.\d+)\\bin' }
)

$nbMentions = 0
foreach ($m in $mentionsAttendues) {
    $chemin = Join-Path $Racine $m.Fichier
    if (-not (Test-Path -LiteralPath $chemin)) { Echec ($m.Fichier + " : fichier absent"); continue }
    $texte = $utf8.GetString([IO.File]::ReadAllBytes($chemin))
    $trouvees = [regex]::Matches($texte, $m.Expression)
    if ($trouvees.Count -eq 0) { Echec ($m.Fichier + " : aucune mention du numero de version (le controle ne lirait rien)"); continue }
    foreach ($t in $trouvees) {
        $nbMentions++
        if ($t.Groups[1].Value -ne $version) { Echec ($m.Fichier + " : mentionne " + $t.Groups[1].Value + " alors que VERSION dit " + $version) }
    }
}

if ($echecs -eq 0) { Write-Host ("Versions d'accord : " + $nbMentions + " mention(s) dans " + $mentionsAttendues.Count + " fichiers, toutes " + $version + " (modules\core\execution\VERSION).") -ForegroundColor Green; exit 0 }
Write-Host ("VERSIONS : " + $echecs + " ECHEC(S)") -ForegroundColor Red
exit 1
