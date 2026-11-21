# Test de scripts\controle-frontieres.ps1 : le controle VOIT les fuites. Sur des copies de modules\ et src\ faites dans le dossier temporaire du systeme (jamais sous le depot : les .owl copies
# y seraient charges avec les notres), on injecte une fuite par regle et l'on verifie que chacune est nommee, qu'un nom cite dans un commentaire ou une chaine de la bibliotheque ne declenche rien,
# et qu'une copie propre passe. Sans owl : quelques secondes. Usage : .\tests\integration\frontieres.ps1     (code de sortie 0 si tout passe, 1 sinon). Ce fichier reste ASCII.

$depot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$controle = Join-Path $depot 'scripts\controle-frontieres.ps1'
$utf8 = New-Object Text.UTF8Encoding($false)
$echecs = 0
$verifications = 0
# Le PowerShell qui execute ce script (powershell.exe sous Windows, pwsh sous Linux) : jamais « powershell » en dur.
$programmePowerShell = (Get-Process -Id $PID).Path
function Verifie([string]$Titre, [bool]$Condition, [string]$Detail) {
    $script:verifications++
    if ($Condition) { Write-Host ("  [OK]     " + $Titre) -ForegroundColor Green }
    else { Write-Host ("  [ECHEC]  " + $Titre) -ForegroundColor Red; if ($Detail -ne '') { Write-Host ("           " + $Detail) }; $script:echecs++ }
}

$zone = Join-Path ([IO.Path]::GetTempPath()) ('ebony_frontieres_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force $zone | Out-Null

# Une copie neuve de modules\ et src\ ; on y ajoute AJOUT a la fin du fichier donne (chemin relatif au depot), puis on lance le controle dessus.
function Essai([string]$Nom, [string]$Fichier, [string]$Ajout) {
    $copie = Join-Path $zone $Nom
    New-Item -ItemType Directory -Force $copie | Out-Null
    Copy-Item -LiteralPath (Join-Path $depot 'modules') -Destination (Join-Path $copie 'modules') -Recurse
    Copy-Item -LiteralPath (Join-Path $depot 'src') -Destination (Join-Path $copie 'src') -Recurse
    if ($Fichier -ne '') {
        $chemin = Join-Path $copie $Fichier.Replace('/', '\')
        [IO.File]::AppendAllText($chemin, ("`r`n" + $Ajout + "`r`n"), $utf8)
    }
    $sortie = (& $programmePowerShell -NoProfile -File $controle -Racine $copie 2>&1 | ForEach-Object { "$_" }) -join "`n"
    return @{ Code = $LASTEXITCODE; Sortie = $sortie }
}

try {
    Write-Host "controle des frontieres : le controle voit les fuites"
    $r = Essai 'propre' '' ''
    Verifie "une copie propre passe (code 0)" ($r.Code -eq 0) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'texte' 'modules/core/execution/http/EbErreurHttp.owl' ('// cEbBaseApplication, EbAutorisation et EbJointChemin sont ici des mots de commentaire' + "`r`n" + 'sEssaiTexte est une chaine = "cEbJetons EbJointChemin cEbBaseApplication"')
    Verifie "un nom cite dans un commentaire ou une chaine de la bibliotheque ne declenche rien" ($r.Code -eq 0) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r1' 'modules/core/execution/http/EbErreurHttp.owl' 'sEssaiR1 est une chaine = EbJointChemin("a", "b")'
    Verifie "R1 : la bibliotheque d'un module qui appelle un nom de src\ est refuse et nomme" (($r.Code -eq 1) -and ($r.Sortie -match 'R1 modules/core/execution/http/EbErreurHttp\.owl : reference EbJointChemin')) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r2' 'modules/core/execution/journal/cEbJournal.owl' 'oEssaiR2 est un cEbBaseApplication'
    Verifie "R2 : un fichier du coeur qui touche donnees est refuse et nomme" (($r.Code -eq 1) -and ($r.Sortie -match 'R2 modules/core/execution/journal/cEbJournal\.owl : reference cEbBaseApplication')) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r2app' 'modules/core/execution/cycle/cEbApplication.owl' 'oEssaiR2App est un cEbBaseApplication'
    Verifie "R2 : cEbApplication non plus ne connait pas la base (elle ne connait que le contrat iEbComposant)" (($r.Code -eq 1) -and ($r.Sortie -match 'R2 modules/core/execution/cycle/cEbApplication\.owl : reference cEbBaseApplication')) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r3' 'modules/core/execution/http/EbErreurHttp.owl' 'sEssaiR3 est une chaine = EbIdentiteDuJeton("x")'
    Verifie "R3 : un fichier du coeur qui appelle le module auth est refuse et nomme" (($r.Code -eq 1) -and ($r.Sortie -match 'R3 modules/core/execution/http/EbErreurHttp\.owl : reference EbIdentiteDuJeton')) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r4' 'modules/core/outils/commandes/EbCommandeVersion.owl' '// cEbJetons'
    Verifie "R4 : un fichier de src\ qui cite le module auth hors de modules\auth\outils\ est refuse et nomme" (($r.Code -eq 1) -and ($r.Sortie -match 'R4 modules/core/outils/commandes/EbCommandeVersion\.owl : cite cEbJetons')) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r5' 'modules/core/outils/commandes/EbCommandeVersion.owl' 'sEssaiR5 est une chaine = EbExecuteToken()'
    Verifie "R5 : un fichier d'outillage autre que le repartiteur qui appelle la commande du module est refuse et nomme" (($r.Code -eq 1) -and ($r.Sortie -match 'R5 modules/core/outils/commandes/EbCommandeVersion\.owl : reference EbExecuteToken')) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r5texte' 'modules/core/outils/commandes/EbCommandeVersion.owl' '// EbExecuteToken est cite en commentaire seulement'
    Verifie "R5 : un nom de la commande cite en commentaire ne declenche rien" ($r.Code -eq 0) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r6' 'modules/core/outils/commandes/EbCommandeVersion.owl' 'sEssaiR6 est une chaine = EbIndiceTls("x")'
    Verifie "R6 : un fichier du coeur qui appelle l'outillage de la base (modules\burin\outils\) est refuse et nomme" (($r.Code -eq 1) -and ($r.Sortie -match 'R6 modules/core/outils/commandes/EbCommandeVersion\.owl : reference EbIndiceTls')) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r6make' 'modules/core/outils/commandes/EbCommandeVersion.owl' 'sEssaiR6Make est une chaine = EbTypesChamp()'
    Verifie "R6 : un fichier du coeur qui appelle la commande make (modules\burin\outils\commandes\make\) est refuse et nomme" (($r.Code -eq 1) -and ($r.Sortie -match 'R6 modules/core/outils/commandes/EbCommandeVersion\.owl : reference EbTypesChamp')) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r6texte' 'modules/core/outils/commandes/EbCommandeVersion.owl' '// EbIndiceTls et EbExecuteMigrate sont cites en commentaire seulement'
    Verifie "R6 : un nom de l'outillage de la base cite en commentaire ne declenche rien" ($r.Code -eq 0) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r6aiguillage' 'src/commandes/EbAiguillage.owl' 'sEssaiR6Aiguillage est une chaine = EbIndiceTls("x")'
    Verifie "R6 : le repartiteur de commandes peut appeler l'outillage de la base (c'est son travail)" ($r.Code -eq 0) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r6auth' 'modules/auth/outils/commandes/token/EbCommandeToken.owl' 'sEssaiR6Auth est une chaine = EbIndiceTls("x")'
    Verifie "R6 : modules\auth\outils\ peut utiliser l'outillage de la base (auth depend de la base, dans ce sens seulement)" ($r.Code -eq 0) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r4permis' 'modules/auth/outils/commandes/token/EbCommandeToken.owl' '// cEbJetons EbAutorisation'
    Verifie "R4 : modules\auth\outils\ peut citer le module auth (c'est sa commande)" ($r.Code -eq 0) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r2requetes' 'modules/core/execution/http/EbErreurHttp.owl' 'oEssaiRequetes est un cEbSql'
    Verifie "R2 : un fichier du coeur qui touche au constructeur de requetes de burin (requetes\) est refuse et nomme" (($r.Code -eq 1) -and ($r.Sortie -match 'R2 modules/core/execution/http/EbErreurHttp\.owl : reference cEbSql')) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r2permis' 'modules/auth/execution/auth/EbAutorisation.owl' 'oEssaiPermis est un cEbBaseApplication'
    Verifie "R2 : le module auth peut dependre de donnees\ (dependance declaree)" ($r.Code -eq 0) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r2figurant' 'modules/figurant/execution/figurant/cEbGenerateurFigurant.owl' 'oEssaiFigurant est un iEbGenerateur'
    Verifie "R2 : le generateur du module figurant peut citer le port de burin (dependance declaree)" ($r.Code -eq 0) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r2figurantdonnees' 'modules/figurant/execution/figurant/cEbDonneesFigurant.owl' 'oEssaiFigurant est un cEbSql'
    Verifie "R2 : un autre fichier du module figurant qui touche a burin est refuse et nomme" (($r.Code -eq 1) -and ($r.Sortie -match 'R2 modules/figurant/execution/figurant/cEbDonneesFigurant\.owl : reference cEbSql')) ("code=" + $r.Code + " " + $r.Sortie)

    # R9, R10, R11 : le module poincon est autonome (il ne depend que du coeur, aucun autre module ne depend de lui, seul le generateur de burin en ecrit les appels).
    $r = Essai 'r9burin' 'modules/poincon/execution/poincon/EbPoincon.owl' 'oEssaiR9 est un cEbBaseApplication'
    Verifie "R9 : un fichier du poincon qui cite un nom de burin est refuse et nomme" (($r.Code -eq 1) -and ($r.Sortie -match 'R9 modules/poincon/execution/poincon/EbPoincon\.owl : reference cEbBaseApplication')) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r9auth' 'modules/poincon/execution/poincon/EbCorpsRequete.owl' 'sEssaiR9Auth est une chaine = EbIdentiteDuJeton("x")'
    Verifie "R9 : un fichier du poincon qui cite un nom d'auth est refuse et nomme" (($r.Code -eq 1) -and ($r.Sortie -match 'R9 modules/poincon/execution/poincon/EbCorpsRequete\.owl : reference EbIdentiteDuJeton')) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r9coeur' 'modules/poincon/execution/poincon/EbPoincon.owl' 'sEssaiR9Coeur est une chaine = EbDateIsoValide("2026-01-01")'
    Verifie "R9 : le poincon peut utiliser le coeur (les dates ISO y sont)" ($r.Code -eq 0) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r10burin' 'modules/burin/execution/liste/EbListe.owl' 'EbPoinconRefuse("a", "b")'
    Verifie "R10 : un fichier de burin qui appelle le poincon est refuse et nomme" (($r.Code -eq 1) -and ($r.Sortie -match 'R10 modules/burin/execution/liste/EbListe\.owl : reference EbPoinconRefuse')) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r10coeur' 'modules/core/execution/http/EbErreurHttp.owl' 'EbPoinconRefuse("a", "b")'
    Verifie "R10 : un fichier du coeur qui appelle le poincon est refuse et nomme" (($r.Code -eq 1) -and ($r.Sortie -match 'R10 modules/core/execution/http/EbErreurHttp\.owl : reference EbPoinconRefuse')) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r10texte' 'modules/burin/execution/liste/EbListe.owl' '// EbPoinconRefuse est cite en commentaire seulement'
    Verifie "R10 : un nom du poincon cite en commentaire ne declenche rien" ($r.Code -eq 0) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r11' 'modules/core/outils/commandes/EbCommandeVersion.owl' '// EbPoinconRefuse'
    Verifie "R11 : l'outillage du coeur qui cite le poincon est refuse et nomme" (($r.Code -eq 1) -and ($r.Sortie -match 'R11 modules/core/outils/commandes/EbCommandeVersion\.owl : cite EbPoinconRefuse')) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r11burin' 'modules/burin/outils/commandes/make/EbContenuRoutes.owl' 'sEssaiR11 est une chaine = "EbPoinconRefuse(sAbsents, sErreurs)"'
    Verifie "R11 : le generateur de burin peut ecrire les appels au poincon (c'est lui qui ecrit le controleur)" ($r.Code -eq 0) ("code=" + $r.Code + " " + $r.Sortie)
    # R7 : le coeur ne nomme aucun fournisseur de base, meme en commentaire ou dans une chaine (ce sont des donnees du module burin).
    $r = Essai 'r7commentaire' 'modules/core/outils/commandes/EbCommandeVersion.owl' '// ici on parle de PostgreSQL'
    Verifie "R7 : un nom de fournisseur dans un commentaire du coeur est refuse et nomme" (($r.Code -eq 1) -and ($r.Sortie -match 'R7 modules/core/outils/commandes/EbCommandeVersion\.owl : cite postgresql')) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r7chaine' 'src/commandes/EbAiguillage.owl' 'sEssaiR7 est une chaine = "sqlite"'
    Verifie "R7 : un nom de fournisseur dans une chaine de src\ est refuse et nomme" (($r.Code -eq 1) -and ($r.Sortie -match 'R7 src/commandes/EbAiguillage\.owl : cite sqlite')) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r7execution' 'modules/core/execution/http/EbErreurHttp.owl' '// HFSQL'
    Verifie "R7 : la bibliotheque du coeur (modules\core\execution\) est couverte aussi" (($r.Code -eq 1) -and ($r.Sortie -match 'R7 modules/core/execution/http/EbErreurHttp\.owl : cite hfsql')) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r7burin' 'modules/burin/outils/commandes/make/EbCommandeMake.owl' '// sqlite postgresql hfsql'
    Verifie "R7 : le module burin peut nommer ses fournisseurs (c'est lui qui les offre)" ($r.Code -eq 0) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r7auth' 'modules/auth/outils/commandes/token/EbCommandeToken.owl' '// sqlite postgresql hfsql'
    Verifie "R7 : le module auth n'est pas dans le perimetre (dette connue : sa commande token nomme encore des fournisseurs)" ($r.Code -eq 0) ("code=" + $r.Code + " " + $r.Sortie)

    # R8 : le coeur n'a aucun identifiant qui dise migration (une migration est un fichier declare par un manifeste), mais ses textes en parlent (dette).
    $r = Essai 'r8' 'modules/core/outils/commandes/EbCommandeVersion.owl' 'sEssaiR8 est une chaine = EbLitMigrationDuModule("x")'
    Verifie "R8 : un identifiant du coeur qui dit migration est refuse et nomme" (($r.Code -eq 1) -and ($r.Sortie -match 'R8 modules/core/outils/commandes/EbCommandeVersion\.owl : l''identifiant EbLitMigrationDuModule')) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r8src' 'src/commandes/EbAiguillage.owl' 'oEssaiR8 est un cEbMigrationEssai'
    Verifie "R8 : src\ aussi (une classe qui dit migration)" (($r.Code -eq 1) -and ($r.Sortie -match 'R8 src/commandes/EbAiguillage\.owl : l''identifiant cEbMigrationEssai')) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r8texte' 'modules/core/outils/commandes/EbCommandeVersion.owl' ('// ebony migrate applique les migrations' + "`r`n" + 'sEssaiR8Texte est une chaine = "database/migrations et ebony migrate"')
    Verifie "R8 : un commentaire ou un texte du coeur qui parle de migrations ne declenche rien (dette, pas regle)" ($r.Code -eq 0) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r8commande' 'src/commandes/EbAiguillage.owl' 'sEssaiR8Commande est une chaine = EbExecuteMigrate()'
    Verifie "R8 : le nom de la commande migrate (EbExecuteMigrate) n'est pas un identifiant de migration" ($r.Code -eq 0) ("code=" + $r.Code + " " + $r.Sortie)

    $r = Essai 'r8burin' 'modules/burin/outils/commandes/make/EbCommandeMake.owl' 'sEssaiR8Burin est une chaine = EbLitMigrationDuModule("x")'
    Verifie "R8 : le module burin peut avoir des identifiants de migration (c'est son travail)" ($r.Code -eq 0) ("code=" + $r.Code + " " + $r.Sortie)
}
finally {
    if (Test-Path -LiteralPath $zone) { Remove-Item -LiteralPath $zone -Recurse -Force -ErrorAction SilentlyContinue }
}

if ($verifications -lt 10) { Write-Host ("`nFRONTIERES : seulement " + $verifications + " verification(s) executee(s) : le test n'a pas pu faire son travail") -ForegroundColor Red; exit 1 }
if ($echecs -gt 0) { Write-Host ("`nFRONTIERES : " + $echecs + " ECHEC(S)") -ForegroundColor Red; exit 1 }
Write-Host "`nFRONTIERES : TOUT PASSE" -ForegroundColor Green
exit 0
