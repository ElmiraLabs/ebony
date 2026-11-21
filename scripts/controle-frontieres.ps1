# Controle : les frontieres entre le coeur et les modules d'ebony, sans lancer owl.
#
# Pourquoi : OWL n'a ni espaces de noms ni imports, donc rien ne l'empeche de laisser un fichier du coeur appeler un module. Une fuite passerait inapercue jusqu'au jour ou
# l'on retire le module (un projet genere qui ne compile plus). Ce controle fige les points de contact connus et echoue des qu'un nouveau apparait.
# Il lit les noms de haut niveau (classes, Collections, interfaces, structures, enumerations, procedures d'une Collection) et cherche leurs references dans le CODE des fichiers
# (commentaires et chaines de caracteres retires, ligne par ligne ; une chaine entre accents graves sur plusieurs lignes n'est pas retiree : approximation connue).
#
# Regles :
#   R1  la bibliotheque d'execution (modules\*\execution\) ne reference aucun nom declare dans l'outillage (src\ et modules\*\outils\) : elle est copiee seule dans les projets generes.
#   R2  hors de modules\burin\execution\ (la bibliotheque du module burin : donnees\ et requetes\), seuls trois fichiers referencent un de ses noms : modules\auth\execution\auth\cEbJetons.owl et EbAutorisation.owl, et modules\figurant\execution\figurant\cEbGenerateurFigurant.owl
#       (le module auth depend de la base : dependance declaree, dans ce sens seulement ; le module figurant aussi, par un seul fichier : son generateur implemente iEbGenerateur, le port des fabriques de burin). Le coeur, cEbApplication comprise, ne connait PAS la base : il ne connait que le contrat iEbComposant
#       (cycle\EbContratsApplication.owl), et c'est le service genere qui ajoute la base a l'application (cEbServiceBase).
#   R3  hors du module auth (modules\auth\), aucun fichier de la bibliotheque ne reference un nom d'auth.
#   R4  dans l'outillage, seul modules\auth\outils\ (la commande du module) cite un nom d'auth : le coeur ne sait plus ecrire un garde de routes, il insere celui que fournit le manifeste.
#   R5  hors du module auth, seul src\commandes\EbAiguillage.owl (le repartiteur de commandes) appelle un nom declare dans modules\auth\outils\ (la commande token).
#   R6  hors du module burin, seuls src\commandes\EbAiguillage.owl et modules\auth\outils\ (le module auth depend de la base, dans ce sens seulement) citent un nom declare dans
#       modules\burin\outils\ (les commandes migrate et make). Le coeur ne connait pas l'outillage de la base.
#   R7  le coeur (src\ et modules\core\, tous les fichiers) ne cite aucun nom de fournisseur de base (sqlite, postgresql, hfsql), meme dans un commentaire ou un texte : les fournisseurs sont des\n#       DONNEES du module burin (membre fournisseurs de son manifeste). Texte brut, comme R4 : un nom ecrit dans une chaine est deja un couplage.
#   R8  le coeur (src\ et modules\core\) n'a aucun IDENTIFIANT qui dise migration (classe, procedure, variable) : une migration est un fichier que le manifeste d'un module declare, le coeur ne connait ni son format ni son contenu.
#       Code seul (commentaires et chaines retires) : les textes qu'ebony ecrit pour l'utilisateur (l'aide, AGENTS.md, README.md) parlent encore de migrations, c'est une dette (ils devront venir d'un manifeste de burin), pas une regle.
#   R9  le module poincon (modules\poincon\execution\) est AUTONOME : il ne reference aucun nom declare par un autre module (burin, auth, figurant), seulement le coeur.
#   R10 aucun autre module (modules\*\execution\, hors poincon) ne reference un nom du poincon : la base, l'authentification et les generateurs fonctionnent sans lui.
#   R11 dans l'outillage, seul modules\burin\outils\ (le generateur du controleur d'une ressource, qui ecrit les appels au Poincon) cite un nom du poincon.
#
# Usage : .\scripts\controle-frontieres.ps1 [-Racine <dossier>]       code de sortie 0 si les frontieres sont respectees, 1 sinon. Ce fichier reste ASCII.

param([string]$Racine = '')

if ($Racine -eq '') { $Racine = Split-Path $PSScriptRoot -Parent }
$Racine = (Resolve-Path -LiteralPath $Racine).Path.TrimEnd('\')
$utf8 = New-Object Text.UTF8Encoding($false)

function LitFichier([string]$Chemin) { return [IO.File]::ReadAllText($Chemin, $utf8) }
function CheminRelatif([string]$Chemin) { return $Chemin.Substring($Racine.Length + 1).Replace('\', '/') }

# Les noms de haut niveau declares dans ces fichiers. Un tableau associatif PowerShell ignore la casse, comme OWL.
function NomsDeclares([object[]]$Fichiers) {
    $noms = @{}
    foreach ($f in $Fichiers) {
        $texte = LitFichier $f.FullName
        foreach ($m in [regex]::Matches($texte, '(?m)^\s*(\w+)\s+est\s+une?\s+(Classe|CollectionDeProc\S*dures|Interface|Structure|Enum\S*ration)\b')) { $noms[$m.Groups[1].Value] = $true }
        if ($texte -match '(?m)^\w+\s+est\s+une\s+CollectionDeProc\S*dures') {
            foreach ($m in [regex]::Matches($texte, '(?m)^\s*PROCEDURE\s+(\w+)\s*\(')) { $noms[$m.Groups[1].Value] = $true }
        }
    }
    return $noms
}

# Le code d'un fichier : chaque ligne sans ses chaines ("..." et `...` sur une ligne) ni son commentaire (// jusqu'a la fin de la ligne).
function CodeSeul([string]$Texte) {
    $lignes = foreach ($ligne in ($Texte -split "`r?`n")) {
        $sansChaines = ($ligne -replace '"[^"]*"', '""') -replace '`[^`]*`', '""'
        $sansChaines -replace '//.*$', ''
    }
    return ($lignes -join "`n")
}

# Les noms de la liste qui apparaissent comme mots dans ce texte.
function NomsCites([string]$Texte, [hashtable]$Noms) {
    $trouves = @{}
    foreach ($m in [regex]::Matches($Texte, '\b[A-Za-z_]\w*')) {
        if ($Noms.ContainsKey($m.Value)) { $trouves[$m.Value] = $true }
    }
    return @($trouves.Keys | Sort-Object)
}

$fichiersExecution = @(Get-ChildItem (Join-Path $Racine 'modules') -Recurse -Filter '*.owl' | Where-Object { (CheminRelatif $_.FullName) -like 'modules/*/execution/*' })
$fichiersSrc = @(Get-ChildItem (Join-Path $Racine 'src') -Recurse -Filter '*.owl')
$fichiersOutilsModules = @(Get-ChildItem (Join-Path $Racine 'modules') -Recurse -Filter '*.owl' | Where-Object { (CheminRelatif $_.FullName) -like 'modules/*/outils/*' })
$fichiersOutils = @($fichiersSrc) + @($fichiersOutilsModules)
$fichiersAuthOutils = @($fichiersOutilsModules | Where-Object { (CheminRelatif $_.FullName) -like 'modules/auth/outils/*' })
$fichiersDbOutils = @($fichiersOutilsModules | Where-Object { (CheminRelatif $_.FullName) -like 'modules/burin/outils/*' })
$fichiersDonnees = @($fichiersExecution | Where-Object { (CheminRelatif $_.FullName) -like 'modules/burin/execution/*' })
$fichiersAuth = @($fichiersExecution | Where-Object { (CheminRelatif $_.FullName) -like 'modules/auth/execution/*' })
$fichiersPoincon = @($fichiersExecution | Where-Object { (CheminRelatif $_.FullName) -like 'modules/poincon/execution/*' })
$fichiersAutresModules = @($fichiersExecution | Where-Object { $r = CheminRelatif $_.FullName; ($r -notlike 'modules/core/*') -and ($r -notlike 'modules/poincon/*') })

$nomsOutils = NomsDeclares $fichiersOutils
$nomsAuthOutils = NomsDeclares $fichiersAuthOutils
$nomsDbOutils = NomsDeclares $fichiersDbOutils
$nomsDonnees = NomsDeclares $fichiersDonnees
$nomsAuth = NomsDeclares $fichiersAuth
$nomsPoincon = NomsDeclares $fichiersPoincon
$nomsAutresModules = NomsDeclares $fichiersAutresModules

$problemes = @()
if ($fichiersExecution.Count -eq 0 -or $fichiersSrc.Count -eq 0) { $problemes += "modules\*\execution\ ou src\ est introuvable ou vide dans $Racine : rien n'a ete controle" }
if ($fichiersDonnees.Count -eq 0 -or $nomsDonnees.Count -eq 0) { $problemes += "modules\burin\execution\ est introuvable ou ne declare aucun nom : la regle R2 ne controlerait rien" }
if ($fichiersAuthOutils.Count -eq 0 -or $nomsAuthOutils.Count -eq 0) { $problemes += "modules\auth\outils\ est introuvable ou ne declare aucun nom : la regle R5 ne controlerait rien" }
if ($fichiersDbOutils.Count -eq 0 -or $nomsDbOutils.Count -eq 0) { $problemes += "modules\burin\outils\ est introuvable ou ne declare aucun nom : la regle R6 ne controlerait rien" }
if ($fichiersAuth.Count -eq 0 -or $nomsAuth.Count -eq 0) { $problemes += "modules\auth\execution\ est introuvable ou ne declare aucun nom : les regles R3 et R4 ne controleraient rien" }
if ($fichiersPoincon.Count -eq 0 -or $nomsPoincon.Count -eq 0) { $problemes += "modules\poincon\execution\ est introuvable ou ne declare aucun nom : les regles R9, R10 et R11 ne controleraient rien" }
$fichiersCoeur = @(Get-ChildItem (Join-Path $Racine 'src') -Recurse -File) + @(Get-ChildItem (Join-Path $Racine 'modules\core') -Recurse -File)
if ($fichiersCoeur.Count -lt 50) { $problemes += "src\ et modules\core\ ne contiennent que $($fichiersCoeur.Count) fichiers : la regle R7 ne controlerait presque rien" }

$autorisesDonnees = @('modules/auth/execution/auth/cEbJetons.owl', 'modules/auth/execution/auth/EbAutorisation.owl', 'modules/figurant/execution/figurant/cEbGenerateurFigurant.owl')

foreach ($f in $fichiersExecution) {
    $rel = CheminRelatif $f.FullName
    $code = CodeSeul (LitFichier $f.FullName)
    foreach ($nom in (NomsCites $code $nomsOutils)) { $problemes += ("R1 " + $rel + " : reference " + $nom + ", declare dans l'outillage, src\ ou modules\*\outils\ (la bibliotheque ne doit rien devoir au generateur)") }
    if ($rel -notlike 'modules/burin/execution/*' -and $autorisesDonnees -notcontains $rel) {
        foreach ($nom in (NomsCites $code $nomsDonnees)) { $problemes += ("R2 " + $rel + " : reference " + $nom + ", declare dans modules\burin\execution\ (module burin ; seuls cEbJetons et EbAutorisation, du module auth, et cEbGenerateurFigurant, du module figurant, le peuvent : le coeur ne connait pas la base)") }
    }
    if ($rel -like 'modules/poincon/execution/*') {
        foreach ($nom in (NomsCites $code $nomsAutresModules)) { $problemes += ("R9 " + $rel + " : reference " + $nom + ", declare dans un autre module (burin, auth, figurant) : le poincon ne doit dependre que du coeur") }
    } else {
        foreach ($nom in (NomsCites $code $nomsPoincon)) { $problemes += ("R10 " + $rel + " : reference " + $nom + ", declare dans modules\poincon\execution\ (aucun autre module ne doit dependre du poincon)") }
    }
    if ($rel -notlike 'modules/auth/*') {
        foreach ($nom in (NomsCites $code $nomsAuth)) { $problemes += ("R3 " + $rel + " : reference " + $nom + ", declare dans modules\auth\ (le coeur ne connait pas le module)") }
    }
}

foreach ($f in $fichiersOutils) {
    $rel = CheminRelatif $f.FullName
    # R6 : le code ne nomme pas l'outillage de la base, sauf le repartiteur, le module burin lui-meme et le module auth (qui depend de la base).
    if ($rel -ne 'src/commandes/EbAiguillage.owl' -and $rel -notlike 'modules/burin/*' -and $rel -notlike 'modules/auth/*') {
        foreach ($nom in (NomsCites (CodeSeul (LitFichier $f.FullName)) $nomsDbOutils)) { $problemes += ("R6 " + $rel + " : reference " + $nom + ", declare dans modules\burin\outils\ (seuls EbAiguillage et modules\auth\outils\ le peuvent : le coeur ne connait pas l'outillage de la base)") }
    }
    if ($rel -notlike 'modules/burin/outils/*' -and $rel -notlike 'modules/poincon/outils/*') {
        foreach ($nom in (NomsCites (LitFichier $f.FullName) $nomsPoincon)) { $problemes += ("R11 " + $rel + " : cite " + $nom + ", declare dans modules\poincon\execution\ (seul modules\burin\outils\, qui ecrit le controleur d'une ressource, le peut)") }
    }
    if ($rel -like 'modules/auth/*') { continue }
    # R5 : le code (hors commentaires et chaines) ne nomme pas la commande du module, sauf le repartiteur de commandes.
    if ($rel -ne 'src/commandes/EbAiguillage.owl') {
        foreach ($nom in (NomsCites (CodeSeul (LitFichier $f.FullName)) $nomsAuthOutils)) { $problemes += ("R5 " + $rel + " : reference " + $nom + ", declare dans modules\auth\outils\ (seul EbAiguillage appelle la commande du module)") }
    }
    # Texte brut, chaines et commentaires compris : le generateur ecrit des noms du module dans le texte qu'il produit, et un commentaire qui en parle est deja un couplage a nommer.
    foreach ($nom in (NomsCites (LitFichier $f.FullName) $nomsAuth)) { $problemes += ("R4 " + $rel + " : cite " + $nom + ", declare dans modules\auth\ (seul modules\auth\outils\ le peut)") }
}

# R7 : le coeur ne nomme aucun fournisseur de base. Les noms viennent des manifestes des modules ; ils ne s'ecrivent nulle part dans src\ ni modules\core\ (commentaires et chaines compris).
foreach ($f in $fichiersCoeur) {
    $rel = CheminRelatif $f.FullName
    foreach ($m in [regex]::Matches((LitFichier $f.FullName), '(?i)sqlite|postgresql|hfsql')) { $problemes += ("R7 " + $rel + " : cite " + $m.Value.ToLower() + ", un fournisseur de base (donnee du module burin, pas du coeur)"); break }
}

# R8 : aucun identifiant du coeur ne dit migration. Les noms de commande (EbExecuteMigrate, un mot "Migrate") ne sont pas concernes : seul "migration" l'est.
foreach ($f in $fichiersCoeur) {
    if ($f.Extension -ne '.owl') { continue }
    $rel = CheminRelatif $f.FullName
    foreach ($m in [regex]::Matches((CodeSeul (LitFichier $f.FullName)), '\b\w*[Mm][Ii][Gg][Rr][Aa][Tt][Ii][Oo][Nn]\w*')) { $problemes += ("R8 " + $rel + " : l'identifiant " + $m.Value + " parle de migration (une migration est un fichier declare par le manifeste d'un module : le coeur ne connait ni son format ni son contenu)"); break }
}
if ($problemes.Count -gt 0) {
    $problemes | ForEach-Object { Write-Output $_ }
    exit 1
}
Write-Output ("Frontieres respectees : {0} fichiers de modules\*\execution\ et {1} d'outillage controles ({2} noms d'outillage, {3} dans donnees, {4} dans auth, {5} dans burin\outils ; R7 : {6} fichiers du coeur)." -f $fichiersExecution.Count, $fichiersOutils.Count, $nomsOutils.Count, $nomsDonnees.Count, $nomsAuth.Count, $nomsDbOutils.Count, $fichiersCoeur.Count)
exit 0
