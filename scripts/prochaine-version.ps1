# Calcule la PROCHAINE VERSION d'ebony et son changelog d'apres les titres des PR fusionnees (Conventional Commits).
# Ne modifie RIEN (ni VERSION, ni tag, ni fichier) et ne publie rien : il lit l'historique git et ecrit un rapport. Le numero se pose a la main, au moment d'une release decidee a la main.
#
#   .\scripts\prochaine-version.ps1                   rapport : version actuelle, version proposee, commits retenus
#   .\scripts\prochaine-version.ps1 -Markdown         le changelog en Markdown (a coller dans les notes de version)
#   .\scripts\prochaine-version.ps1 -Depuis <ref>     autre point de depart (tag, commit) ; par defaut : le dernier commit qui a change modules/core/execution/VERSION
#
# Regle (semver, "0.x" tant que la version majeure est 0) :
#   - changement incompatible ("!" apres le type, ou "BREAKING CHANGE:" dans le corps) : majeure ; en 0.x, mineure
#   - feat : mineure ; en 0.x, correctif (patch)      - fix, perf : correctif
#   - docs, test, build, ci, chore, refactor, revert : aucun changement de version a eux seuls
#   - un titre qui ne suit pas le format (les PR d'avant le 2026-11-17) est LISTE a part et ne compte pas dans le calcul
param(
    [string]$Depuis = '',
    [switch]$Markdown
)

$ErrorActionPreference = 'Stop'

# Types retenus dans le changelog, dans l'ordre d'affichage, avec leur titre de section.
$sections = [ordered]@{
    'feat'     = 'Nouveautes'
    'fix'      = 'Corrections'
    'perf'     = 'Performances'
    'refactor' = 'Refontes internes'
}
$motifTitre = '^(?<type>feat|fix|perf|refactor|docs|test|build|ci|chore|revert)(\((?<portee>[a-z0-9._-]+)\))?(?<casse>!)?: (?<description>.+?)(?: \(#(?<pr>\d+)\))?$'

# Un titre -> { Conforme, Type, Portee, Description, Pr, Incompatible }.
function LitTitre([string]$Titre, [string]$Corps) {
    $m = [regex]::Match($Titre.Trim(), $motifTitre)
    if (-not $m.Success) {
        $pr = [regex]::Match($Titre, '\(#(?<pr>\d+)\)\s*$').Groups['pr'].Value
        $sansPr = [regex]::Replace($Titre.Trim(), '\s*\(#\d+\)\s*$', '')
        return [pscustomobject]@{ Conforme = $false; Type = ''; Portee = ''; Description = $sansPr; Pr = $pr; Incompatible = $false }
    }
    $incompatible = ($m.Groups['casse'].Success) -or ($Corps -match '(?m)^BREAKING[ -]CHANGE:')
    return [pscustomobject]@{
        Conforme     = $true
        Type         = $m.Groups['type'].Value
        Portee       = $m.Groups['portee'].Value
        Description  = $m.Groups['description'].Value
        Pr           = $m.Groups['pr'].Value
        Incompatible = [bool]$incompatible
    }
}

# Le niveau de changement le plus fort parmi les lignes : 'majeure', 'mineure', 'correctif' ou 'aucun'.
function NiveauDuChangement([object[]]$Lignes, [int]$Majeure) {
    $niveau = 0   # 0 aucun, 1 correctif, 2 mineure, 3 majeure
    foreach ($ligne in $Lignes) {
        if (-not $ligne.Conforme) { continue }
        $n = 0
        if ($ligne.Incompatible) { if ($Majeure -eq 0) { $n = 2 } else { $n = 3 } }
        elseif ($ligne.Type -eq 'feat') { if ($Majeure -eq 0) { $n = 1 } else { $n = 2 } }
        elseif ($ligne.Type -in @('fix', 'perf')) { $n = 1 }
        if ($n -gt $niveau) { $niveau = $n }
    }
    return @('aucun', 'correctif', 'mineure', 'majeure')[$niveau]
}

# La version suivante pour un niveau donne ("0.1.1" + mineure = "0.2.0").
function VersionSuivante([string]$Version, [string]$Niveau) {
    $m = [regex]::Match($Version.Trim(), '^(\d+)\.(\d+)\.(\d+)$')
    if (-not $m.Success) { throw "Version illisible : '$Version' (attendu X.Y.Z)." }
    $x = [int]$m.Groups[1].Value; $y = [int]$m.Groups[2].Value; $z = [int]$m.Groups[3].Value
    switch ($Niveau) {
        'majeure'   { return ('{0}.0.0' -f ($x + 1)) }
        'mineure'   { return ('{0}.{1}.0' -f $x, ($y + 1)) }
        'correctif' { return ('{0}.{1}.{2}' -f $x, $y, ($z + 1)) }
        default     { return $Version.Trim() }
    }
}

# Le changelog en Markdown : une section par type retenu, les changements incompatibles en tete, puis les titres a classer.
function ChangelogMarkdown([string]$Version, [object[]]$Lignes) {
    $texte = New-Object System.Text.StringBuilder
    [void]$texte.AppendLine("# Ebony $Version")
    [void]$texte.AppendLine()
    $incompatibles = @($Lignes | Where-Object { $_.Conforme -and $_.Incompatible })
    if ($incompatibles.Count -gt 0) {
        [void]$texte.AppendLine('## Changements incompatibles')
        [void]$texte.AppendLine()
        foreach ($l in $incompatibles) { [void]$texte.AppendLine((LigneMarkdown $l)) }
        [void]$texte.AppendLine()
    }
    foreach ($type in $sections.Keys) {
        $groupe = @($Lignes | Where-Object { $_.Conforme -and $_.Type -eq $type -and -not $_.Incompatible })
        if ($groupe.Count -eq 0) { continue }
        [void]$texte.AppendLine('## ' + $sections[$type])
        [void]$texte.AppendLine()
        foreach ($l in $groupe) { [void]$texte.AppendLine((LigneMarkdown $l)) }
        [void]$texte.AppendLine()
    }
    $autres = @($Lignes | Where-Object { -not $_.Conforme })
    if ($autres.Count -gt 0) {
        [void]$texte.AppendLine('## A classer (titres sans type)')
        [void]$texte.AppendLine()
        foreach ($l in $autres) { [void]$texte.AppendLine((LigneMarkdown $l)) }
        [void]$texte.AppendLine()
    }
    return $texte.ToString().TrimEnd()
}

function LigneMarkdown([object]$Ligne) {
    $portee = ''
    if ($Ligne.Portee -ne '') { $portee = '**' + $Ligne.Portee + '** : ' }
    $pr = ''
    if ($Ligne.Pr -ne '') { $pr = ' (#' + $Ligne.Pr + ')' }
    return '- ' + $portee + $Ligne.Description + $pr
}

# Rien d'autre ne s'execute quand ce fichier est charge par un test (". .\prochaine-version.ps1").
if ($MyInvocation.InvocationName -eq '.') { return }

$racine = Split-Path $PSScriptRoot -Parent
$fichierVersion = Join-Path $racine 'modules/core/execution/VERSION'
$versionActuelle = (Get-Content -LiteralPath $fichierVersion -TotalCount 1).Trim()
Push-Location $racine
try {
    if ($Depuis -eq '') {
        $Depuis = (git log -1 --format=%H -- 'modules/core/execution/VERSION').Trim()
        if ($Depuis -eq '') { throw "Aucun commit n'a change modules/core/execution/VERSION : donnez un point de depart avec -Depuis." }
    }
    $brut = git log --first-parent --format='%H%x1f%s%x1f%b%x1e' "$Depuis..HEAD"
    $lignes = @()
    foreach ($entree in ([regex]::Split(($brut -join "`n"), [string][char]0x1E))) {
        $e = $entree.Trim()
        if ($e -eq '') { continue }
        $champs = $e.Split([char]0x1F, 3)
        if ($champs.Count -lt 2) { continue }
        $corps = ''
        if ($champs.Count -ge 3) { $corps = $champs[2] }
        $lignes += LitTitre $champs[1] $corps
    }
} finally { Pop-Location }

$majeure = [int]($versionActuelle.Split('.')[0])
$niveau = NiveauDuChangement $lignes $majeure
$proposee = VersionSuivante $versionActuelle $niveau

if ($Markdown) {
    ChangelogMarkdown $proposee $lignes
    return
}

$conformes = @($lignes | Where-Object { $_.Conforme })
$autres = @($lignes | Where-Object { -not $_.Conforme })
Write-Host ("Version actuelle   : " + $versionActuelle + "  (modules/core/execution/VERSION)")
Write-Host ("Depuis             : " + $Depuis.Substring(0, [Math]::Min(9, $Depuis.Length)))
Write-Host ("PR fusionnees      : " + $lignes.Count + "  (" + $conformes.Count + " au format Conventional Commits, " + $autres.Count + " sans type)")
Write-Host ("Niveau de changement : " + $niveau)
Write-Host ("Version proposee   : " + $proposee)
if ($autres.Count -gt 0) { Write-Host ("Les " + $autres.Count + " titres sans type ne comptent pas dans le calcul : ils sont dans -Markdown, section 'A classer'.") }
Write-Host ""
foreach ($type in @('feat', 'fix', 'perf', 'refactor', 'docs', 'test', 'build', 'ci', 'chore', 'revert')) {
    $n = @($conformes | Where-Object { $_.Type -eq $type }).Count
    if ($n -gt 0) { Write-Host ("  {0,-9} {1}" -f $type, $n) }
}
$incompatibles = @($conformes | Where-Object { $_.Incompatible })
if ($incompatibles.Count -gt 0) { Write-Host ("  changements incompatibles : " + $incompatibles.Count) }
