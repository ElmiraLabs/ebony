# Statut et limites d'Ebony

Cette page dit ce qui manque à **Ebony**. Les limites du serveur d'OWL lui-même (une requête à la fois, tailles, connexion à la base) sont dans [Limites d'OWL et performance](performance-et-limites.md).


Ebony 0.1.5 est une **préversion**. À savoir avant de l'adopter :

- **Une requête à la fois.** Un service OWL traite les requêtes une par une (quatre requêtes d'une seconde envoyées ensemble prennent environ quatre secondes) : ne l'exposez pas à une charge imprévisible. OWL n'a ni thread ni asynchrone.
- **Bases** : SQLite et PostgreSQL 16 pour `ebony migrate` ; HFSQL est refusé pour les migrations et pour ebony make resource (le repository est écrit avec Burin, qui n'a pas encore de dialecte HFSQL).
- **Modules** : `burin`, `poincon` et `auth` (dans le kit `api`), et `figurant` (facultatif, des valeurs d'exemple pour les seeders : `ebony add figurant`) ; il n'en existe pas d'autre. `ebony add` en ajoute un à un projet ; il n'y a pas de commande pour en retirer un, ni de modules tiers, et `add` n'est couvert qu'avec SQLite (voir [Ajouter un module](ajouter-un-module.md)).
- **Authentification** : des jetons d'accès pour des clients ; pas de connexion d'utilisateur (mot de passe, session, rôles).
- **Le corps d'une requête** : `POST` et `PUT` exigent les champs qui n'acceptent pas NULL, `PATCH` ne change que ceux qu'il envoie ; **un champ du mauvais type** (`"prix":"abc"`) devient 0 ou le texte vide sans erreur, et une décimale envoyée pour un entier est tronquée (limites de la liaison d'OWL ; voir [le corps d'une requête](architecture.md#le-corps-dune-requête--absent-présent-partiel)).
- **Liste paginée, filtres d'égalité seulement** : la liste générée rend une page (`page`, `limite`, `tri`, `ordre`, `filtre_<colonne>` : voir [make.md](make.md)) ; pas d'intervalle, de recherche dans une partie de texte ni de tri sur plusieurs colonnes. Le dépôt en mémoire (tests) trie par insertion : il n'est pas fait pour de grosses listes.
- **Validation par règles simples** : le Poinçon contrôle l'obligation, les longueurs, les bornes, les valeurs permises, un motif (expression régulière non ancrée : une faute de syntaxe y est indétectable) et le format ISO 8601 des dates, d'après `ressource.json` ; rien entre deux champs, et un champ du mauvais type devient 0 ou le texte vide sans erreur (limite d'OWL).
- **Document OpenAPI** : `ebony openapi` décrit les routes générées d'après `ressource.json` ; les routes écrites à la main n'y figurent pas, et il a été validé par le lint de Redocly CLI (deux avertissements de recommandation) ; voir [les commandes](commandes.md#openapi).
- **Clés étrangères** : l'application demande à SQLite de les vérifier (`PRAGMA foreign_keys = ON` à chaque ouverture de sa connexion : il est éteint par défaut), comme PostgreSQL le fait toujours. Une ligne qui vise une ligne absente, ou qu'on supprime alors qu'une autre la vise, donne **409 `conflit`** (message fixe, sans le texte de la base). Limites : une base SQLite ouverte par un autre outil ne les vérifie pas ; les tests générés des repositories (SQLite en mémoire, une table seule) ne les vérifient pas non plus.
- **Fabriques** : `make resource` écrit une fabrique d'entités d'exemple (valeurs déterministes, voir [make](make.md)). **Seeders** : `make seeder` écrit le seeder d'une ressource et un lanceur (`owl database/seeders/DatabaseSeeder.owl --seed`, refusé hors `APP_ENV=developpement` ou `test`). **Pas encore** : commande `ebony seed`, routes déclarées dans un fichier à la AdonisJS, pages web, bureau, mobile. Ce qui est utilisable aujourd'hui est le projet API décrit plus haut.
- **Plateformes** : Windows ; Linux (`install.sh` à la place d'`ebony install`).
- **Lenteur au lancement** : une commande `ebony` prend 1 à 7 secondes depuis l'archive ou une copie installée, mais 20 à 25 secondes depuis un clone tant que les points d'entrée réduits n'ont pas été générés : OWL analyse tout le projet à chaque lancement.

