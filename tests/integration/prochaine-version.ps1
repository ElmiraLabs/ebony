# Test de scripts/prochaine-version.ps1 : lecture des titres (Conventional Commits), niveau de changement, version suivante et changelog.
# Sans git ni owl : le script est charge par un point (". .\prochaine-version.ps1"), seules ses fonctions s'executent.
# Code de sortie 0 si tout passe, 1 sinon. Ce fichier reste ASCII.
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'scripts\prochaine-version.ps1')

$echecs = 0
$nombre = 0
function Verifie([string]$Libelle, $Obtenu, $Attendu) {
    $script:nombre++
    if ("$Obtenu" -ceq "$Attendu") { Write-Host "  [OK]     $Libelle" }
    else { Write-Host "  [ECHEC]  $Libelle : obtenu '$Obtenu', attendu '$Attendu'"; $script:echecs++ }
}

Write-Host "lecture des titres"
$l = LitTitre 'feat(make): une nouvelle option (#1012)' ''
Verifie 'feat avec portee : conforme' $l.Conforme $true
Verifie 'feat avec portee : type' $l.Type 'feat'
Verifie 'feat avec portee : portee' $l.Portee 'make'
Verifie 'feat avec portee : description sans le numero de PR' $l.Description 'une nouvelle option'
Verifie 'feat avec portee : numero de PR' $l.Pr '1012'
Verifie 'feat avec portee : pas incompatible' $l.Incompatible $false
$l = LitTitre 'fix: corrige un test' ''
Verifie 'fix sans portee : conforme' $l.Conforme $true
Verifie 'fix sans portee : portee vide' $l.Portee ''
$l = LitTitre 'feat(liste)!: la liste est paginee (#1187)' ''
Verifie 'point d exclamation : incompatible' $l.Incompatible $true
$l = LitTitre 'refactor: reorganise' "Detail.`n`nBREAKING CHANGE: le format change"
Verifie 'BREAKING CHANGE dans le corps : incompatible' $l.Incompatible $true
$l = LitTitre 'Liste paginee, triee et filtrable dans le controleur genere (#1187)' ''
Verifie 'ancien titre sans type : non conforme' $l.Conforme $false
Verifie 'ancien titre : numero de PR lu' $l.Pr '1187'
Verifie 'ancien titre : description sans le numero' $l.Description 'Liste paginee, triee et filtrable dans le controleur genere'
Verifie 'type inconnu : non conforme' (LitTitre 'feature: x' '').Conforme $false
Verifie 'deux-points colles : non conforme' (LitTitre 'feat:sans espace' '').Conforme $false
Verifie 'majuscule au type : non conforme' (LitTitre 'Feat: x' '').Conforme $false

Write-Host "niveau de changement"
function Lignes([string[]]$titres) { return @($titres | ForEach-Object { LitTitre $_ '' }) }
Verifie 'docs seul : aucun' (NiveauDuChangement (Lignes @('docs: x', 'ci: y', 'test: z', 'chore: w', 'refactor: v')) 0) 'aucun'
Verifie 'fix : correctif' (NiveauDuChangement (Lignes @('docs: x', 'fix: y')) 0) 'correctif'
Verifie 'perf : correctif' (NiveauDuChangement (Lignes @('perf: y')) 0) 'correctif'
Verifie '0.x : feat donne un correctif' (NiveauDuChangement (Lignes @('feat: y')) 0) 'correctif'
Verifie '0.x : incompatible donne une mineure' (NiveauDuChangement (Lignes @('feat: y', 'fix(a)!: z')) 0) 'mineure'
Verifie '1.x : feat donne une mineure' (NiveauDuChangement (Lignes @('feat: y', 'fix: z')) 1) 'mineure'
Verifie '1.x : incompatible donne une majeure' (NiveauDuChangement (Lignes @('feat!: y')) 1) 'majeure'
Verifie 'titres sans type : ignores' (NiveauDuChangement (Lignes @('Un ancien titre (#1001)', 'Un autre (#1002)')) 0) 'aucun'

Write-Host "version suivante"
Verifie 'correctif' (VersionSuivante '0.1.1' 'correctif') '0.1.2'
Verifie 'mineure remet le correctif a 0' (VersionSuivante '0.1.1' 'mineure') '0.2.0'
Verifie 'majeure remet le reste a 0' (VersionSuivante '1.4.7' 'majeure') '2.0.0'
Verifie 'aucun : inchangee' (VersionSuivante '0.1.1' 'aucun') '0.1.1'
$refus = $false; try { VersionSuivante 'abc' 'correctif' | Out-Null } catch { $refus = $true }
Verifie 'version illisible : refusee' $refus $true

Write-Host "changelog"
$md = ChangelogMarkdown '0.2.0' (Lignes @('feat(make): ajoute x (#1001)', 'fix: corrige y (#1002)', 'docs: texte (#1003)', 'feat(liste)!: change la forme (#1004)', 'Ancien titre (#1005)'))
Verifie 'titre du changelog' ($md -split '\r?\n')[0] '# Ebony 0.2.0'
Verifie 'section des changements incompatibles' ($md -match '## Changements incompatibles') $true
Verifie 'le feat incompatible est dans les incompatibles et pas dans Nouveautes' (($md -split '## Nouveautes')[1] -match 'change la forme') $false
Verifie 'section Nouveautes avec la portee et le numero' ($md -match '- \*\*make\*\* : ajoute x \(#1001\)') $true
Verifie 'section Corrections' ($md -match '## Corrections') $true
Verifie 'docs absent du changelog' ($md -match 'texte') $false
Verifie 'ancien titre dans la section A classer' ($md -match '## A classer[\s\S]*Ancien titre \(#1005\)') $true

Write-Host ""
if ($nombre -lt 25) { Write-Host "ECHEC : seulement $nombre verifications (un test qui n'execute presque rien ne doit pas passer)"; exit 1 }
if ($echecs -gt 0) { Write-Host "PROCHAINE-VERSION : $echecs ECHEC(S) sur $nombre"; exit 1 }
Write-Host "PROCHAINE-VERSION : TOUT PASSE ($nombre verifications)"
exit 0