# Où en est Ebony

Ebony 0.1.5 est une **préversion** : elle crée des API REST pour OWL. Cette page dit ce qui est disponible, ce qui ne l'est pas encore, et les pièges à connaître avant de l'adopter.

## Disponible

- **Bases de données** : SQLite et PostgreSQL pour les migrations et les ressources. Avec HFSQL, Ebony se connecte à la base, mais ne génère ni migrations ni ressources.
- **Modules** : `burin` (base de données), `poincon` (validation) et `auth` (jetons) dans le kit `api`, et `figurant` (valeurs d'exemple), facultatif. `ebony add` ajoute un module à un projet : voir [Ajouter un module](ajouter-un-module.md).
- **Routes générées** : les six routes REST d'une ressource, avec une liste paginée, triée et filtrable : voir [les routes générées](routes-generees.md).
- **Validation** : le Poinçon contrôle l'obligation, les longueurs, les bornes, les valeurs permises, un motif et le format des dates, d'après `ressource.json` : voir [la description d'une ressource](ressource-json.md).
- **Jetons d'accès** pour les clients, avec des routes protégées par défaut : voir [token](token.md).
- **Clés étrangères** : une ligne qui vise une ligne absente, ou qu'on supprime alors qu'une autre la vise, donne un `409 conflit`.
- **Fabriques et seeders** : `make resource` écrit une fabrique d'entités d'exemple, `make seeder` un seeder et son lanceur (refusé hors `APP_ENV=developpement` ou `test`).
- **OpenAPI** : `ebony openapi` décrit les routes générées : voir [les commandes](commandes.md#openapi).
- **Plateformes** : Windows et Linux : voir [Ebony sous Linux](linux.md) et la [compatibilité](compatibilite.md).

## Pas encore disponible

- **La connexion d'un utilisateur** : mot de passe, session, rôles et récupération de compte.
- **Un fichier de routes déclaratif**, à la AdonisJS : les routes sont celles du contrôleur généré.
- **Les filtres autres que l'égalité exacte** (intervalles, parties de texte), la recherche dans plusieurs colonnes et le tri sur plusieurs colonnes.
- **HFSQL** pour les migrations et les ressources.
- **Une commande `ebony seed`**, des modules tiers, et la suppression d'un module d'un projet.
- **Le téléversement de fichiers, l'envoi d'e-mails et la limitation de débit.**
- **Les applications web, de bureau et mobile.**

## Pièges courants

- **Un champ du mauvais type devient 0 ou un texte vide.** `"prix":"abc"` n'est pas refusé : il est lu comme 0, et une décimale envoyée pour un entier est tronquée. Voir [la description d'une ressource](ressource-json.md).
- **Le service traite les requêtes une par une.** Une route lente retarde les suivantes : voir [Performance](performance-et-limites.md).
- **Les clés étrangères sous SQLite** ne sont vérifiées que par l'application : une base ouverte par un autre outil ne les vérifie pas. Les tests générés des repositories (SQLite en mémoire, une table seule) ne les vérifient pas non plus.
- **`ebony openapi` ne décrit que les routes générées** : celles que vous écrivez à la main n'y figurent pas.
- **Le lancement d'une commande prend quelques secondes** : OWL analyse tout le projet à chaque lancement.
- **Le dépôt en mémoire des tests** trie par ordre d'insertion : il n'est pas fait pour de grosses listes.
