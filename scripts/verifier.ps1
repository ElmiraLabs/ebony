# Verifie tout le depot : compilation, tests unitaires, tests d'integration du lanceur et de l'ajout au PATH.
# Les tests unitaires sont ceux de scripts\test-rapide.ps1 (chaque suite isolee avec ses seules dependances, plus un controle statique des globales de fichiers de test) :
# memes totaux qu'"owl test" (50 suites, 1937 assertions, 474 scenarios, au moment de la mesure) en 1 minute au lieu de 23 a 42 (owl test recompile tout pour chaque suite).
# Les trois premiers sont necessaires : owl --check et les tests unitaires acceptent des erreurs que le lancement reel refuse
# (ex. une methode qui implemente une interface avec PROCEDURE PUBLIC). Seul le test d'integration les voit.
# Windows PowerShell 5.1 ou plus, ou PowerShell 7 sous Linux.   Usage :   .\scripts\verifier.ps1      (code de sortie 0 si tout passe, 1 sinon)
# PORTEE : par defaut, seules les etapes que les fichiers MODIFIES de la branche peuvent atteindre sont lancees (scripts\portee-verification.ps1 : table de regles, un fichier inconnu des regles lance tout) ;
# les autres sont dites IGNOREES, avec la raison. -Complet lance tout : obligatoire avant une release, apres une nouvelle version d'OWL, et quand on change verifier.ps1 ou la table des regles.
#   .\scripts\verifier.ps1 -Complet
#   .\scripts\verifier.ps1 -FichiersSimules docs/guides/make.md,modules/burin/execution/requetes/cEbRequete.owl     (simulation : la portee d'une liste donnee au lieu de celle de git)
param([switch]$Complet, [string[]]$FichiersSimules = @())
# Sous Linux (PowerShell 7, owl, bash et curl dans le PATH ; mettre DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 s'il manque libicu) les etapes propres a Windows sont ignorees EXPLICITEMENT (groupe installe, registre, archive, PostgreSQL)
# et le parcours de tests\integration\linux.sh les remplace : voir la section Linux du README.
# Ce fichier reste ASCII.

$racine = Split-Path $PSScriptRoot -Parent
Set-Location $racine
$echecs = 0
$estWindows = [IO.Path]::DirectorySeparatorChar -eq '\'
# Le PowerShell qui execute ce script (powershell.exe sous Windows, pwsh sous Linux) : jamais le mot powershell en dur.
$programmePowerShell = (Get-Process -Id $PID).Path

# La portee : quelles etapes les fichiers modifies rendent necessaires (voir scripts\portee-verification.ps1). -Complet, ou une liste de fichiers modifies introuvable : tout.
. (Join-Path $PSScriptRoot 'portee-verification.ps1')
$fichiersModifies = $null
if (-not $Complet) {
    if ($FichiersSimules.Count -gt 0) { $fichiersModifies = @($FichiersSimules | ForEach-Object { $_ -split ',' } | Where-Object { $_ }) }
    else { $fichiersModifies = Get-FichiersModifies $racine }
}
$portee = Get-PorteeVerification $fichiersModifies
$raisonsPortee = @($portee.Raisons)
if ($Complet) { $raisonsPortee = @("option -Complet") }
function Concerne([string]$NomEtape) { return [bool]$portee.Etapes[$NomEtape] }
Write-Host ""
if ($portee.Complet) {
    Write-Host ("PORTEE : verification COMPLETE (" + ($raisonsPortee | Select-Object -First 1) + ")") -ForegroundColor Cyan
}
else {
    Write-Host ("PORTEE : verification CIBLEE, " + $fichiersModifies.Count + " fichier(s) modifie(s) par rapport a main ; etapes concernees : " + $(if (($portee.Etapes.Keys | Where-Object { $portee.Etapes[$_] }).Count -eq 0) { 'aucune (controles sans owl seulement)' } else { ($portee.Etapes.Keys | Where-Object { $portee.Etapes[$_] }) -join ', ' })) -ForegroundColor Cyan
    foreach ($raisonPortee in ($raisonsPortee | Select-Object -First 12)) { Write-Host ("   " + $raisonPortee) }
    if ($raisonsPortee.Count -gt 12) { Write-Host ("   ... et " + ($raisonsPortee.Count - 12) + " autre(s)") }
}
Write-Host ""

# Une etape propre a Windows, sautee sous Linux : dite a l'ecran, jamais passee sous silence.
function EtapeIgnoree([string]$Nom, [string]$Raison) {
    Write-Host ("== " + $Nom)
    Write-Host ("   IGNORE : " + $Raison) -ForegroundColor Yellow
}

# Les durees : chaque etape dit combien de secondes elle a pris, et le recapitulatif final les classe. Sans cela, on ne sait pas laquelle fait grossir la verification (20 minutes en novembre 2026, 36 quelques jours plus tard).
# Attention : les etapes en parallele se disputent les coeurs de la machine ; leur duree est une duree d'horloge, pas un cout isole.
$debutTotal = Get-Date
$durees = @()
function NoteDuree([string]$Nom, [double]$Secondes) {
    $script:durees += [pscustomobject]@{ Nom = $Nom; Secondes = [int][math]::Round($Secondes) }
}

function Etape([string]$Nom, [scriptblock]$Commande) {
    Write-Host ("== " + $Nom)
    $chrono = [Diagnostics.Stopwatch]::StartNew()
    $sortie = & $Commande 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    $chrono.Stop()
    NoteDuree $Nom $chrono.Elapsed.TotalSeconds
    $duree = [int][math]::Round($chrono.Elapsed.TotalSeconds)
    if ($code -ne 0) {
        $script:echecs++
        Write-Host ("   ECHEC (" + $duree + " s)") -ForegroundColor Red
        # Les lignes en echec d'abord (avec la suivante, qui porte le detail), sinon le debut de la sortie : une etape qui a beaucoup de lignes [OK] cachait sinon la ligne qui echoue.
        $lignesEchecEtape = @()
        for ($i = 0; $i -lt $sortie.Count; $i++) {
            if ($sortie[$i] -match 'ECHEC|FAIL') { $lignesEchecEtape += $sortie[$i]; if ($i + 1 -lt $sortie.Count) { $lignesEchecEtape += $sortie[$i + 1] } }
        }
        if ($lignesEchecEtape.Count -eq 0) { $lignesEchecEtape = @($sortie) }
        $lignesEchecEtape | Select-Object -First 12 | ForEach-Object { Write-Host ("   " + $_) }
    }
    else { Write-Host ("   OK (" + $duree + " s)") -ForegroundColor Green }
}

# Encapsulation. Le controle de visibilite d'owl ne voit pas tous les acces (variable de boucle POUR TOUT, resultat d'un appel,
# code des Collections et du bloc de projet.owl). On le complete
# par la convention de nommage : un champ a un prefixe de type (nStatut, sMessage, oSysteme, tabItems), une methode est en PascalCase
# (Statut()). Donc "quelquechose.nStatut" sans parenthese est un acces direct a un champ. Les valeurs d'enumeration (eEbStatut.erreur)
# sont en minuscules apres le point et ne sont pas concernees. ATTENTION : -match est insensible a la casse en PowerShell,
# il faut -cmatch, sinon [A-Z] accepte aussi les minuscules.
# Un membre GLOBAL d'une classe se lit par le NOM DE LA CLASSE (cEbCodeSortie.nCode : prefixe c, convention d'ebony) : ce n'est pas l'acces direct a un champ d'une instance, on ne le signale pas.
$motifChamp = '(?:(?<![.\w"])(?!c[A-Z])[A-Za-z_]\w*|[\)\]])\.(?:tab|[snbroe])[A-Z]\w*\b(?!\()'
$raisonNonConcerne = "non concerne par les fichiers modifies (scripts\portee-verification.ps1 ; verifier.ps1 -Complet lance tout)"
# Le test de la table des regles de portee : sans owl, quelques secondes, a chaque verification.
Etape "portee : la table des regles classe les fichiers comme prevu (tests\integration\portee.ps1)" { & $programmePowerShell -NoProfile -File (Join-Path $racine 'tests\integration\portee.ps1') }
if (Concerne 'Compilation') {
Etape "encapsulation : aucun acces direct a un champ" {
    $fichiers = @(Get-ChildItem (Join-Path $racine 'src'), (Join-Path $racine 'tests') -Recurse -Filter '*.owl')
    $fichiers += @(Get-ChildItem (Join-Path $racine 'modules') -Recurse -Filter '*.owl' | Where-Object { $_.FullName.Replace('\', '/') -like '*/outils/*' })
    $fichiers += Get-Item (Join-Path $racine 'ebony.owl'), (Join-Path $racine 'projet.owl')
    $trouves = foreach ($f in $fichiers) {
        $n = 0
        foreach ($ligne in (Get-Content $f.FullName -Encoding UTF8)) {
            $n++
            $code = ($ligne -replace '//.*$', '') -replace '"[^"]*"', '""'
            if ($code -cmatch $motifChamp) { "{0}:{1}  {2}" -f $f.FullName.Replace($racine + '\', ''), $n, $ligne.Trim() }
        }
    }
    if ($trouves) { $trouves | ForEach-Object { Write-Output $_ }; $global:LASTEXITCODE = 1 } else { $global:LASTEXITCODE = 0 }
}

Etape "owl --check projet.owl" { owl --check projet.owl }
}
else {
    EtapeIgnoree "encapsulation : aucun acces direct a un champ" $raisonNonConcerne
    EtapeIgnoree "owl --check projet.owl" $raisonNonConcerne
}
# Points d'entree reduits par commande (.commandes, ignore par git) : le lanceur les utilise s'ils existent, donc les tests d'integration appellent ebony en 1 a 7 s au lieu de 25.
# Regeneres A CHAQUE verification qui les utilise : un dossier perime fausserait le test. Regenere aussi par scripts\construit-archive.ps1 pour l'archive.
if ((Concerne 'Compilation') -or (Concerne 'Base') -or (Concerne 'Projet') -or (Concerne 'Make') -or (Concerne 'Installe')) {
Etape "points d'entree reduits par commande (scripts\construit-entrees.ps1)" { & $programmePowerShell -NoProfile -File (Join-Path $racine 'scripts\construit-entrees.ps1') }
}
else { EtapeIgnoree "points d'entree reduits par commande (scripts\construit-entrees.ps1)" $raisonNonConcerne }
# La liste des commandes vient de l'aiguillage (EbAiguillage.owl) ; celle de bin\ebony.cmd est la seule ecrite a la main : elle doit etre d'accord (sinon une commande retomberait sans bruit sur le repli a 25 s).
Etape "commandes : aiguillage, lanceur et points d'entree d'accord (scripts\controle-commandes.ps1)" { & $programmePowerShell -NoProfile -File (Join-Path $racine 'scripts\controle-commandes.ps1') }
# Versions : le numero ecrit en dur dans le README, la page d'accueil et les guides est celui de VERSION. Sans owl.
Etape "versions : les textes publics disent la version de modules\core\execution\VERSION (scripts\controle-versions.ps1)" { & $programmePowerShell -NoProfile -File (Join-Path $racine 'scripts\controle-versions.ps1') }
# Frontieres du coeur et des modules : le coeur n'appelle ni le SQL (hors cEbApplication) ni auth, la bibliotheque ne depend pas de src\. Sans owl ; le test injecte de vraies fuites dans une copie et verifie qu'elles sont vues.
if (Concerne 'Frontieres') {
Etape "frontieres du coeur et des modules (scripts\controle-frontieres.ps1 et tests\integration\frontieres.ps1)" {
    & $programmePowerShell -NoProfile -File (Join-Path $racine 'scripts\controle-frontieres.ps1')
    if ($LASTEXITCODE -eq 0) { & $programmePowerShell -NoProfile -File (Join-Path $racine 'tests\integration\frontieres.ps1') }
}
}
else { EtapeIgnoree "frontieres du coeur et des modules (scripts\controle-frontieres.ps1 et tests\integration\frontieres.ps1)" $raisonNonConcerne }# Les etapes longues (tests unitaires rapides, tests d'integration du lanceur) sont faites de lancements d'owl (les integrations recompilent tout le projet, 20 a 25 s chacun) et ne dependent pas l'une de l'autre :
# on les lance EN PARALLELE (tests unitaires + les quatre groupes du lanceur + l'archive). Mesure avec OWL 1.6.0 : trois compilations simultanees coutent ~1,6 fois une seule, pas trois fois (PC a 2 coeurs, 4 threads).
# Chaque tache ecrit dans un fichier ; on affiche les resultats a la fin, dans l'ordre. Les etapes qui touchent le registre (chemin-path) ou sont breves restent sequentielles APRES :
# chemin-path et le groupe 'installe' utilisent la meme variable de PATH de test et ne doivent jamais tourner ensemble.
function EtapesEnParallele([object[]]$Taches) {
    $dossierSortie = Join-Path ([IO.Path]::GetTempPath()) ('ebony_verifier_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $dossierSortie | Out-Null
    $lancees = @()
    foreach ($tache in $Taches) {
        $sortieFichier = Join-Path $dossierSortie ($lancees.Count.ToString() + '.out')
        $erreurFichier = Join-Path $dossierSortie ($lancees.Count.ToString() + '.err')
        $debut = Get-Date
        $parametresProcessus = @{ FilePath = $tache.Programme; ArgumentList = $tache.Arguments; WorkingDirectory = $racine; PassThru = $true; RedirectStandardOutput = $sortieFichier; RedirectStandardError = $erreurFichier }
        if ($estWindows) { $parametresProcessus.WindowStyle = 'Hidden' }
        $processus = Start-Process @parametresProcessus
        $null = $processus.Handle   # garde le handle : sans cela, ExitCode peut rester vide apres la fin du processus
        $lancees += [pscustomobject]@{ Nom = $tache.Nom; Processus = $processus; Sortie = $sortieFichier; Erreur = $erreurFichier; Debut = $debut }
    }
    foreach ($tache in $lancees) { $tache.Processus.WaitForExit() }
    foreach ($tache in $lancees) {
        Write-Host ("== " + $tache.Nom)
        $texte = @(Get-Content -LiteralPath $tache.Sortie -Encoding UTF8 -ErrorAction SilentlyContinue) + @(Get-Content -LiteralPath $tache.Erreur -Encoding UTF8 -ErrorAction SilentlyContinue)
        # Duree d'horloge de la tache, du lancement a la fin du processus (0 si l'heure de fin est illisible).
        $secondesTache = 0
        try { $secondesTache = ($tache.Processus.ExitTime - $tache.Debut).TotalSeconds } catch { $secondesTache = 0 }
        NoteDuree ($tache.Nom + ' [parallele]') $secondesTache
        $dureeTache = [int][math]::Round($secondesTache)
        if ($tache.Processus.ExitCode -ne 0) {
            $script:echecs++
            Write-Host ("   ECHEC (" + $dureeTache + " s)") -ForegroundColor Red
            # Les lignes en echec d'abord (avec leur detail), sinon le debut de la sortie.
            $lignesEchec = @()
            for ($i = 0; $i -lt $texte.Count; $i++) {
                if ("$($texte[$i])" -match 'ECHEC|FAIL|Erreur') { $lignesEchec += "$($texte[$i])"; if ($i + 1 -lt $texte.Count) { $lignesEchec += "$($texte[$i + 1])" } }
            }
            if ($lignesEchec.Count -eq 0) { $lignesEchec = @($texte | ForEach-Object { "$_" }) }
            $lignesEchec | Select-Object -First 24 | ForEach-Object { Write-Host ("   " + $_) }
        }
        else { Write-Host ("   OK (" + $dureeTache + " s)") -ForegroundColor Green }
    }
    Remove-Item -LiteralPath $dossierSortie -Recurse -Force -ErrorAction SilentlyContinue
}
$lanceurScript = Join-Path $racine 'tests\integration\lanceur.ps1'
# Les taches, des PLUS LONGUES aux plus courtes (durees mesurees seules ou en charge : make, installateurs, installe, archive, PostgreSQL, projet, coeur seul, base, tests unitaires) : la plus longue demarre la premiere,
# au lieu de finir seule apres les autres. Mesure (2 coeurs, 4 threads) : le debit total plafonne a environ deux compilations d'owl en parallele, lancer plus de taches ne va pas plus vite mais ne coute pas plus non plus.
# Une tache que la portee ne demande pas n'est pas lancee et le dit (EtapeIgnoree) ; sans portee ciblee, toutes tournent comme avant.
$tachesParalleles = @()
$tachesIgnorees = @()
function AjouteTache([string]$Etape, [hashtable]$Tache) {
    if (Concerne $Etape) { $script:tachesParalleles += $Tache } else { $script:tachesIgnorees += $Tache.Nom }
}
# Les suites unitaires : seulement celles que les fichiers modifies concernent (test-rapide.ps1 -ListeFichiers), sauf si la portee est complete ou si test-rapide.ps1 lui-meme a change.
$argumentsUnitaires = @('-NoProfile', '-File', (Join-Path $racine 'scripts\test-rapide.ps1'))
if (-not $portee.Complet -and -not (Concerne 'UnitairesTous') -and $fichiersModifies.Count -gt 0) {
    $listeFichiersModifies = Join-Path ([IO.Path]::GetTempPath()) ('ebony_modifies_' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.txt')
    [IO.File]::WriteAllText($listeFichiersModifies, (($fichiersModifies -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))
    $argumentsUnitaires += @('-ListeFichiers', $listeFichiersModifies)
}
$nomUnitaires = 'tests unitaires (scripts\test-rapide.ps1 : suites isolees + controle des globales de test + controle statique du coeur seul)'
if ($estWindows) {
    AjouteTache 'Make' @{ Nom = "test d'integration du lanceur : groupe make"; Programme = $programmePowerShell; Arguments = @('-NoProfile', '-File', $lanceurScript, '-Groupe', 'make') }
    AjouteTache 'Make' @{ Nom = "test d'integration du lanceur : groupe make2 (suite de make : projets independants)"; Programme = $programmePowerShell; Arguments = @('-NoProfile', '-File', $lanceurScript, '-Groupe', 'make2') }
    # Les installateurs (install\install.ps1 sous Windows ; install\install.sh rejoue sous WSL quand WSL et un owl Linux sont la, sinon IGNORE dit dans la sortie) contre l'archive du commit HEAD (noms fixes). PATH de test propre : EBONY_TEST_PATH_INSTALLATEUR.
    AjouteTache 'Installateurs' @{ Nom = "installateurs (install.ps1, install.sh) : une ligne, somme, reinstallation, HTTP, refus"; Programme = $programmePowerShell; Arguments = @('-NoProfile', '-File', (Join-Path $racine 'tests\integration\installateur.ps1')) }
    AjouteTache 'Installe' @{ Nom = "test d'integration du lanceur : groupe installe"; Programme = $programmePowerShell; Arguments = @('-NoProfile', '-File', $lanceurScript, '-Groupe', 'installe') }
    # L'archive de distribution est faite a partir du commit HEAD (git archive), PAS du dossier de travail : commiter avant de lancer cette etape pour qu'elle voie ce qu'on veut livrer.
    # Elle utilise sa propre variable de PATH de test (EBONY_TEST_PATH_ARCHIVE), donc elle peut tourner en meme temps que le groupe 'installe'.
    AjouteTache 'Archive' @{ Nom = "archive de distribution : somme, installation sans git, reinstallation, ebony new, desinstallation"; Programme = $programmePowerShell; Arguments = @('-NoProfile', '-File', (Join-Path $racine 'tests\integration\archive.ps1')) }
    # PostgreSQL REEL (Docker) : migrate, depot SQL genere, service, niveaux TLS. Deux conteneurs jetables, ports libres ; IGNORE (code 0) si Docker ne repond pas ou si l'image postgres:16 n'est pas deja telechargee.
    AjouteTache 'Postgresql' @{ Nom = "PostgreSQL reel (Docker, tests\integration\postgresql.ps1) : migrate, depot SQL, service, TLS"; Programme = $programmePowerShell; Arguments = @('-NoProfile', '-File', (Join-Path $racine 'tests\integration\postgresql.ps1')) }
    AjouteTache 'Projet' @{ Nom = "test d'integration du lanceur : groupe projet"; Programme = $programmePowerShell; Arguments = @('-NoProfile', '-File', $lanceurScript, '-Groupe', 'projet') }
    # Le coeur SEUL, par compilation : une copie du depot sans modules ni tests de modules compile, passe ses tests et genere un projet slim qui compile. Windows seulement (robocopy, ebony.cmd).
    # Sa version STATIQUE (aucun fichier du coeur ne cite un nom d'un module) est dans test-rapide.ps1 et tourne a chaque verification ; cette preuve par compilation reste pour la verification complete.
    AjouteTache 'CoeurSeul' @{ Nom = "coeur seul : sans modules, il compile, passe ses tests et genere un projet slim (scripts\controle-coeur-seul.ps1)"; Programme = $programmePowerShell; Arguments = @('-NoProfile', '-File', (Join-Path $racine 'scripts\controle-coeur-seul.ps1')) }
    AjouteTache 'Base' @{ Nom = "test d'integration du lanceur : groupe base"; Programme = $programmePowerShell; Arguments = @('-NoProfile', '-File', $lanceurScript, '-Groupe', 'base') }
    AjouteTache 'Unitaires' @{ Nom = $nomUnitaires; Programme = $programmePowerShell; Arguments = $argumentsUnitaires }
}
else {
    # Sous Linux : les groupes base, projet et make du lanceur (bin/ebony, un vrai owl, un vrai owl serve), puis le parcours de linux.sh, en parallele des tests unitaires.
    # Le groupe installe (install, uninstall, PATH) est propre a Windows.
    AjouteTache 'Make' @{ Nom = "test d'integration du lanceur : groupe make"; Programme = $programmePowerShell; Arguments = @('-NoProfile', '-File', $lanceurScript, '-Groupe', 'make') }
    AjouteTache 'Make' @{ Nom = "test d'integration du lanceur : groupe make2 (suite de make : projets independants)"; Programme = $programmePowerShell; Arguments = @('-NoProfile', '-File', $lanceurScript, '-Groupe', 'make2') }
    AjouteTache 'Projet' @{ Nom = "test d'integration du lanceur : groupe projet"; Programme = $programmePowerShell; Arguments = @('-NoProfile', '-File', $lanceurScript, '-Groupe', 'projet') }
    AjouteTache 'Base' @{ Nom = "test d'integration du lanceur : groupe base"; Programme = $programmePowerShell; Arguments = @('-NoProfile', '-File', $lanceurScript, '-Groupe', 'base') }
    if ((Concerne 'Make') -or (Concerne 'Projet') -or (Concerne 'Base')) {
        $tachesParalleles += @{ Nom = "parcours sous Linux avec bin/ebony (tests/integration/linux.sh)"; Programme = 'bash'; Arguments = @((Join-Path $racine 'tests/integration/linux.sh')) }
    }
    else { $tachesIgnorees += "parcours sous Linux avec bin/ebony (tests/integration/linux.sh)" }
    AjouteTache 'Unitaires' @{ Nom = $nomUnitaires; Programme = $programmePowerShell; Arguments = $argumentsUnitaires }
}
if ($tachesParalleles.Count -gt 0) { EtapesEnParallele $tachesParalleles }
if ($listeFichiersModifies) { Remove-Item -LiteralPath $listeFichiersModifies -Force -ErrorAction SilentlyContinue }
if ($estWindows -and (Concerne 'Installe')) {
    # L'ajout d'ebony au PATH, contre le vrai registre mais sur une variable de TEST (EBONY_TEST_PATH) : le vrai PATH n'est jamais modifie, le test le verifie.
    Etape "ajout au PATH (bin\ebony-path.ps1), sur une variable de test" { & $programmePowerShell -NoProfile -File (Join-Path $racine 'tests\integration\chemin-path.ps1') }
    # La suppression des versions installees (ebony uninstall) est destructrice : ce test verifie surtout ce qu'elle ne doit PAS supprimer (dossier etranger, jonction, mauvais nom, racine de disque).
    Etape "suppression (bin\ebony-supprime.ps1), bornee aux dossiers d'ebony" { & $programmePowerShell -NoProfile -File (Join-Path $racine 'tests\integration\suppression.ps1') }
}
elseif ($estWindows) {
    EtapeIgnoree "ajout au PATH (bin\ebony-path.ps1), sur une variable de test" $raisonNonConcerne
    EtapeIgnoree "suppression (bin\ebony-supprime.ps1), bornee aux dossiers d'ebony" $raisonNonConcerne
}
else {
    $raisonWindows = "propre a Windows (lanceur .cmd, registre, PowerShell 5.1) ; couvert sous Linux par tests/integration/linux.sh"
    EtapeIgnoree "test d'integration du lanceur : groupe installe (install, uninstall, PATH)" $raisonWindows
    EtapeIgnoree "PostgreSQL reel (Docker, tests\integration\postgresql.ps1)" "pas encore portable sous Linux (voir la section Linux du README)"
    EtapeIgnoree "archive de distribution (tests\integration\archive.ps1)" $raisonWindows
    EtapeIgnoree "installateurs (tests\integration\installateur.ps1)" "l'archive est construite sous Windows (construit-archive.ps1) ; install.sh se rejoue avec : sh tests/integration/installateur.sh <dossier de l'archive>"
    EtapeIgnoree "ajout au PATH et suppression (bin\ebony-path.ps1, bin\ebony-supprime.ps1)" $raisonWindows
}
# Du nom libre au projet qui compile (dossier et identifiant calcules par nos fonctions OWL, puis vrai dossier et vrai projet compiles par owl) : 6 s.
# Le mode -Complet (2 minutes, ~1 000 noms) est a lancer apres chaque mise a jour d'owl : .\tests\integration\noms-projet.ps1 -Complet

if (Concerne 'Noms') {
Etape "noms de projet : du nom libre au projet compile, contre le vrai owl" { & $programmePowerShell -NoProfile -File (Join-Path $racine 'tests\integration\noms-projet.ps1') }
}
else { EtapeIgnoree "noms de projet : du nom libre au projet compile, contre le vrai owl" $raisonNonConcerne }
Write-Host ""
Write-Host ("Durees (secondes), de la plus longue a la plus courte ; total d'horloge " + [int]((Get-Date) - $debutTotal).TotalSeconds + " s :")
$durees | Sort-Object Secondes -Descending | ForEach-Object { Write-Host ("  {0,5} s  {1}" -f $_.Secondes, $_.Nom) }
Write-Host ""
if (-not $portee.Complet) { Write-Host "(verification CIBLEE : les etapes IGNOREES plus haut n'ont PAS ete lancees ; .\scripts\verifier.ps1 -Complet avant une release)" -ForegroundColor Yellow }
if ($echecs -eq 0) { Write-Host $(if ($portee.Complet) { "TOUT PASSE" } else { "TOUT PASSE (portee ciblee)" }) -ForegroundColor Green; exit 0 }
else { Write-Host ("$echecs ETAPE(S) EN ECHEC") -ForegroundColor Red; exit 1 }
