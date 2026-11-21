# Les modules d'Ebony

Les fonctionnalités d'Ebony sont réparties en **modules**. Un module apporte du code d'exécution (écrit en OWL, préfixé `Eb`, copié dans le dossier `ebony/` de chaque projet généré) et des commandes (qui restent dans l'installation d'Ebony). Le cœur ne connaît pas les autres modules : chacun déclare ce qu'il apporte, et un contrôle automatique refuse qu'une frontière entre modules soit franchie.

## Les modules officiels

| Besoin | Module | État |
|---|---|---|
| Cycle de vie, configuration, journal, HTTP, commandes | `core` | Disponible |
| Jetons d'accès, routes protégées, `ebony token` | `auth` | Disponible |
| Connexion, migrations, repositories SQL | `burin` | Disponible pour le code d'exécution (connexion, dépôts) ; `ebony migrate` et `ebony make` restent dans l'outillage du cœur et refusent un projet sans ce module |
| Vérification de ce que le client envoie (le Poinçon) | `poincon` | Disponible, dans le kit `api` ; autonome : il ne dépend d'aucun autre module, pas même de la base |
| Fabriques et seeders | faits, sans commande `seed` | Disponible : `make resource` écrit une fabrique, `make seeder` un seeder et son lanceur (voir [make](make.md)) ; pas de commande `ebony seed` |

| Valeurs d'exemple réalistes | `figurant` | Disponible, facultatif (dans aucun kit) : `ebony add figurant` ; prénoms, noms, courriels, villes… déterministes, pour les fabriques et les seeders |

## Les kits

Un **kit** est la liste des modules qu'un projet reçoit à sa création : `ebony new <nom> --kit <kit>`. Le choix est noté dans `ebony.conf` (`"kit"` et `"modules"`), et `ebony restore` et `ebony upgrade` s'y tiennent : ils ne recopient que les modules du projet.

| Kit | Modules (en plus du cœur) | Pour qui |
|---|---|---|
| `api` (par défaut) | `burin`, `poincon`, `auth` | une API REST avec base de données, validation des corps de requête et jetons d'accès |
| `slim` | aucun | le cœur seul : un service REST sans base de données, sans variable `DB_*` ; `GET /api/health` répond `{"statut":"ok"}` |

Les kits `web`, `desktop` et `mobile` sont annoncés dans l'écosystème, sans date ni promesse : seul `api` (et son allégé `slim`) existe.

Un projet `slim` n'a pas le module `burin` : `ebony migrate` et `ebony make` le refusent (code 1) en nommant le module, et `ebony token` refuse de même sans `auth`. Le contrôleur que `ebony make resource` écrit appelle le Poinçon : la commande exige donc aussi le module `poincon` (code 53, qui dit « ebony add poincon »). Rien n'est écrit dans ces cas. Pour lui donner une base, la validation ou les jetons, `ebony add burin`, `ebony add poincon` puis `ebony add auth` (voir [Ajouter un module](ajouter-un-module.md)), ou créer le projet avec le kit `api`.

## Le manifeste d'un module

Un module peut joindre un **manifeste** (`ebony/modules/<nom>.json`) qui déclare, sans code : les variables d'environnement qu'il ajoute au schéma de configuration, les migrations qu'il fait écrire dans le projet, les fichiers qu'il ajoute, et ce qu'il ajoute aux routes générées. Les migrations et les fichiers écrits deviennent **ceux de votre projet**, qui en est propriétaire : Ebony ne les remplace plus.

## `core` : le cœur

- **Cycle de vie d'une application.** `cEbApplication` assemble la configuration, le journal et ses **composants** (la base de données en est un : le cœur ne connaît que le contrat `iEbComposant`). Le service généré la démarre dans `FinInitialisation` et l'arrête à la fermeture (l'arrêt est idempotent). `GET /api/health` renvoie 200, ou 503 si un composant (la base) ne répond pas ; un projet sans composant répond `{"statut":"ok"}`. Une configuration invalide arrête le démarrage (code 60) en listant **toutes** les erreurs.
- **Configuration.** `.env` et `.env.secrets` (non versionnés), contrôlés d'après un schéma de données, `config/env.json` (jamais du code exécuté). L'état de chaque variable (source, validité, erreur) est connu sans jamais exposer sa valeur. Voir [la configuration](configuration.md).
- **Journal.** Une ligne JSON par événement sur la sortie standard, pour la collecte par un hébergeur : niveaux `debug`, `info`, `warn`, `error`, champs triés, échappement correct, horodatage UTC à la seconde. Le seuil vient de `LOG_NIVEAU` (`info` par défaut). Aucun secret ne doit être écrit dans un message : le journal écrit tel quel ce qu'on lui donne.
- **HTTP.** Le contexte de requête, la réponse, des fabriques de réponses, les erreurs JSON standard (voir [les erreurs](erreurs.md)) et la sérialisation JSON.
- **Commandes.** `new`, `init`, `add`, `make`, `migrate`, `env`, `request`, `doctor`, `restore`, `upgrade`, `install`, `uninstall` : voir [la référence](commandes.md).

## `burin` : la base de données

Le module du kit `api` ; le kit `slim` ne l'a pas, et un projet sans lui démarre sans aucune variable `DB_*` (`GET /api/health` ne parle alors pas de base). La base est un **composant** de l'application : le service généré l'ajoute, le cœur ne connaît que le contrat `iEbComposant`.

- **Connexion SQL.** Une connexion partagée **résiliente** : si une requête échoue, elle sonde la base, rouvre la connexion perdue et **rejoue une fois** ; sinon elle répond « indisponible » (503). Une requête fausse n'est jamais rejouée. SQLite, PostgreSQL (niveau TLS réglable par `DB_TLS`) et HFSQL (connexion seulement : `migrate` le refuse). Une écriture dont la réponse s'est perdue peut être rejouée alors qu'elle avait abouti : écrivez les écritures de façon idempotente quand c'est possible.

## `poincon` : ce que le client envoie

Le module du kit `api` ; il s'ajoute seul à n'importe quel projet (`ebony add poincon`), avec ou sans base de données. Il **ne dépend d'aucun autre module** (un contrôle automatique le garantit), et aucun module ne dépend de lui : la base, les jetons et les valeurs d'exemple fonctionnent sans lui.

- **Les règles sont des données.** Le Poinçon lit `app/domaine/<dossier>/ressource.json` (écrit par `ebony make resource`, ensuite à vous) **à chaque `POST`, `PUT` ou `PATCH`** : l'obligation d'un champ (`nullable`, `defaut`), ses `regles` (longueurs, bornes, valeurs permises, motif) et le format ISO 8601 des dates. Modifier le fichier prend effet à la requête suivante.
- **Une seule réponse 422** qui nomme tout ce qui ne va pas. Une description fautive (règle inconnue, mauvais type de valeur) est une erreur 500 journalisée, jamais ignorée en silence.
- **Où est le code.** `ebony/poincon/` : `EbPoincon.owl` (le contrôle, sans disque : le JSON passé en argument) et `EbCorpsRequete.owl` (la reconnaissance d'un champ **absent** d'un corps REST, par des valeurs sentinelles). Les dates ISO 8601 sont dans le cœur (`EbDatesIso`), parce que les listes de Burin s'en servent aussi.
- **Ce qui le lie encore au REST.** `EbCorpsRequete.owl` ne sert qu'aux corps JSON des routes ; le contrôle lui-même ne connaît ni la requête ni la base, pour pouvoir valider aussi les données d'une application de bureau.

Les règles, leur vocabulaire et les limites sont décrits dans [les routes générées](make.md).

## `figurant` : des valeurs d'exemple réalistes

Module **facultatif** (il n'est dans aucun kit) pour un projet qui a `burin` : `ebony add figurant` copie `ebony/figurant/` et l'inscrit dans `ebony.conf`. Une fois ajouté, `ebony make seeder` écrit son générateur (`cEbGenerateurFigurant(42)`) dans le lanceur à la place du compteur : rien à changer à la main. Il apporte `cEbGenerateurFigurant(graine)`, que l'on passe à une [fabrique](make.md) ou à un seeder à la place du générateur à compteur :

```
oFabrique est une cFabriqueClient(cEbGenerateurFigurant(42))
```

Les valeurs ressemblent à de vraies données : le **nom de la colonne** décide (`prenom`, `nom`, `email`, `telephone`, `ville`, `pays`, `adresse`, `code_postal`, `societe`, `description`…), et un prénom, un nom et un courriel d'une même ligne vont ensemble (`melissa.mercier1@example.com`). Elles sont **déterministes** : la même graine donne les mêmes valeurs d'un lancement à l'autre et sous Windows comme sous Linux (la suite n'utilise que des entiers ; `Hasard` d'OWL, lui, rend des suites différentes selon la plate-forme). Les téléphones sont dans la plage fictive `01 99 00 xx xx`.

Pour dire ce qu'un texte représente, écrivez une **sorte** dans `--champs` : `nom:texte~produit` (un nom de produit), `prenom:texte~prenom-feminin` ou `~prenom-masculin` (un prénom du bon genre), `~nom-de-famille`, `~courriel`, `~ville`… (voir [make](make.md)). Sans sorte, le nom de la colonne est lu comme ci-dessus, et un champ `nom` y est un nom de famille.

Limites : les clés étrangères ne sont pas valides d'office (fixez-les avec `CreeAvec`) ; les listes de prénoms, de noms et de villes sont courtes (une soixantaine de prénoms, de noms, une quarantaine de villes). Disponible sous Windows et sous Linux.
## `auth` : l'authentification

- **Jetons d'accès « opaques ».** Un jeton est un secret aléatoire de 32 octets en Base64 URL, précédé de `eb_` (ce n'est pas un JWT). **Le secret n'est affiché qu'une fois**, à la création : la base ne garde que son empreinte SHA-256, donc lire la base ne permet pas de s'en servir. Un secret perdu se remplace (révoquer, puis en créer un autre).
- **La commande `ebony token`.** `create <nom> [--expire AAAA-MM-JJ]` (sans option, le jeton n'expire pas), `list` (jamais le secret ; état `actif`, `expiré` ou `révoqué`), `revoke <identifiant>`.
- **Routes protégées par défaut.** Le contrôleur généré par `make resource` exige un jeton valable dans `Authorization: Bearer …` : sans lui, 401, avant la route. `AUTH_ROUTES=ouvertes` dans `.env` ouvre les routes (développement ou API publique). Le nom du jeton est lisible dans une route (`MoiMême..Requête..Identité`). Une route que vous ajoutez au contrôleur hérite de la protection.
- **La table `eb_jetons`** vient de la migration que le module fait écrire dans `database/migrations/` (`ebony new` et `ebony init`), jouée par `ebony migrate`. `--auth --table <table>` écrit en plus `config/Auth.owl` (la table des utilisateurs et le mode de jeton, à vous) et, dans un projet neuf, la migration de la table des utilisateurs (`identifiant`, `mot_de_passe`, `role`).
- **Ce sont des jetons d'accès pour des clients et des applications, pas une connexion d'utilisateur** : il n'y a pas encore de connexion par mot de passe, de session, de rôles ni de récupération de compte. OWL n'a pas de hachage lent : un hachage rapide suffit pour un secret aléatoire de 256 bits, pas pour un mot de passe.
