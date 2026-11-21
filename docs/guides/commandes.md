# Référence des commandes

`ebony aide` liste toutes les commandes. Ce guide donne, pour chacune, ce qu'elle fait, ses options et ses sorties. Les commandes qu'un outil (un IDE, un script) doit lire ont une option `--json`.

## Les commandes

| Commande | Ce qu'elle fait |
|---|---|
| `ebony new <nom>` | crée un **projet API** dans un nouveau dossier : `ebony.conf`, `projet.owl`, `config/env.json`, `.gitignore`, `README.md`, `AGENTS.md` (consignes pour un assistant de code : conventions, où écrire quoi, pièges d'OWL), un **service REST** (`app/http/Service<Nom>.owl`) et `ebony/` (la bibliothèque d'exécution). Options : `--kit api\|slim` (voir [les kits](modules.md#les-kits) ; `api` par défaut), `--base sqlite\|postgresql\|hfsql` (HFSQL : connexion seulement, sans migrations), `--auth [--table utilisateurs\|users]`, `--json`. Avec `--kit slim`, il n'y a ni base ni authentification : `--base` et `--auth` sont refusés (code de sortie 2) en disant d'utiliser le kit `api`. Le projet compile, démarre sous `owl serve`, et `owl test` y fonctionne. |
| `ebony init` | ajoute Ebony à un projet OWL existant, sans rien écraser (mêmes options que `new`, pas de nom). |
| `ebony add <module>` | ajoute un module (`burin`, `poincon`, `auth`, `figurant`) au projet du dossier courant : `--base sqlite`, `postgresql` ou `hfsql` (pour `burin`), `--json`. Réécrit seulement les fichiers qu'Ebony a écrits et que vous n'avez pas modifiés : voir [Ajouter un module](ajouter-un-module.md). |
| `ebony make resource <Nom> --champs …` | écrit l'entité, les repositories (SQL et mémoire), le service, les tests, le contrôleur et la description (`ressource.json`) d'une table. `--table <table>`, `--dry-run` (dit ce qui serait écrit), `--json`. Ne remplace jamais un fichier : relancée, elle conserve les fichiers existants. |
| `ebony make migration <Nom> [--champs …]` | écrit la migration qui crée une table. Mêmes options. Sans `--champs`, les champs viennent de la description (`ressource.json`) que `make resource` a écrite pour cette table. |
| `ebony make seeder <Nom>` | écrit le seeder d'une ressource déjà générée (classe, test) et, une fois, le lanceur `database/seeders/DatabaseSeeder.owl`. `--dry-run`, `--json` (pas de `--champs` ni de `--table`). Le remplissage se lance avec `owl database/seeders/DatabaseSeeder.owl --seed` : voir [make](make.md). |
| `ebony openapi [--sortie <fichier>] [--remplace]` | écrit le document **OpenAPI 3.0.3** de l'API (dans le fichier de `--sortie`, sinon sur la sortie standard), d'après les descriptions `app/domaine/*/ressource.json` (module `burin`). Voir [`openapi`](#openapi). |
| `ebony migrate` | applique les migrations en attente, une transaction chacune. `status`, `rollback [--pas N]`, `--dry-run`, `--json`. SQLite et PostgreSQL 16. |
| `ebony token create \| list \| revoke` | gère les jetons d'accès (module `auth`). |
| `ebony env` | examine la configuration du projet sans le démarrer ; jamais la valeur d'un secret. `--json`. |
| `ebony request GET /chemin` | envoie une requête HTTP à un service en cours d'exécution : `--header Nom:valeur`, `--body texte`, `--port N` ou `--url adresse`, `--json`. |
| `ebony doctor` | vérifie l'environnement : accès au dossier de lancement, installation lisible, écriture, version d'OWL, état du projet. `--json`. |
| `ebony restore` | restaure `ebony/` dans un projet cloné avec git, d'après la version **minimale** notée dans `ebony.conf` (comme `^1.2.0` dans un `package.json`). |
| `ebony upgrade` | aligne `ebony/` et `ebony.conf` sur l'ebony installé, puis signale les variables de configuration que les modules du projet attendent et que `config/env.json` ne déclare pas (il ne les ajoute pas). Ni `restore` ni `upgrade` ne supprime ni ne rétrograde rien. |
| `ebony install`, `ebony uninstall` | installe Ebony pour l'utilisateur et l'ajoute au PATH, ou le retire (Windows). Voir [l'installation](installation.md). |
| `ebony --version` | une ligne `ebony X.Y.Z`. |

## `make` : la grammaire de `--champs`

`nom:type[*][?][@table[.colonne]]`, séparés par des virgules. Exemple : `id:entier*,nom:texte,email:texte?,client:entier@clients.id`.

| Élément | Sens |
|---|---|
| types | `entier`, `texte`, `reel`, `booleen`, `date`, `dateheure` |
| `*` | clé primaire (pour un entier : générée par la base) |
| `?` | la colonne accepte NULL |
| `@table.colonne` | clé étrangère |

OWL ignore silencieusement certains mots comme noms de membre d'une structure (`liste`, `fin`, `est`, `et`, `ou`, `pas`, `tout`, `local`, `global`, `null`…) : si une colonne porte un de ces noms, `make resource` n'écrit pas le contrôleur et le dit dans une note.

## `migrate`

```text
ebony migrate [--dry-run] [--json]                      applique les migrations en attente, dans l'ordre
ebony migrate status [--json]                           liste les migrations et leur état
ebony migrate rollback [--pas N] [--dry-run] [--json]   défait la dernière migration appliquée (ou les N dernières)
```

- Les migrations sont les fichiers `database/migrations/M<horodatage>_<Intention>.owl`. L'ordre est celui des noms.
- **Ebony lit le SQL dans le fichier, il n'exécute pas la classe.** Il reconnaît la forme que `make migration` écrit (une instruction par `TableauAjoute(tabSql, …)`, puis `RENVOYER tabSql`). Une migration qui calcule son SQL (concaténation, condition, appel) est **refusée**, jamais appliquée à moitié. Pour ajouter une colonne à la main, écrivez une migration de cette forme.
- **Une migration = une transaction** : si une instruction est refusée, tout est annulé, les migrations précédentes restent appliquées et la commande s'arrête (code 1).
- Le suivi est la table `eb_migrations`. `status` liste `applied`, `pending` ou `missing` (appliquée, mais son fichier n'est plus dans le projet).
- Une migration appliquée dont vous modifiez le fichier après coup n'est pas détectée. Deux `migrate` simultanés sur la même base ne sont pas protégés l'un de l'autre.
- PostgreSQL : version 16 couverte ; en local sans TLS, écrivez `DB_TLS=desactive` dans `.env` (voir [la configuration](configuration.md)).

## `openapi`

```text
ebony openapi --sortie openapi.json [--remplace]
ebony openapi                          le document sur la sortie standard
```

À lancer dans le dossier d'un projet qui a le module `burin` et au moins une ressource décrite (`make resource` écrit `app/domaine/<dossier>/ressource.json`). Le document est écrit sur la sortie standard, rien n'est écrit sur le disque ; hors d'un projet ebony ou sans le module `burin`, la commande le dit et rend le code 1 ; sans aucune description, ou avec une description incorrecte (le message nomme le fichier), elle rend le code 2.

- **Ce qu'il décrit** : `GET /api/health`, puis pour chaque ressource les six routes que `make resource` génère : liste paginée (`page`, `limite`, `tri`, `ordre`, un `filtre_<colonne>` par colonne), création, lecture, remplacement, modification partielle, suppression, avec leurs codes de réponse (400, 404, 409, 503, 500) et le format d'erreur `{ "code", "message" }`.
- **Les schémas viennent de `ressource.json`** : type et format de chaque champ, `nullable`, clé générée en lecture seule, référence vers une autre table, `default`, et les règles du Poinçon en `minLength`, `maxLength`, `pattern`, `minimum`, `maximum`, `enum`. Trois schémas par ressource : la ressource (lecture), `<Nom>Corps` (corps d'un `POST` ou d'un `PUT` : sans la clé générée, obligatoires = ni NULL ni défaut) et `<Nom>Partiel` (corps d'un `PATCH` : rien d'obligatoire). Une règle qui ne s'exprime pas pour le type du champ est omise.
- **La sécurité** : si un module du projet déclare un garde à jeton Bearer (c'est le cas d'`auth`), le document décrit un schéma `bearerAuth` exigé partout sauf `/api/health`, avec `401` sur chaque opération de ressource. `AUTH_ROUTES=ouvertes`, dans `.env`, ouvre les routes à l'exécution : le document décrit la configuration par défaut.
- **Ce qu'il ne décrit pas** : l'accueil `GET /api`, les routes que vous écrivez à la main, ni une modification faite à la main dans un contrôleur ; seul ce que dit `ressource.json` est décrit. Le titre est le nom du projet, la version `1.0.0` et le serveur `http://127.0.0.1:8080` (`owl serve` par défaut) : à modifier dans le fichier si besoin.
- **Enregistrer le document** : utilisez **`--sortie`**, qui écrit le fichier en UTF-8 sans BOM (fins de ligne LF) quel que soit le terminal. La redirection est un piège sous Windows : **dans Windows PowerShell 5.1, `ebony openapi > openapi.json` écrit en UTF-16**, que les outils OpenAPI refusent (« null byte is not allowed in input »). Sous Windows, `>` écrit `FF FE` et des octets nuls, `| Out-File -Encoding utf8` donne un BOM UTF-8 (accepté par Redocly), `cmd /c "… > f"` donne du JSON sans BOM ; dans `cmd` et sous Linux, `>` convient.
- **Licence** : le document déclare la licence `MIT` (`info.license`), choix par défaut d'Ebony ; si votre API en a une autre, changez-la dans le fichier.
- **Contrôle** : le document d'un projet de deux ressources (clé entière, avec jeton) passe le lint de Redocly CLI 2.79.0 (`npx @redocly/cli lint openapi.json`) : valide, avec deux avertissements de recommandation (le document n'avait pas encore de `license`, qu'il porte maintenant ; pas de réponse `4XX` pour `GET /api/health`). Le lint n'a pas été relancé depuis l'ajout de la licence.
- Ebony écrit ce document lui-même parce qu'il ne peut pas lancer `owl openapi` (OWL ne sait pas lancer un programme avec ses arguments et en lire la sortie), et que ce dernier ne décrit ni les corps de requête ni la réponse de la liste.

## `token`

```text
ebony token create <nom> [--expire AAAA-MM-JJ] [--json]   crée un jeton et l'affiche une seule fois
ebony token list [--json]                                 liste les jetons (jamais leur secret)
ebony token revoke <identifiant> [--json]                 révoque un jeton
```

À lancer dans le dossier d'un projet. Le détail du fonctionnement est dans [les modules](modules.md#auth--lauthentification). Un `--expire` vaut jusqu'à la fin du jour indiqué, en UTC ; une date passée est refusée. Révoquer deux fois, ou un identifiant inconnu, donne le code 1.

## Utiliser Ebony depuis un outil

- `ebony --version` : une ligne `ebony X.Y.Z`, code 0.
- `ebony doctor --json` : un seul objet JSON sur la sortie standard, rien d'autre :
  `{"ok":true,"ebony":"0.1.5","owl":"1.9.0","checks":[{"id":"acces-dossier","status":"ok","label":"…","message":"…","correction":""}],"errors":0,"warnings":0}`.
  `status` vaut `ok`, `warning` ou `error` ; `ok` est faux dès qu'il y a une erreur (un avertissement ne le change pas). Identifiants stables, dans l'ordre : `acces-dossier`, `installation`, `ecriture`, `version-owl`, `etat-projet`.
- Les commandes `make`, `migrate`, `token`, `env`, `new` et `request` rendent, avec `--json`, **une seule ligne JSON**. En cas d'échec : `{"ok":false,"error":"…"}`.

### Codes de sortie

| Code | Sens |
|---|---|
| 0 | réussite (un avertissement de `doctor` ne change pas le code) |
| 1 | échec de la commande (dont une erreur de `doctor`) |
| 2 | usage incorrect : commande inconnue, argument ou option manquant ou inconnu |
| 70 | erreur interne |

Un échec affiche une seule ligne `ebony : <cause>`, jamais une pile d'appels. Le lanceur `ebony.cmd` rend ces codes grâce à un petit fichier temporaire : OWL ne sait pas donner de code de sortie.

**Durée.** Chaque lancement d'`ebony` coûte quelques secondes tant qu'OWL analyse tout le projet : 1 à 7 secondes depuis l'archive ou une copie installée, 20 à 25 secondes depuis un clone tant que les points d'entrée réduits n'ont pas été générés. Un outil qui appelle `ebony` doit le faire en arrière-plan et garder le résultat.
