# Les dossiers de tests unitaires (sous tests\unitaires) qui appartiennent a un module : ils partent avec lui quand le module quitte le depot.
# Source unique, lue (dot-sourcing) par scripts\controle-coeur-seul.ps1 (qui les retire dans une copie), scripts\test-rapide.ps1 (controle statique du coeur seul)
# et scripts\portee-verification.ps1 (quel module un test concerne). Un nouveau dossier de tests propre a un module s'ajoute ICI.
# Ce fichier reste ASCII.

$testsParModule = [ordered]@{
    burin = @('execution\requetes', 'execution\donnees', 'execution\liste', 'execution\fabriques', 'commandes\make', 'commandes\migrate', 'commandes\openapi')
    poincon = @('execution\poincon')
    auth  = @('execution\auth', 'commandes\token')
    figurant = @('execution\figurant')
}
