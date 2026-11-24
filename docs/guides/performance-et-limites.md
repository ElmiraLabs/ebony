# Performance : écrire des routes qui tiennent en production

Cette page donne les repères pour écrire des routes rapides avec `owl serve` (ou le binaire produit par `owl-build`). Ce qui est disponible ou non dans Ebony est dans [Où en est Ebony](statut-et-limites.md).

## Le service traite les requêtes une par une

Un service OWL sert une requête à la fois. Une requête qui en suit une autre attend la fin de la première. Un client lent ou muet (connexion ouverte, rien envoyé) ne bloque pas les autres.

Pour écrire des routes qui tiennent la charge :

- **Répondez vite.** Une route doit répondre en quelques millisecondes. Évitez les calculs longs, les attentes et les appels réseau sans délai maximal.
- **Sortez le travail long du handler.** Découpez-le, confiez-le à un autre processus, ou répondez tout de suite et traitez ailleurs.
- **Comptez la durée de chaque route.** Une route de 200 ms plafonne le service à environ 5 requêtes par seconde, quel que soit le nombre de clients.
- **Pas de verrou à prévoir.** Comme il n'y a jamais deux requêtes en même temps, un état partagé (la connexion à la base, des globales) n'a pas besoin d'être protégé. C'est le comportement actuel d'OWL : ne bâtissez pas votre code dessus pour toujours.

## Taille des corps

Un corps très gros (de l'ordre de 20 Mo) est refusé en `413` par défaut.

## Base de données

- **Gardez la connexion ouverte.** Ouvrir une connexion à chaque requête est lent, surtout avec PostgreSQL. Ouvrir la connexion une fois, au démarrage (`FinInitialisation`), et la fermer dans `Fermeture` est beaucoup plus rapide. C'est ce que fait le service généré.
- **Une connexion perdue est rétablie.** Si la base tombe puis revient, la connexion partagée de Burin vérifie la base, se rouvre et rejoue la requête une fois. Sinon, la route répond `503`. Voir la [configuration](configuration.md).
- **Écrivez vos écritures de façon idempotente quand c'est possible.** Une écriture dont la réponse s'est perdue peut avoir abouti sans que le client le sache, et être rejouée.

## Erreurs

Une exception non gérée dans une route donne un `500` et une trace dans le journal. Le service continue de servir les autres requêtes.
