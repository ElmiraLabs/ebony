# Test de scripts\portee-verification.ps1 : quelles etapes de la verification un ensemble de fichiers modifies declenche-t-il ?
# Sans owl, quelques secondes. Un classement trop large coute du temps ; un classement trop etroit laisserait passer un defaut : ces cas figent les deux sens.
# Usage : .\tests\integration\portee.ps1      (code de sortie 0 si tout passe, 1 sinon). Ce fichier reste ASCII.

$racine = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $racine 'scripts\portee-verification.ps1')
$echecs = 0
$verifications = 0

function Verifie([string]$Titre, [bool]$Condition, [string]$Detail) {
    $script:verifications++
    if ($Condition) { Write-Host ("  [OK]     " + $Titre) }
    else { Write-Host ("  [ECHEC]  " + $Titre) -ForegroundColor Red; if ($Detail) { Write-Host ("           " + $Detail) }; $script:echecs++ }
}

# Les etapes allumees, en une ligne lisible.
function Allumees($Portee) { return (($Portee.Etapes.Keys | Where-Object { $Portee.Etapes[$_] }) -join ',') }

Write-Host "regles de classement"
$documentation = Get-PorteeVerification @('docs/guides/make.md', 'README.md', 'docs/guides/architecture.md', 'modules/burin/README.md', '.github/workflows/docs.yml')
Verifie "la documentation seule n'allume aucune etape et n'est pas complete" ((-not $documentation.Complet) -and ((Allumees $documentation) -eq '')) (Allumees $documentation)

$burin = Get-PorteeVerification @('modules/burin/execution/requetes/cEbRequete.owl', 'docs/guides/make.md')
$attenduBurin = 'Compilation,Unitaires,Projet,Make,Postgresql,Frontieres,Noms'   # dans l'ordre de $etapesDeVerification
Verifie "un fichier de Burin allume ses etapes (et la documentation n'y change rien)" ((-not $burin.Complet) -and ((Allumees $burin) -eq $attenduBurin)) (Allumees $burin)
Verifie "un fichier de Burin ne declenche ni l'archive, ni les installateurs, ni le groupe installe, ni le coeur seul" (-not ($burin.Etapes.Archive -or $burin.Etapes.Installateurs -or $burin.Etapes.Installe -or $burin.Etapes.CoeurSeul)) (Allumees $burin)

$manifeste = Get-PorteeVerification @('modules/burin/execution/modules/burin.json')
Verifie "un manifeste de module allume aussi le groupe base (l'aide le lit)" ($manifeste.Etapes.Base -and $manifeste.Etapes.Make -and -not $manifeste.Complet) (Allumees $manifeste)

$auth = Get-PorteeVerification @('modules/auth/outils/commandes/token/EbCommandeToken.owl')
Verifie "un fichier d'Auth allume Make, Projet et PostgreSQL (jetons) sans tout lancer" ($auth.Etapes.Make -and $auth.Etapes.Projet -and $auth.Etapes.Postgresql -and -not $auth.Etapes.Archive -and -not $auth.Complet) (Allumees $auth)

$figurant = Get-PorteeVerification @('modules/figurant/execution/figurant/cEbGenerateurFigurant.owl', 'modules/figurant/execution/modules/figurant.json')
Verifie "un fichier du module figurant allume la compilation, les tests, Make (ebony add) et les frontieres, sans PostgreSQL ni archive ni tout lancer" ($figurant.Etapes.Compilation -and $figurant.Etapes.Unitaires -and $figurant.Etapes.Make -and $figurant.Etapes.Frontieres -and -not $figurant.Etapes.Postgresql -and -not $figurant.Etapes.Archive -and -not $figurant.Etapes.Installe -and -not $figurant.Complet) (Allumees $figurant)

$poincon = Get-PorteeVerification @('modules/poincon/execution/poincon/EbPoincon.owl', 'modules/poincon/execution/modules/poincon.json')
Verifie "un fichier du module poincon allume la compilation, les tests, Make (le controleur) et les frontieres, sans archive ni tout lancer" ($poincon.Etapes.Compilation -and $poincon.Etapes.Unitaires -and $poincon.Etapes.Make -and $poincon.Etapes.Frontieres -and -not $poincon.Etapes.Archive -and -not $poincon.Etapes.Installe -and -not $poincon.Complet) (Allumees $poincon)
$coeur = Get-PorteeVerification @('src/commandes/EbPrincipal.owl')
Verifie "un fichier du coeur lance tout" ($coeur.Complet -and $coeur.Etapes.Archive -and $coeur.Etapes.Installateurs -and $coeur.Etapes.CoeurSeul) (Allumees $coeur)
$coeurModule = Get-PorteeVerification @('modules/core/execution/cycle/cEbApplication.owl')
Verifie "un fichier de modules/core lance tout" ($coeurModule.Complet) (Allumees $coeurModule)
$melange = Get-PorteeVerification @('modules/burin/execution/requetes/cEbRequete.owl', 'src/commandes/EbPrincipal.owl')
Verifie "un fichier de Burin avec un fichier du coeur : tout" ($melange.Complet) (Allumees $melange)

Verifie "un chemin inconnu lance tout, avec sa raison" ((Get-PorteeVerification @('quelquechose/inconnu.txt')).Complet -and ((Get-PorteeVerification @('quelquechose/inconnu.txt')).Raisons[0] -match 'inconnu.txt')) ''
Verifie "un nouveau module (inconnu des regles) lance tout" ((Get-PorteeVerification @('modules/autre/execution/x.owl')).Complet) ''
Verifie "bin, ebony.owl et projet.owl lancent tout" ((Get-PorteeVerification @('bin/ebony.cmd')).Complet -and (Get-PorteeVerification @('ebony.owl')).Complet -and (Get-PorteeVerification @('projet.owl')).Complet) ''
Verifie "verifier.ps1 et portee-verification.ps1 eux-memes lancent tout" ((Get-PorteeVerification @('scripts/verifier.ps1')).Complet -and (Get-PorteeVerification @('scripts/portee-verification.ps1')).Complet) ''
Verifie "aucun fichier modifie : tout" ((Get-PorteeVerification @()).Complet -and (Get-PorteeVerification $null).Complet) ''
Verifie "les chemins a barres inverses sont reconnus comme ceux a barres obliques" ((Allumees (Get-PorteeVerification @('modules\burin\execution\requetes\cEbRequete.owl'))) -eq $attenduBurin) ''

Verifie "un test d'integration n'allume que l'etape qu'il pilote (archive)" ((Allumees (Get-PorteeVerification @('tests/integration/archive.ps1'))) -eq 'Archive') ''
Verifie "un test d'integration n'allume que l'etape qu'il pilote (installateurs)" ((Allumees (Get-PorteeVerification @('tests/integration/installateur.sh'))) -eq 'Installateurs') ''
Verifie "le test du lanceur allume ses quatre groupes" ((Allumees (Get-PorteeVerification @('tests/integration/lanceur.ps1'))) -eq 'Base,Projet,Make,Installe') ''
Verifie "un test unitaire allume la compilation et les tests unitaires seulement" ((Allumees (Get-PorteeVerification @('tests/unitaires/systeme/test_EbJson.owl'))) -eq 'Compilation,Unitaires') ''
Verifie "test-rapide.ps1 allume tous les tests unitaires et le coeur seul" ((Allumees (Get-PorteeVerification @('scripts/test-rapide.ps1'))) -eq 'UnitairesTous,CoeurSeul') ''
Verifie "le test de portee n'allume rien (il tourne a chaque verification)" ((Allumees (Get-PorteeVerification @('tests/integration/portee.ps1'))) -eq '') ''

# Les fichiers modifies, lus dans un vrai depot git temporaire : une branche creee depuis main, un fichier modifie, un supprime, un nouveau suivi, un non suivi, un chemin accentue.
Write-Host "fichiers modifies (depot git temporaire)"
$dossierGit = Join-Path ([IO.Path]::GetTempPath()) ('ebony_portee_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $dossierGit | Out-Null
try {
    $null = & git -C $dossierGit init -q -b main
    $null = & git -C $dossierGit config user.email 'essai@example.invalid'
    $null = & git -C $dossierGit config user.name 'essai'
    $null = & git -C $dossierGit config commit.gpgsign false
    [IO.File]::WriteAllText((Join-Path $dossierGit 'a.txt'), 'a')
    [IO.File]::WriteAllText((Join-Path $dossierGit 'b.txt'), 'b')
    $null = & git -C $dossierGit add -A
    $null = & git -C $dossierGit commit -q -m base
    Verifie "sur main sans rien de modifie : un tableau vide (le script en deduit : tout)" ((@(Get-FichiersModifies $dossierGit)).Count -eq 0) ''
    $null = & git -C $dossierGit checkout -q -b travail
    [IO.File]::WriteAllText((Join-Path $dossierGit 'a.txt'), 'a2')
    Remove-Item (Join-Path $dossierGit 'b.txt')
    [IO.File]::WriteAllText((Join-Path $dossierGit 'c.txt'), 'c')
    $null = & git -C $dossierGit add c.txt
    $null = & git -C $dossierGit commit -q -m 'ajout de c'
    [IO.File]::WriteAllText((Join-Path $dossierGit 'd.txt'), 'd')
    $dossierAccent = Join-Path $dossierGit ('mod' + [char]0xE8 + 'le')
    New-Item -ItemType Directory -Path $dossierAccent | Out-Null
    [IO.File]::WriteAllText((Join-Path $dossierAccent 'x.txt'), 'x')
    $lus = @(Get-FichiersModifies $dossierGit)
    $attendus = @('a.txt', 'b.txt', 'c.txt', 'd.txt', ('mod' + [char]0xE8 + 'le/x.txt'))
    Verifie "modifie, supprime, valide et non suivi sont tous la, chemin accentue compris" (($lus -join '|') -eq (($attendus | Sort-Object) -join '|')) ($lus -join '|')
}
finally { Remove-Item -LiteralPath $dossierGit -Recurse -Force -ErrorAction SilentlyContinue }
Verifie "hors d'un depot git : rien (null), donc verification complete" ($null -eq (Get-FichiersModifies ([IO.Path]::GetTempPath()))) ''

Write-Host ""
if ($verifications -lt 20) { Write-Host ("ECHEC : seulement " + $verifications + " verifications (un test qui n'execute rien ne doit pas passer)") -ForegroundColor Red; exit 1 }
if ($echecs -eq 0) { Write-Host ("PORTEE : TOUT PASSE (" + $verifications + " verifications)") -ForegroundColor Green; exit 0 }
Write-Host ("PORTEE : " + $echecs + " ECHEC(S)") -ForegroundColor Red
exit 1
