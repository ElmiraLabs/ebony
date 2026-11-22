# Comment une requête traverse un projet Ebony

Ce guide explique ce qui se passe entre l'arrivée d'une requête HTTP et la réponse, et **où écrire quoi** dans un projet généré par `ebony new` et `ebony make resource`. Les exemples viennent de la ressource `Produit` des [premiers pas](premiers-pas.md).

## Le chemin d'une requête

```text
Requête HTTP                GET /api/produits       Authorization: Bearer eb_…
      │
      ▼
owl serve                   monte tous les services OWL du projet
      │                     (ServiceBoutique, ControleurProduit…)
      ▼
surAuthentification         jeton valable ?  non → 401, la route n'est pas appelée
      │
      ▼
Route (OpérationHTTP)       ListeProduit, CreeProduit… : lit le chemin et le corps,
      │                     vérifie ce que le client envoie (422)
      ▼
Service métier              cServiceProduit : les règles de l'application
      │                     (ne connaît ni HTTP ni SQL)
      ▼
Repository                  iRepoProduit : cRepoProduitSql (application)
      │                                    cRepoProduitMemoire (tests)
      ▼
Base de données             SQLite ou PostgreSQL, par une connexion partagée
```

Au retour, le résultat devient une réponse JSON. Si une exception est levée à n'importe quel étage, la route l'attrape, la traduit en code HTTP et répond `{"code":"…","message":"…"}` : voir [les erreurs](erreurs.md). Une exception que la route n'a pas attrapée devient une réponse 500, sans rien révéler d'interne.

## Les couches et leurs responsabilités

| Couche | Fichier généré | Elle fait | Elle ne fait pas |
|---|---|---|---|
| **Route** (contrôleur) | `app/http/produit/ControleurProduit.owl` | déclare les routes, lit le chemin et le corps, vérifie ce que le client envoie, répond en JSON | pas de règle métier, ne parle jamais au repository |
| **Service** | `app/services/produit/cServiceProduit.owl` | porte les règles métier (« un produit inactif ne peut pas être commandé ») | ne sait rien du HTTP ni du SQL |
| **Repository** | `app/donnees/produit/cRepoProduitSql.owl`, `cRepoProduitMemoire.owl` | lit, ajoute, modifie, supprime : le seul endroit qui parle à la base | pas de règle métier |
| **Entité** | `app/domaine/produit/cProduit.owl` | un objet de l'application (champs privés, accesseurs, immuable) | ne sait rien de la base ni du HTTP |

La règle d'appel est simple : **la route appelle le service, le service appelle le repository**. La route construit le repository SQL uniquement pour le donner au service.

## Où écrire quoi

- **Vérifier ce que le client envoie** (un champ obligatoire, un format) : dans `ressource.json`, appliqué par le Poinçon (voir [la description d'une ressource](ressource-json.md)). Un contrôle que ce vocabulaire ne permet pas s'ajoute dans la route.
- **Une règle métier** : dans le **service**. Une règle violée lève une exception : `ExceptionDéclenche(409, "Ce produit existe déjà")`. Les codes reconnus sont décrits dans [les erreurs](erreurs.md).
- **Parler à la base** : dans le **repository**. Si vous changez de base, c'est la seule couche qui change.
- **Une route de plus** : un bloc `OpérationHTTP` dans le contrôleur, sur le modèle de `ListeProduit`. Le contrôleur est à vous.

Les fichiers générés sont les vôtres : relancer `ebony make resource` ne les remplace jamais.

## Le corps d'une requête : absent, présent, partiel

Un champ absent du corps ne doit pas se confondre avec un champ à zéro. Ebony les distingue, et les routes réagissent ainsi :

```text
POST  /api/produits     {"nom":"Cahier"}                        →  422  {"code":"invalide","message":"Champs obligatoires absents : prix, actif."}
POST  /api/produits     {"nom":"Cahier","prix":0,"actif":false} →  201  {"id":1,"nom":"Cahier","prix":0,"actif":false}
PUT   /api/produits/1   {"nom":"Cahier A5"}                     →  422  {"code":"invalide","message":"Champs obligatoires absents : prix, actif."}
PATCH /api/produits/1   {"prix":2.5}                            →  200  {"id":1,"nom":"Cahier","prix":2.5,"actif":false}
```

- `POST` et `PUT` exigent tous les champs qui ne sont ni `nullable` ni munis d'un `defaut`. Zéro, `false` et le texte vide, quand ils sont envoyés, sont des valeurs.
- `PUT` remplace toute la ligne. `PATCH` ne change que les champs envoyés.

Les règles, les valeurs par défaut et les pièges courants sont dans [la description d'une ressource](ressource-json.md).

## Les tests

Chaque couche se teste seule, parce que chaque accès au système passe par un contrat. Le service reçoit un repository par son contrat `iRepoProduit` : en production le contrôleur lui donne le repository SQL, dans les tests on lui donne le repository **en mémoire**, sans base ni fichier. Les tests générés sont dans `tests/unitaires/produit/` (sans base) et `tests/integration/produit/` (contre la vraie base) ; on les lance avec `owl test`.

## Le démarrage et l'arrêt

Le service généré (`app/http/Service<Nom>.owl`) possède l'application : il la démarre dans `FinInitialisation` (configuration chargée et contrôlée, journal, connexion à la base) et la ferme à l'arrêt. Une configuration invalide arrête le démarrage en listant toutes les erreurs. Les routes partagent la même connexion à la base. `GET /api` et `GET /api/health` restent publics ; `/api/health` répond 200, ou 503 si la base ne répond pas.

**Une requête à la fois.** `owl serve` traite les requêtes une par une : le temps d'une route retarde les suivantes. Une route doit donc répondre vite ; un travail long se fait ailleurs.
