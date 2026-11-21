# Ajouter un module à un projet

`ebony add <module>` ajoute un [module](modules.md) (`burin`, `poincon`, `auth`, `figurant`) à un projet qui existe déjà : créé avec `ebony new` (le kit `slim`, par exemple, qui n'a ni base ni jetons) ou adopté avec [`ebony init`](adopter-un-projet.md). C'est le même chemin que `ebony new --kit api` : le projet obtenu est celui qu'un `ebony new` avec ce module aurait écrit. Référence : Ebony 0.1.5, OWL 1.9.0 et SQLite, sous Windows et Linux. PostgreSQL et HFSQL : voir la fin.

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
  Réécrits    : config/env.json, .env.exemple, .env.secrets.exemple, app/Composants.owl, ebony.conf (tels qu'ebony les avait écrits)

Pour continuer :
  ebony env
```

`ebony add poincon` ajoute la validation des corps de requête (le Poinçon). Il n'a besoin ni de la base ni d'une migration : il se copie dans `ebony/poincon/` et s'inscrit dans `ebony.conf`. Il peut aussi s'ajouter seul à un projet sans base.

`ebony add auth` ajoute les jetons d'accès, et écrit la migration qui crée leur table :

```text
Module ajouté au projet : auth (…\boutique)
  Modules     : burin, poincon, auth
  Base        : sqlite
  Créés       : ebony/ (module auth), database/migrations/M202611100000_CreeEbJetons.owl
  Réécrits    : .env.exemple, ebony.conf (tels qu'ebony les avait écrits)

Pour continuer :
  ebony migrate
  ebony env
```

Le résultat a été comparé à celui de `ebony new boutique` (kit `api`) : **les mêmes fichiers, octet pour octet**, à trois exceptions près, qui portent le kit d'origine : le membre `kit` de `ebony.conf` (`slim` reste noté), `README.md` et `AGENTS.md`. Le projet compile, `ebony migrate` applique la migration des jetons et `GET /api/health` répond `{"statut":"ok","base":"ok"}`.

## Ce que `ebony add` écrit

- **La bibliothèque du module** dans `ebony/` (rien d'autre n'y est touché), puis le module dans `modules` de [`ebony.conf`](ebony-conf.md), avec `base.fournisseur` quand le module en a besoin. `ebony.conf` est écrit **en dernier** : sa présence dans `modules` dit que l'ajout est terminé.
- **Les fichiers et migrations que le module déclare** (la migration des jetons, par exemple), sans jamais écraser un fichier qui existe.
- **Les fichiers qu'Ebony gère** : `config/env.json`, `.env.exemple`, `.env.secrets.exemple` (les variables du module) et `app/Composants.owl` (le registre des composants : la base y est déclarée, voir [la structure](structure.md)).

**Votre service n'est jamais modifié.** Il appelle le registre `app/Composants.owl` au démarrage : ajouter un module ne le change donc pas.

### Les fichiers que vous avez modifiés

Ebony réécrit un fichier qu'il gère **seulement s'il est encore tel qu'il l'avait écrit** pour les modules d'avant. Si vous l'avez modifié (même d'un caractère), il n'y touche pas : il le liste sous « Conservés » et dit ce qu'il faut y ajouter. Par exemple, après une modification de `config/env.json` :

```text
  Conservés   : config/env.json (modifiés par vous : non touchés)

À faire vous-même :
  - Votre config/env.json n'a pas été modifié (il n'est plus tel qu'ebony l'avait écrit). Ajoutez-y les variables : AUTH_ROUTES, puis vérifiez avec « ebony env ».
```

Le module est ajouté malgré tout (bibliothèque, `ebony.conf`) : c'est à vous de recopier ce que la note indique, puis de lancer `ebony env` pour contrôler la configuration.

## Choisir la base

`ebony add burin` prend **SQLite** par défaut. `--base sqlite|postgresql|hfsql` en choisit une autre :

```powershell
ebony add burin --base postgresql
```

La base choisie est notée dans `ebony.conf` (`base.fournisseur`) et dans le registre. **`ebony add` ne change jamais la base d'un projet** : `ebony add auth --base postgresql` sur un projet déjà en SQLite est refusé (code de sortie 2), de même que `--base` pour un module qui n'a pas besoin de base.

## Ce qu'il refuse

Toutes les vérifications ont lieu **avant** d'écrire : un refus ne laisse rien derrière lui. Code de sortie 1, sauf une option incorrecte (2).

| Situation | Message |
|---|---|
| Le module dépend d'un autre qui manque | « Le module « auth » a besoin de : db. Ajoutez-le d'abord (par exemple « ebony add burin »). » |
| Le module n'existe pas | « Le module « validation » n'existe pas dans l'ebony installé. Modules qu'on peut ajouter : auth, db. » |
| Le module est déjà dans le projet | « … est déjà dans ce projet … » |
| `ebony/` n'est pas la bibliothèque de l'Ebony installé (un projet créé avec une version plus ancienne, par exemple) | supprimez ce dossier (Ebony ne supprime rien), lancez `ebony upgrade`, puis relancez `ebony add` |
| Un dossier du module existe déjà et n'est pas vide dans `ebony/` | la liste des éléments en conflit, sans rien écrire |
| Un `ebony.conf` ancien, sans la liste `modules` | rien à ajouter : un tel projet a déjà tous les modules |
| Ce n'est pas un projet Ebony | placez-vous dans le dossier d'un projet |
| `--base` inconnu | « Valeur refusée pour --base … Valeurs possibles : sqlite, postgresql, hfsql. » (code 2) |

Si l'écriture est interrompue en route (disque plein, accès refusé), `ebony.conf` n'a pas été modifié : le message dit ce qui a pu être laissé ; supprimez-le (le dossier du module dans `ebony/` d'abord), puis relancez.

## Un projet adopté ou créé avant le registre

Un projet adopté avec `ebony init` a déjà son registre `app/Composants.owl` et un service à lui, qui doit l'appeler (voir [adopter Ebony](adopter-un-projet.md)). Avec `ebony init --kit slim`, puis un service qui appelle le registre, `ebony add burin` ne modifie pas le service : `GET /api/health` passe de `{"statut":"ok"}` à `{"statut":"ok","base":"ok"}`. Pour un projet qui n'a **pas** de registre, `ebony add` en écrit un quand le module apporte un composant (la base), et une note dit les lignes à ajouter au service : `POUR TOUT oFabrique DE …Fabriques()`, puis `oApp.Ajoute(oFabrique)` et `FIN`. Si ce service crée déjà la base lui-même, retirez ces lignes : elle démarrerait deux fois.

### Un projet créé avec la 0.1.0

C'est le cas d'un projet créé avant le registre. Un projet `ebony new boutique --kit slim` de la 0.1.0 n'a pas de `app/Composants.owl`, et son `ebony/` est celui de la 0.1.0. `ebony add burin` le refuse (la bibliothèque n'est pas celle de l'Ebony installé) et `ebony upgrade` aussi tant que l'ancien `ebony/` est là : **supprimez le dossier `ebony/`** (Ebony ne supprime rien), lancez `ebony upgrade`, puis `ebony add burin`. Il réécrit alors `config/env.json`, `.env.exemple` et `.env.secrets.exemple` (ils étaient tels que la 0.1.0 les avait écrits), crée `app/Composants.owl` et dit d'y brancher le service : après avoir ajouté la boucle `POUR TOUT oFabrique DE AppBoutiqueFabriques()` à `FinInitialisation`, le service démarre avec la base (`GET /api/health` : `{"statut":"ok","base":"ok"}`).

## Pour un outil : `--json`

`ebony add burin --json` écrit une seule ligne :

```json
{"ok":true,"dir":"…","module":"burin","modules":["burin"],"base":"sqlite","files":["ebony/ (module burin)"],"updated":["config/env.json",".env.exemple",".env.secrets.exemple","app/Composants.owl","ebony.conf"],"kept":[],"notes":[],"next":["ebony env"]}
```

`files` : ce qui est créé ; `updated` : ce que Ebony a réécrit ; `kept` : ce que vous aviez modifié et qu'il n'a pas touché ; `notes` : ce que vous devez faire ; `next` : les commandes à lancer ensuite. En cas d'échec : `{"ok":false,"error":…}`.

## Ce qui n'est pas couvert

Pour **PostgreSQL ou HFSQL**, `ebony add` écrit les fichiers attendus, mais le parcours complet n'a été suivi que sur SQLite. Les options `--auth` et `--table` de `ebony new` n'ont pas d'équivalent : `ebony add auth` ajoute les jetons, pas la table des utilisateurs. `README.md` et `AGENTS.md` ne sont pas réécrits : ils parlent du kit d'origine.
