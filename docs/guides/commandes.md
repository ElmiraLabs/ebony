# Référence des commandes

`ebony aide` liste toutes les commandes. Cette page donne, pour chacune, ce qu'elle fait et ses options. Les commandes qu'un outil (un IDE, un script) doit lire ont une option `--json`.

## Les commandes

| Commande | Ce qu'elle fait |
|---|---|
| `ebony new <nom>` | crée un projet dans un nouveau dossier, qui compile et démarre sous `owl serve`. Options : `--kit api\|slim` (voir [les kits](modules.md#les-kits)), `--base sqlite\|postgresql\|hfsql`, `--auth`, `--json`. |
| `ebony init` | ajoute Ebony à un projet OWL existant, sans rien écraser. Mêmes options que `new`, sans nom. Voir [adopter un projet](adopter-un-projet.md). |
| `ebony add <module>` | ajoute un module (`burin`, `poincon`, `auth`, `figurant`) au projet du dossier courant. Voir [ajouter un module](ajouter-un-module.md). |
| `ebony make resource <Nom> --champs …` | écrit l'entité, les repositories, le service, les tests, le contrôleur et `ressource.json` d'une table. |
| `ebony make migration <Nom>` | écrit la migration qui crée une table. |
| `ebony make seeder <Nom>` | écrit le seeder d'une ressource déjà générée. |
| `ebony migrate` | applique les migrations en attente. Voir [migrate](migrate.md). |
| `ebony token create \| list \| revoke` | gère les jetons d'accès. Voir [token](token.md). |
| `ebony openapi` | écrit le document OpenAPI de l'API. Voir plus bas. |
| `ebony env` | examine la configuration du projet sans le démarrer, sans jamais montrer la valeur d'un secret. |
| `ebony request GET /chemin` | envoie une requête HTTP à un service en cours d'exécution. Options : `--header Nom:valeur`, `--body texte`, `--port N` ou `--url adresse`. |
| `ebony doctor` | vérifie l'environnement : dossier, installation, écriture, version d'OWL, état du projet. |
| `ebony restore` | restaure le dossier `ebony/` dans un projet cloné avec git. |
| `ebony upgrade` | aligne `ebony/` et `ebony.conf` sur l'Ebony installé, et signale les variables de configuration manquantes. |
| `ebony install`, `ebony uninstall` | installent ou retirent Ebony pour l'utilisateur (Windows). Voir [l'installation](installation.md). |
| `ebony --version` | affiche la version d'Ebony. |

Toutes les commandes d'écriture (`new`, `init`, `add`, `make`) acceptent `--dry-run` : elles disent ce qui serait écrit, sans toucher au disque. Aucune ne remplace un fichier qui existe.

## `make`

Le guide détaillé de `ebony make` (options, fichiers écrits, grammaire de `--champs`) est en cours de réécriture.

## `migrate`

```text
ebony migrate [--dry-run]                        applique les migrations en attente
ebony migrate status                             liste les migrations et leur état
ebony migrate rollback [--pas N] [--dry-run]     défait la dernière migration (ou les N dernières)
```

Une migration est appliquée dans une transaction : si une instruction est refusée, elle est annulée et la commande s'arrête. Le détail est dans [migrate](migrate.md).

## `openapi`

```text
ebony openapi --sortie openapi.json [--remplace]
ebony openapi                          le document sur la sortie standard
```

À lancer dans le dossier d'un projet qui a le module `burin` et au moins une ressource. Le document décrit `GET /api/health` et, pour chaque ressource, les six routes générées : paramètres de la liste, corps de chaque opération, codes de réponse et format d'erreur. Les schémas viennent de `ressource.json` : types, clés, valeurs par défaut et règles de validation.

- **Sécurité.** Si le projet protège ses routes par jeton (le module `auth`), le document décrit un schéma `bearerAuth` exigé partout sauf sur `/api/health`.
- **Ce qui n'est pas décrit** : les routes que vous écrivez à la main.
- **Titre, version, serveur et licence** : le titre est le nom du projet, la version `1.0.0`, le serveur `http://127.0.0.1:8080` et la licence `MIT`. Modifiez-les dans le fichier si besoin.
- **Enregistrer le document** : utilisez `--sortie`, qui écrit le fichier en UTF-8 sans BOM. Sous Windows PowerShell 5.1, `ebony openapi > openapi.json` écrit en UTF-16, que les outils OpenAPI refusent : c'est la raison de `--sortie`.

## `token`

```text
ebony token create <nom> [--expire AAAA-MM-JJ]   crée un jeton et l'affiche une seule fois
ebony token list                                 liste les jetons (jamais leur secret)
ebony token revoke <identifiant>                 révoque un jeton
```

Un jeton avec `--expire` vaut jusqu'à la fin du jour indiqué, en UTC. Voir [token](token.md) et [les modules](modules.md).

## Utiliser Ebony depuis un outil

Avec `--json`, les commandes `make`, `migrate`, `token`, `env`, `new` et `request` rendent **une seule ligne JSON** sur la sortie standard. En cas d'échec : `{"ok":false,"error":"…"}`.

`ebony doctor --json` rend un objet de ce type (exemple) :

```json
{"ok":true,"ebony":"0.1.5","owl":"1.9.0","checks":[{"id":"acces-dossier","status":"ok","label":"…","message":"…","correction":""}],"errors":0,"warnings":0}
```

`status` vaut `ok`, `warning` ou `error`. `ok` est faux dès qu'il y a une erreur ; un avertissement ne le change pas. Les identifiants des contrôles sont, dans l'ordre : `acces-dossier`, `installation`, `ecriture`, `version-owl`, `etat-projet`.

### Codes de sortie

| Code | Sens |
|---|---|
| 0 | réussite (un avertissement de `doctor` ne change pas le code) |
| 1 | échec de la commande, dont une erreur de `doctor` |
| 2 | usage incorrect : commande inconnue, argument ou option manquant ou inconnu |
| 70 | erreur interne |

Un échec affiche une seule ligne `ebony : <cause>`, jamais une pile d'appels.

Chaque lancement d'`ebony` prend quelques secondes. Un outil qui l'appelle doit le faire en arrière-plan et garder le résultat.
