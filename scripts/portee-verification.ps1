# Quelles etapes de scripts\verifier.ps1 un ensemble de fichiers modifies rend-il necessaires ? (dot-sourcing : ce fichier ne definit que des fonctions.)
#
# Pourquoi : la verification complete dure 25 a 40 minutes sur la machine de developpement (2 coeurs), dont la plus grande part est du travail qu'une modification de Burin, d'Auth, d'un test ou d'un guide n'a aucune chance
# de changer (archive, installateurs, groupe installe...). On ne lance donc que ce que les fichiers modifies peuvent atteindre ; la verification COMPLETE reste la regle avant une release, apres une nouvelle version d'OWL
# et chaque fois qu'on la demande (verifier.ps1 -Complet).
#
# Principe : une table de regles (motif du chemin -> etapes). Un chemin que AUCUNE regle ne connait declenche la verification complete : une erreur de classement coute du temps, jamais un faux vert.
# Les fichiers modifies sont ceux de la branche (git diff contre l'ancetre commun avec main, copie de travail comprise) plus les fichiers non suivis. Rien de modifie, git absent ou main introuvable : verification complete.
# Ce fichier reste ASCII.

# Les etapes qu'une regle peut allumer.
$etapesDeVerification = @('Compilation', 'Unitaires', 'UnitairesTous', 'Base', 'Projet', 'Make', 'Installe', 'CoeurSeul', 'Postgresql', 'Archive', 'Installateurs', 'Frontieres', 'Noms')

# Dans l'ordre : la premiere regle qui reconnait le chemin (chemin relatif au depot, avec des "/") s'applique. 'COMPLET' = tout lancer.
$reglesDePortee = @(
    # Documentation et fichiers que la verification ne lit pas : aucune etape (les controles sans owl, versions et commandes, tournent toujours).
    @{ Motif = '^(docs|\.github)/'; Etapes = @() },
    @{ Motif = '^[^/]+\.md$'; Etapes = @() },
    @{ Motif = '^LICENSE'; Etapes = @() },
    @{ Motif = '^\.mcp\.json$'; Etapes = @() },
    @{ Motif = '^modules/[^/]+\.md$'; Etapes = @() },
    @{ Motif = '^modules/[^/]+/README\.md$'; Etapes = @() },
    @{ Motif = '^(scripts|tests/unitaires|tests/integration)/README\.md$'; Etapes = @() },
    @{ Motif = '^scripts/(instantane-liste\.txt|publie-instantane\.ps1|controle-instantane\.ps1|mesure-cout\.ps1|controle-versions\.ps1)$'; Etapes = @() },
    @{ Motif = '^tests/integration/linux\.sh$'; Etapes = @() },   # le parcours Linux ne tourne pas sous Windows
    @{ Motif = '^tests/integration/portee\.ps1$'; Etapes = @() },  # etape sans owl, lancee a chaque verification
    # Un module (burin, poincon, auth) : sa bibliotheque, son outillage et ses tests. Le coeur n'en depend pas (controle statique de test-rapide.ps1) ; ni l'installation, ni l'archive, ni le groupe base n'y touchent.
    # Un manifeste ou un modele (.json, .tpl) d'un module est LU par l'aide et par la copie de la bibliotheque (groupe base : l'aide liste les bases connues d'apres burin.json) : le groupe base s'y ajoute.
    @{ Motif = '^modules/(burin|poincon|auth)/.*\.(json|tpl)$'; Etapes = @('Compilation', 'Unitaires', 'Make', 'Projet', 'Postgresql', 'Frontieres', 'Noms', 'Base') },
    @{ Motif = '^modules/(burin|poincon|auth)/'; Etapes = @('Compilation', 'Unitaires', 'Make', 'Projet', 'Postgresql', 'Frontieres', 'Noms') },
    # Le module figurant (generateur de valeurs d'exemple) : sa bibliotheque et son manifeste. Il depend de burin et n'est dans aucun kit : seul ebony add figurant (groupe make) le copie dans un projet ; ni PostgreSQL ni le groupe projet n'y touchent.
    @{ Motif = '^modules/figurant/'; Etapes = @('Compilation', 'Unitaires', 'Make', 'Frontieres', 'Noms') },
    @{ Motif = '^tests/unitaires/'; Etapes = @('Compilation', 'Unitaires') },
    # Les tests d'integration et les scripts : l'etape qu'ils pilotent.
    @{ Motif = '^tests/integration/lanceur\.ps1$'; Etapes = @('Base', 'Projet', 'Make', 'Installe') },
    @{ Motif = '^tests/integration/(postgresql\.ps1|burin/)'; Etapes = @('Postgresql') },
    @{ Motif = '^tests/integration/archive\.ps1$'; Etapes = @('Archive') },
    @{ Motif = '^tests/integration/installateur\.(ps1|sh)$'; Etapes = @('Installateurs') },
    @{ Motif = '^tests/integration/frontieres\.ps1$'; Etapes = @('Frontieres') },
    @{ Motif = '^tests/integration/(chemin-path|suppression)\.ps1$'; Etapes = @('Installe') },
    @{ Motif = '^tests/integration/noms-projet\.ps1$'; Etapes = @('Noms') },
    @{ Motif = '^scripts/(test-rapide|modules-tests)\.ps1$'; Etapes = @('UnitairesTous', 'CoeurSeul') },
    @{ Motif = '^scripts/controle-coeur-seul\.ps1$'; Etapes = @('CoeurSeul') },
    @{ Motif = '^scripts/controle-frontieres\.ps1$'; Etapes = @('Frontieres') },
    @{ Motif = '^scripts/construit-archive\.ps1$'; Etapes = @('Archive', 'Installateurs') },
    @{ Motif = '^install/'; Etapes = @('Installateurs') }
    # Tout le reste (src, modules/core, ebony.owl, projet.owl, bin, le reste de scripts, verifier.ps1 et ce fichier lui-meme, un nouveau module) : COMPLET.
)

# $Fichiers : chemins relatifs au depot. Rend { Complet ; Etapes (une clef par etape, vrai ou faux) ; Raisons (une ligne par fichier qui allume quelque chose, ou la raison du COMPLET) }.
function Get-PorteeVerification([string[]]$Fichiers) {
    $etapes = [ordered]@{}
    foreach ($nomEtape in $etapesDeVerification) { $etapes[$nomEtape] = $false }
    $raisons = @()
    $complet = $false
    if (-not $Fichiers -or $Fichiers.Count -eq 0) {
        $complet = $true
        $raisons += "aucun fichier modifie reconnu (rien a comparer) : on ne sait pas quoi verifier"
    }
    else {
        foreach ($fichier in $Fichiers) {
            $chemin = $fichier.Replace('\', '/')
            $regleTrouvee = $null
            foreach ($regle in $reglesDePortee) { if ($chemin -match $regle.Motif) { $regleTrouvee = $regle; break } }
            if ($null -eq $regleTrouvee) {
                $complet = $true
                $raisons += ($chemin + " : aucune regle ne le classe, donc verification complete")
            }
            else {
                foreach ($nomEtape in $regleTrouvee.Etapes) { $etapes[$nomEtape] = $true }
                if ($regleTrouvee.Etapes.Count -gt 0) { $raisons += ($chemin + " : " + ($regleTrouvee.Etapes -join ', ')) }
            }
        }
    }
    if ($complet) { foreach ($nomEtape in $etapesDeVerification) { $etapes[$nomEtape] = $true } }
    return [pscustomobject]@{ Complet = $complet; Etapes = $etapes; Raisons = $raisons }
}

# Un chemin tel que git l'ecrit : "mod\303\250le/x.txt" (entre guillemets, octets non ASCII en octal) avec le reglage par defaut. On le decode soi-meme en UTF-8 : lire la sortie de git
# telle quelle depend de la page de code de la console (mesure : un chemin accentue devient « modÃ¨le » quand la sortie est redirigee).
function ConvertFrom-CheminGit([string]$Ligne) {
    if (-not ($Ligne.Length -ge 2 -and $Ligne.StartsWith('"') -and $Ligne.EndsWith('"'))) { return $Ligne }
    $octets = New-Object 'System.Collections.Generic.List[byte]'
    $interieur = $Ligne.Substring(1, $Ligne.Length - 2)
    $i = 0
    while ($i -lt $interieur.Length) {
        $c = $interieur[$i]
        if ($c -ne '\') { foreach ($octet in [Text.Encoding]::UTF8.GetBytes([string]$c)) { $octets.Add($octet) }; $i++; continue }
        $i++
        $suite = $interieur[$i]
        if ($suite -ge '0' -and $suite -le '7') { $octets.Add([Convert]::ToByte($interieur.Substring($i, 3), 8)); $i += 3; continue }
        $remplacement = switch ($suite) { 't' { 9 } 'n' { 10 } 'r' { 13 } 'a' { 7 } 'b' { 8 } 'f' { 12 } 'v' { 11 } default { [int][char]$suite } }
        $octets.Add([byte]$remplacement)
        $i++
    }
    return [Text.Encoding]::UTF8.GetString($octets.ToArray())
}

# Les fichiers modifies de la branche courante : tout ce qui differe de l'ancetre commun avec main (commits, index, copie de travail ; renommages comptes comme suppression + ajout), plus les fichiers non suivis.
# Rend $null si on ne peut pas le savoir (git absent, pas de depot, pas de main), un tableau (peut-etre vide) sinon.
function Get-FichiersModifies([string]$Racine) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $null }
    $reference = $null
    foreach ($branche in @('main', 'origin/main')) {
        $null = & git -C $Racine rev-parse --verify --quiet $branche 2>$null
        if ($LASTEXITCODE -eq 0) { $reference = $branche; break }
    }
    if (-not $reference) { return $null }
    $ancetre = (& git -C $Racine merge-base HEAD $reference 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $ancetre) { return $null }
    $modifies = @(& git -C $Racine -c core.quotepath=true diff --name-only --no-renames $ancetre 2>$null)
    if ($LASTEXITCODE -ne 0) { return $null }
    $nonSuivis = @(& git -C $Racine -c core.quotepath=true ls-files --others --exclude-standard 2>$null)
    if ($LASTEXITCODE -ne 0) { return $null }
    return @(($modifies + $nonSuivis) | Where-Object { $_ } | ForEach-Object { ConvertFrom-CheminGit $_ } | Sort-Object -Unique)
}
