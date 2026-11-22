# Les modules d'Ebony

Les fonctionnalités d'Ebony sont réparties en **modules**. Un projet ne reçoit que ceux dont il se sert : leur code est copié dans le dossier `ebony/` du projet, et leurs commandes restent dans l'installation d'Ebony.

## Les modules disponibles

| Module | Ce qu'il apporte | Dans le kit `api` |
|---|---|---|
| `core` | le cycle de vie, la configuration, le journal, les réponses HTTP, les commandes de base | oui (toujours) |
| `burin` | la connexion à la base, les repositories SQL, les migrations (`ebony migrate`), `ebony make` | oui |
| `poincon` | la validation de ce que le client envoie, d'après `ressource.json` | oui |
| `auth` | les jetons d'accès, les routes protégées, `ebony token` | oui |
| `figurant` | des valeurs d'exemple réalistes (prénoms, noms, villes…) pour les fabriques et les seeders | non : `ebony add figurant` |

## Les kits

Un **kit** est la liste des modules qu'un projet reçoit à sa création : `ebony new <nom> --kit <kit>`. Le choix est noté dans `ebony.conf`.

| Kit | Modules (en plus du cœur) | Pour qui |
|---|---|---|
| `api` (par défaut) | `burin`, `poincon`, `auth` | une API REST avec base de données, validation et jetons d'accès |
| `slim` | aucun | le cœur seul : un service REST sans base de données, dont `GET /api/health` répond `{"statut":"ok"}` |

Les kits pour le web, le bureau et le mobile ne sont pas encore disponibles.

Un projet `slim` n'a pas de base : `ebony migrate` et `ebony make` refusent de s'y exécuter, et le message nomme le module manquant. Pour lui donner une base, la validation ou les jetons, ajoutez les modules (`ebony add burin`, `ebony add poincon`, `ebony add auth`) : voir [Ajouter un module](ajouter-un-module.md). Ou créez le projet avec le kit `api`.

## `core` : le cœur

- **Cycle de vie.** L'application démarre dans `FinInitialisation` et s'arrête à la fermeture. `GET /api/health` répond 200, ou 503 si la base ne répond pas.
- **Configuration.** `.env` et `.env.secrets`, contrôlés d'après un schéma. Une configuration invalide arrête le démarrage en listant toutes les erreurs. Voir [la configuration](configuration.md).
- **Journal.** Une ligne JSON par événement sur la sortie standard. Le seuil vient de `LOG_NIVEAU` (`info` par défaut). Voir [le journal](journalisation.md).
- **HTTP.** Le contexte de requête, la réponse, les erreurs JSON standard (voir [les erreurs](erreurs.md)).
- **Commandes.** `new`, `init`, `add`, `env`, `request`, `doctor`, `restore`, `upgrade`, `install`, `uninstall` : voir [la référence](commandes.md).

## `burin` : la base de données

Burin est le module qui parle à la base. Le kit `slim` ne l'a pas, et un projet sans lui démarre sans aucune variable `DB_*`.

- **Connexion.** Une connexion partagée qui se rétablit toute seule : si une requête échoue, elle vérifie la base, rouvre la connexion perdue et rejoue la requête une fois. Si la base reste injoignable, la route répond 503.
- **Bases.** SQLite et PostgreSQL pour les migrations et les ressources. Avec HFSQL, Burin se connecte, mais ne génère ni migrations ni ressources (voir [la compatibilité](compatibilite.md)).
- **Commandes.** `ebony migrate`, et `ebony make` (voir [make](make.md)).

## `poincon` : la validation

Le Poinçon vérifie ce que le client envoie. Il s'ajoute seul à n'importe quel projet (`ebony add poincon`), avec ou sans base de données.

- **Les règles sont des données.** Il lit `app/domaine/<dossier>/ressource.json` à chaque `POST`, `PUT` ou `PATCH` : champs obligatoires, valeurs par défaut, longueurs, bornes, valeurs permises, motif, format des dates. Modifier le fichier prend effet à la requête suivante.
- **Une seule réponse** (422) qui nomme tout ce qui ne va pas.

Le détail des règles est dans [la description d'une ressource](ressource-json.md).

## `figurant` : des valeurs d'exemple réalistes

Module facultatif, pour un projet qui a `burin` : `ebony add figurant`. Ensuite, `ebony make seeder` l'utilise tout seul. Il apporte `cEbGenerateurFigurant(graine)`, que l'on passe à une fabrique à la place du générateur par défaut :

```owl
oFabrique est une cFabriqueClient(cEbGenerateurFigurant(42))
```

Les valeurs ressemblent à de vraies données : le nom de la colonne décide (`prenom`, `nom`, `email`, `telephone`, `ville`, `pays`, `adresse`, `code_postal`, `societe`…), et un prénom, un nom et un courriel d'une même ligne vont ensemble. Elles sont **reproductibles** : la même graine donne les mêmes valeurs à chaque lancement, sous Windows comme sous Linux. Les numéros de téléphone sont dans une plage fictive (`01 99 00 xx xx`).

Pour dire ce qu'un texte représente, ajoutez une **sorte** dans `--champs` : `nom:texte~produit`, `prenom:texte~prenom-feminin`, `~nom-de-famille`, `~courriel`, `~ville`… Voir [make](make.md).

À savoir : les clés étrangères ne sont pas valides d'office (fixez-les avec `CreeAvec`), et les listes de prénoms, de noms et de villes sont courtes.

## `auth` : les jetons d'accès

- **Des jetons opaques.** Un jeton est un secret aléatoire préfixé `eb_`. Il n'est affiché qu'une fois, à sa création : la base n'en garde que l'empreinte, donc lire la base ne permet pas de s'en servir. Un secret perdu se remplace (révoquez, puis créez-en un autre).
- **La commande `ebony token`** : `create <nom> [--expire AAAA-MM-JJ]` (sans option, le jeton n'expire pas), `list` (jamais le secret) et `revoke <identifiant>`. Voir [token](token.md).
- **Routes protégées par défaut.** Les routes générées exigent un jeton dans `Authorization: Bearer …` : sans lui, la réponse est un 401. `AUTH_ROUTES=ouvertes` dans `.env` les ouvre, pour le développement. Une route que vous ajoutez au contrôleur hérite de la protection.
- **La table `eb_jetons`** vient de la migration que le module écrit dans `database/migrations/` ; `ebony migrate` la crée.

Ce sont des jetons d'accès pour des clients et des applications. La connexion d'un utilisateur par mot de passe, les sessions et les rôles ne sont pas encore là.

## Le manifeste d'un module

Un module peut joindre un manifeste (`ebony/modules/<nom>.json`) qui déclare, sans code : les variables qu'il ajoute à la configuration, les migrations et les fichiers qu'il fait écrire, et ce qu'il ajoute aux routes générées. Les fichiers écrits deviennent ceux de votre projet : Ebony ne les remplace jamais.
