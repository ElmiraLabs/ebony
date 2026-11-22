# Les routes générées

`ebony make resource` écrit un contrôleur par ressource : `app/http/<dossier>/Controleur<Nom>.owl`. C'est un `ServiceREST` à part : ajouter une ressource ne modifie pas le service de votre application.

## Les six routes

Pour une ressource `Client` :

| Route | Succès | Erreurs possibles |
|---|---|---|
| `GET /api/clients` | 200, une page de la liste | 400, 503, 500 |
| `GET /api/clients/{cle}` | 200 | 404, 503, 500 |
| `POST /api/clients` | 201, l'entité enregistrée | 400, 409, 422, 503, 500 |
| `PUT /api/clients/{cle}` | 200, l'entité enregistrée (remplace toute la ligne) | 400, 404, 409, 422, 503, 500 |
| `PATCH /api/clients/{cle}` | 200, l'entité enregistrée (seuls les champs envoyés changent) | 400, 404, 409, 422, 503, 500 |
| `DELETE /api/clients/{cle}` | 204 | 404, 409, 503, 500 |

Le segment d'adresse est la dernière partie du nom de la table, en minuscules (`crm.Clients` donne `clients`). Chaque entité est écrite avec une clé JSON par colonne, au nom de la colonne en minuscules, mots reliés par `_` (`date_naissance`).

## Les erreurs

Une erreur est un JSON `{ "code": "...", "message": "..." }` :

| Code HTTP | `code` | Cas |
|---|---|---|
| 400 | `invalide` | requête mal formée : corps non JSON, paramètre de liste incorrect |
| 401 | `non_autorise` | jeton absent ou refusé |
| 404 | `introuvable` | la ligne n'existe pas |
| 409 | `conflit` | clé texte déjà prise, ou clé étrangère violée |
| 422 | `invalide` | données invalides : champ obligatoire absent, règle de `ressource.json` violée |
| 503 | `base_indisponible` | la base ne répond pas |
| 500 | `erreur_interne` | erreur du service |

Le message d'un 400, 404 ou 409 ne contient que le nom du champ ou la clé. Le détail d'un 500 ou d'un 503 va dans le journal, jamais au client. Vos propres routes peuvent répondre de la même façon avec `EbErreurHttp`.

## La liste : pagination, tri et filtres

`GET /api/clients` rend une page, jamais toute la table :

```text
GET /api/clients?page=2&limite=10&tri=nom&ordre=desc&filtre_actif=true
→ 200  { "donnees": [ {...}, ... ],
         "meta": { "total": 37, "page": 2, "limite": 10, "pages": 4 } }
```

- **`page`** (1 par défaut) et **`limite`** (20 par défaut, de 1 à 100). Une page au-delà de la fin rend `donnees` vide, sans erreur.
- **`tri`** : une colonne, par sa clé JSON (`date_naissance`), puis **`ordre`** : `asc` (défaut) ou `desc`. À égalité, la clé croissante départage : deux pages ne se recouvrent jamais.
- **`filtre_<colonne>=<valeur>`** : une égalité exacte sur la colonne (`filtre_nom=Ada`, `filtre_actif=true`, `filtre_naissance=1990-01-02`). Plusieurs filtres sont tous exigés. Une valeur vide n'est pas un filtre.
- **`total`** compte les lignes sous les mêmes filtres, toutes pages confondues.
- Les valeurs sont décodées (`%C3%A9` donne `é`).

Un paramètre mal formé (`page=abc`, `limite=500`, `tri=inconnu`) donne **un seul 400** qui les nomme tous. Un paramètre inconnu est ignoré : pour filtrer, il faut écrire `filtre_<colonne>`, pas seulement `<colonne>`.

La liste ne sait pas filtrer autrement que par égalité, ni trier sur plusieurs colonnes.

## Les routes sont protégées

Les routes exigent un jeton. Sans jeton valable, la réponse est `401 non_autorise`, avant la route. Créez un jeton avec `ebony token create <nom>` (voir [token](token.md)) et envoyez-le dans l'en-tête :

```
Authorization: Bearer <jeton>
```

`/api/health` reste public.

**Pour ouvrir les routes** en développement, mettez `AUTH_ROUTES=ouvertes` dans `.env`. Seule cette valeur les ouvre : toute autre les protège, et `ebony env` signale une valeur incorrecte (`Ouvertes`, une faute de frappe) au lieu de protéger sans le dire.

Si le projet n'a pas de module qui protège les routes, le contrôleur est écrit ouvert, avec un commentaire `ROUTES OUVERTES` dans le fichier et une note à la fin de la commande.

## Le corps d'une requête

Pour `POST`, `PUT` et `PATCH`, le contrôleur lit le corps JSON dans une structure `st<Nom>Corps`, une propriété par colonne. Ce qui est obligatoire, la forme des valeurs et les règles sont décrits dans [`ressource.json`](ressource-json.md) et appliqués par le Poinçon.

Chaque propriété de la structure porte une valeur que personne n'envoie (`"__absent__"`, `-999999999`…). Elle permet de distinguer un champ absent d'un champ à zéro. Ne la changez pas : voir [le code généré](code-genere.md).

Un corps qui n'est pas du JSON donne 400, et un autre `Content-Type` donne 415, avec un message d'OWL.

## Quand les routes ne sont pas écrites

OWL ignore en silence certains mots quand ils servent de nom de propriété d'une structure : `liste`, `fin`, `pas`, `est`, `et`, `ou`, `local`, `global`, `tout`, `null`, `vrai`, `faux`… Si le nom d'une colonne en fait partie (ou ne commence pas par une lettre minuscule sans accent), `make resource` écrit les autres fichiers, n'écrit pas les routes et le dit dans une note.

Renommez la colonne, ou écrivez vos propres routes en vous appuyant sur le service.
