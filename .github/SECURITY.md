# Politique de sécurité

Ebony est une **préversion**. Cette page dit comment signaler une faille et ce que vous pouvez en attendre.

## Versions concernées

Seule la **dernière version publiée** (voir les [releases](https://github.com/ElmiraLabs/ebony/releases)) reçoit des corrections. Il n'y a pas de branche de maintenance pour les versions plus anciennes.

## Signaler une faille

**N'ouvrez pas de ticket public** pour une faille de sécurité.

Utilisez le signalement privé de GitHub : onglet **Security** du dépôt, bouton **Report a vulnerability** (<https://github.com/ElmiraLabs/ebony/security/advisories/new>). Seules les personnes qui gèrent le projet voient le rapport.

Un bon rapport dit :

- la version d'Ebony (`ebony --version`) et celle d'OWL (`owl --version`), le système (Windows ou Linux) ;
- ce que vous avez fait, ce que vous attendiez, ce qui s'est passé : les commandes exactes, un projet minimal si possible ;
- l'effet possible (lire ou écrire hors d'un dossier, exécuter du code, contourner un jeton, fuite d'un secret…).

Il n'y a **pas de délai de réponse garanti** : c'est un petit projet en préversion. Nous accusons réception dès que nous le pouvons, nous corrigeons, puis nous publions le correctif dans une version avec ses notes ; nous vous citons si vous le souhaitez.

## Ce qui relève d'Ebony, et ce qui n'en relève pas

- **Ebony** : le générateur (`ebony new`, `make`, `add`, `upgrade`…), la bibliothèque copiée dans `ebony/` d'un projet, les installateurs (`install.ps1`, `install.sh`), le lanceur.
- **Pas Ebony** : le langage et l'outil `owl` eux-mêmes. Une faille d'OWL se signale à l'équipe d'OWL ([followthewhiteowl/neowl](https://github.com/followthewhiteowl/neowl)). Ebony n'est pas affilié à cette équipe.
- **Votre application** : le code que vous écrivez ou modifiez dans un projet généré vous appartient. Les limites connues d'un service OWL (une requête à la fois, validation des corps, pas de connexion d'utilisateur) sont décrites dans [Statut et limites](https://elmiralabs.github.io/ebony/guides/statut-et-limites) : elles ne sont pas des failles.

## À savoir sur l'installation

Les installateurs vérifient la somme SHA-256 de l'archive téléchargée : cela protège d'un téléchargement corrompu, **pas** d'une release compromise. Lisez le script avant de l'exécuter si vous voulez (`install/install.ps1`, `install/install.sh`).