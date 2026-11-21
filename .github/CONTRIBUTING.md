# Contribuer à Ebony

Merci de vouloir aider. Une contribution peut être petite : un rapport de bug clair aide autant qu'une correction.

En participant, vous acceptez le [code de conduite](CODE_OF_CONDUCT.md). Pour une **faille de sécurité**, ne créez pas de ticket public : suivez la [politique de sécurité](SECURITY.md).

## Signaler un bug ou proposer une idée

Ouvrez un ticket sur ce dépôt. Pour un bug, donnez :

- la sortie de `ebony doctor` (elle dit la version d'Ebony, celle d'OWL et le système) ;
- les commandes exactes que vous avez lancées et ce qui s'est passé, avec le message d'erreur complet ;
- si possible, le plus petit projet qui reproduit le problème.

Pour une idée, dites d'abord **le problème** que vous voulez résoudre, puis la forme que vous imaginez.

## Proposer une modification

1. Ouvrez un ticket avant un gros changement, pour vérifier qu'il va dans le sens du projet.
2. Faites une branche, **un changement par demande**, petit et vérifié.
3. Écrivez ou adaptez les tests qui prouvent le comportement ; sans test, dites pourquoi.
4. Titre de la demande en [Conventional Commits](https://www.conventionalcommits.org/fr/) : `<type>(<portée facultative>): <description>`, avec les types `feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `build`, `ci`, `chore`, `revert` ; un `!` après le type signale un changement incompatible.
5. Dites ce qui a été testé, ce qui ne l'a pas été, et sur quel système (Windows ou Linux).

Une contribution acceptée est publiée avec une prochaine version du projet.

## Travailler sur le code

Il vous faut [OWL](https://github.com/followthewhiteowl/neowl) **1.9.0** dans le PATH. Depuis un clone du dépôt :

```powershell
owl --check projet.owl            # le projet compile-t-il ? (environ une minute)
owl fmt --check <fichier.owl>     # le formatage d'OWL, un fichier à la fois ; sans --check il réécrit le fichier
.\scripts\test-rapide.ps1         # les tests unitaires, chaque suite isolée (environ une minute)
.\scripts\verifier.ps1            # la vérification complète, ciblée sur ce que vous avez modifié (de quelques secondes à une vingtaine de minutes)
```

Quelques règles de ce dépôt :

- **Un fichier `.owl` passe par `owl fmt`** après chaque modification.
- **Un seul projet OWL** : tous les `.owl` forment un projet (`projet.owl` à la racine), donc les noms de haut niveau sont uniques ; la bibliothèque d'exécution est préfixée `Eb`.
- **Les modèles de fichiers générés sont des `.tpl`**, jamais des `.owl`.
- **Les fichiers `.cmd` sont en CRLF** (`cmd.exe` l'exige) ; ne les éditez pas avec un outil qui convertit les fins de ligne.
- Après un changement du générateur, relancez `.\scripts\construit-entrees.ps1` : le lanceur utilise des points d'entrée réduits générés par ce script.
- Sous Linux, `pwsh scripts/verifier.ps1` tourne avec PowerShell 7 ; certaines étapes propres à Windows y sont ignorées et dites telles.

La vérification complète (`.\scripts\verifier.ps1 -Complet`) est demandée avant une version publiée.

## Licence

En contribuant, vous acceptez que votre contribution soit publiée sous la [licence MIT](../LICENSE) du projet.