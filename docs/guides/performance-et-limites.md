# Limites d'OWL et performance

Cette page décrit ce que **le serveur d'OWL** (`owl serve`, ou le binaire produit par `owl-build`) permet ou non, pour écrire des routes qui tiennent en production. Les limites **d'Ebony** (modules, authentification, validation, bases, plateformes) sont dans [Statut et limites d'Ebony](statut-et-limites.md).

Les chiffres ci-dessous sont des ordres de grandeur, mesurés sur un service minimal à deux routes (l'une attend une seconde, l'autre répond tout de suite) : ils servent à comprendre le comportement, pas à promettre un débit. Ils sont à refaire à chaque nouvelle version d'OWL.

## 1. Les requêtes sont servies une par une

OWL ne traite qu'une requête à la fois.

| Situation | Résultat mesuré |
|---|---|
| 4 requêtes d'une seconde, envoyées ensemble | environ 4 s au total |
| 1 requête d'une seconde, seule | environ 1 s |
| requête immédiate envoyée pendant une requête d'une seconde | environ 0,9 s (elle attend la fin de la lente) |
| client lent ou muet (connexion ouverte, rien envoyé) | ne bloque **pas** les autres |

**Aucune concurrence n'est promise.** Conséquences pour vos routes :

- Un handler doit répondre en quelques millisecondes. Évitez les calculs longs, les attentes et les appels réseau sans délai maximal.
- Un travail long ne se fait pas dans un handler : découpez-le, confiez-le à un autre processus, ou répondez tout de suite et traitez-le ailleurs.
- La durée d'une requête retarde toutes les suivantes : une route à 200 ms plafonne le service à environ 5 requêtes par seconde, quel que soit le nombre de clients.
- Un état partagé (la connexion à la base, des globales) n'a pas besoin de verrou, puisqu'il n'y a jamais deux requêtes en même temps. C'est le comportement actuel d'OWL, pas un contrat : ne le supposez pas pour toujours.

## 2. Taille des corps

Un corps de 20 Mo est refusé en `413` par défaut.

## 3. Base de données

- **Ouvrir une connexion à chaque requête** coûte cher : environ 40 requêtes par seconde avec PostgreSQL (l'authentification SCRAM prend environ 25 ms).
- **Ouvrir la connexion une fois**, au démarrage (`FinInitialisation`), et la fermer dans `Fermeture` : environ 400 à 700 requêtes par seconde.
- Les erreurs d'entrée-sortie d'OWL sont « douces » : `Succès` vaut faux, sans exception. Une connexion partagée ne se rétablit pas seule après un arrêt de la base. Ebony utilise `cEbBaseResiliente` (module `burin`) : elle vérifie la connexion, la rouvre, rejoue la requête une fois, sinon répond « indisponible » (traduit en `503`). Voir la [configuration](configuration.md).
- **Une écriture dont la réponse s'est perdue** peut avoir abouti sans que le client le sache, et être rejouée : écrivez vos requêtes d'écriture de façon idempotente quand c'est possible.

## 4. Erreurs

Une exception non gérée dans un handler donne un `500` et une trace sur la sortie standard. Le processus continue de servir les autres requêtes. Voir [les erreurs](erreurs.md).

## Ce qui n'est pas fait

- Pas de contrôle automatique des appels bloquants dans un handler : c'est à vous de les éviter.
