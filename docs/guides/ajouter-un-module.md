# Ajouter un module à un projet

`ebony add <module>` ajoute un [module](modules.md) (`burin`, `poincon`, `auth`, `figurant`) à un projet qui existe déjà : créé avec `ebony new` (le kit `slim`, par exemple, qui n'a ni base ni jetons) ou adopté avec [`ebony init`](adopter-un-projet.md). Le projet obtenu est le même que celui qu'aurait écrit `ebony new --kit api`.

## Un exemple : de `slim` à `api`

```powershell
ebony new boutique --kit slim
cd boutique
ebony add burin
ebony add poincon
ebony add auth
ebony migrate
```

`ebony add burin` ajoute la base de données (SQLite par défaut) :

```text
Module ajouté au projet : burin (…\boutique)
  Modules     : burin
  Base        : sqlite
  Créés       : ebony/ (module burin)
  Réécrits    : config/env.json, .env.exemple, .env.secrets.exemple, app/Composants.owl, ebony.conf

Pour continuer :
  ebony env
```

`ebony add poincon` ajoute la validation des corps de requête. Il n'a besoin ni de la base ni d'une migration, et peut aussi s'ajouter seul à un projet sans base.

`ebony add auth` ajoute les jetons d'accès, et écrit la migration qui crée leur table :

```text
Module ajouté au projet : auth (…\boutique)
  Modules     : burin, poincon, auth
  Base        : sqlite
  Créés       : ebony/ (module auth), database/migrations/M202611100000_CreeEbJetons.owl
  Réécrits    : .env.exemple, ebony.conf

Pour continuer :
  ebony migrate
  ebony env
```

Après `ebony migrate`, `GET /api/health` répond `{"statut":"ok","base":"ok"}`.

## Ce que `ebony add` écrit

- **La bibliothèque du module**, dans `ebony/`, puis le module dans la liste `modules` de [`ebony.conf`](ebony-conf.md). `ebony.conf` est écrit en dernier : le module n'y figure que quand l'ajout est terminé.
- **Les fichiers et migrations que le module déclare** (la migration des jetons, par exemple), sans jamais écraser un fichier qui existe.
- **Les fichiers qu'Ebony gère** : `config/env.json`, `.env.exemple`, `.env.secrets.exemple` (les variables du module) et `app/Composants.owl` (le registre des composants : voir [la structure](structure.md)).

**Votre service n'est jamais modifié.** Il appelle le registre `app/Composants.owl` au démarrage, donc ajouter un module ne le change pas.

### Les fichiers que vous avez modifiés

Ebony réécrit un fichier qu'il gère seulement s'il est encore tel qu'il l'avait écrit. Si vous l'avez modifié, même d'un caractère, il n'y touche pas : il le liste sous « Conservés » et dit ce qu'il faut y ajouter. Par exemple :

```text
  Conservés   : config/env.json (modifiés par vous : non touchés)

À faire vous-même :
  - Votre config/env.json n'a pas été modifié (il n'est plus tel qu'ebony l'avait écrit). Ajoutez-y les variables : AUTH_ROUTES, puis vérifiez avec « ebony env ».
```

Le module est ajouté malgré tout. Recopiez ce que la note indique, puis lancez `ebony env` pour contrôler la configuration.

## Choisir la base

`ebony add burin` prend SQLite par défaut. `--base sqlite|postgresql|hfsql` en choisit une autre :

```powershell
ebony add burin --base postgresql
```

La base choisie est notée dans `ebony.conf`. `ebony add` ne change jamais la base d'un projet : `ebony add auth --base postgresql` sur un projet déjà en SQLite est refusé.

## Ce qu'il refuse

Toutes les vérifications ont lieu avant d'écrire : un refus ne laisse rien derrière lui.

| Situation | Ce que dit Ebony |
|---|---|
| Le module dépend d'un autre qui manque | de l'ajouter d'abord (`auth` a besoin de `burin`) |
| Le module n'existe pas | la liste des modules qu'on peut ajouter |
| Le module est déjà dans le projet | qu'il y est déjà |
| `ebony/` n'est pas la bibliothèque de l'Ebony installé | de supprimer ce dossier, puis de lancer `ebony upgrade` |
| Un dossier du module existe déjà et n'est pas vide dans `ebony/` | la liste des éléments en conflit |
| Ce n'est pas un projet Ebony | de se placer dans le dossier d'un projet |
| `--base` inconnu | les valeurs possibles |

Si l'écriture est interrompue en route (disque plein, accès refusé), `ebony.conf` n'a pas été modifié. Le message dit ce qui a pu être laissé : supprimez-le (le dossier du module dans `ebony/` d'abord), puis relancez.

## Un projet adopté avec `ebony init`

Un projet adopté a déjà son registre `app/Composants.owl` et un service à lui, qui doit l'appeler (voir [adopter Ebony](adopter-un-projet.md)). Dans ce cas, `ebony add burin` ne modifie pas le service : `GET /api/health` passe de `{"statut":"ok"}` à `{"statut":"ok","base":"ok"}`.

Si le projet n'a pas de registre, `ebony add` en écrit un quand le module apporte un composant (la base). Une note dit alors les lignes à ajouter au service : `POUR TOUT oFabrique DE …Fabriques()`, puis `oApp.Ajoute(oFabrique)` et `FIN`. Si ce service crée déjà la base lui-même, retirez ces lignes : elle démarrerait deux fois.

## Pour un outil : `--json`

`ebony add burin --json` écrit une seule ligne :

```json
{"ok":true,"dir":"…","module":"burin","modules":["burin"],"base":"sqlite","files":["ebony/ (module burin)"],"updated":["config/env.json",".env.exemple",".env.secrets.exemple","app/Composants.owl","ebony.conf"],"kept":[],"notes":[],"next":["ebony env"]}
```

`files` : ce qui est créé. `updated` : ce qu'Ebony a réécrit. `kept` : ce que vous aviez modifié et qu'il n'a pas touché. `notes` : ce que vous devez faire. `next` : les commandes à lancer ensuite. En cas d'échec : `{"ok":false,"error":…}`.

## Pièges courants

- **PostgreSQL et HFSQL** : `ebony add` écrit les fichiers attendus, mais le parcours complet n'a été vérifié qu'avec SQLite.
- **`--auth` et `--table`** de `ebony new` n'ont pas d'équivalent : `ebony add auth` ajoute les jetons, pas la table des utilisateurs.
- **`README.md` et `AGENTS.md`** ne sont pas réécrits : ils parlent du kit d'origine.
