# `ebony make` : écrire une ressource ou une migration

Ce guide décrit les commandes d'écriture de `ebony make` et le code qu'elles produisent. Les outils (un IDE, par exemple) peuvent lire la même grammaire : `ebony make` sans argument, ou `ebony aide`, la liste.

```
ebony make resource <Nom> --champs <liste> [--table <table>] [--dry-run] [--json]
ebony make migration <Nom> [--champs <liste>] [--table <table>] [--dry-run] [--json]
ebony make seeder <Nom> [--dry-run] [--json]
```

À lancer **dans le dossier d'un projet créé par `ebony new` ou `ebony init`** (un `ebony.conf` dans le dossier courant, pas de remontée vers les parents).
`ebony` sans argument (ou `ebony aide`) liste `make` et ses options : c'est ce que lit un outil pour savoir ce que l'ebony installé sait faire.

## `--champs` : la grammaire

Des champs séparés par des virgules (les espaces autour sont ignorés) : `nom:type[marqueurs]`.

| Partie | Sens |
|---|---|
| `nom` | le nom de la colonne **dans la base**, tel quel (accents, espaces, majuscules : `Date de naissance`). Refusés : `"` `` ` `` `[` `]` `%` `{` `}` `,` `:` et les caractères de commande. |
| `type` | `entier`, `texte`, `reel`, `booleen`, `date`, `dateheure` (accents et majuscules tolérés : `réel`, `Booléen`). |
| `*` | clé primaire, `NOT NULL`. Une seule, de type `entier` (supposée **générée par la base**) ou `texte` (fournie par l'appelant). Pas de clé composée. |
| `?` | la colonne accepte `NULL`. Sans `?`, elle est `NOT NULL` dans la migration. |
| `~sorte` | ce que le **texte** représente, pour les [fabriques](#la-fabrique-des-entités-d-exemple) (valeurs d'exemple) : `prenom-masculin`, `prenom-feminin`, `prenom`, `nom-de-famille`, `produit`, `courriel`, `telephone`, `ville`, `pays`, `adresse`, `code-postal`, `societe`, `texte`. Facultatif, pour un champ `texte` seulement ; une autre sorte est refusée. |
| `@table` | clé étrangère vers `table.id` ; `@table.colonne` ou `@schema.table.colonne` pour une autre colonne. Utilisée par la migration. |

Les marqueurs suivent le type, dans n'importe quel ordre, sauf `@` qui vient en dernier (un `*`, un `?` ou un `~sorte` écrit après `@` est refusé : il serait avalé dans le nom de la table) : `id:entier*`, `email:texte?`, `client_id:entier@clients`, `pays:texte?@pays.code`, `nom:texte~produit`.
Aucun n'est un caractère spécial de `cmd` ni de PowerShell (pas de `>` ni de `&`).

Exemple : `id:entier*,nom:texte,email:texte?,client_id:entier@clients,actif:booleen,note:reel,cree:dateheure?`

La **sorte** ne change ni la base ni le code de la ressource : elle est écrite dans `ressource.json` (membre `sorte`) et la fabrique la donne au générateur (`ValeurTexteDeSorte("produit", "nom")`). Sans elle, le générateur ne voit que le nom de la colonne : un champ `nom` y est un nom de famille ; avec `nom:texte~produit`, c'est un nom de produit.

**Un type inconnu est refusé** (code 2, le message liste les types) : jamais remplacé par `texte` en silence. C'est à l'IDE de faire la correspondance entre les types du moteur et ceux-ci :

| Types du moteur (exemples) | Type ebony |
|---|---|
| `INTEGER`, `BIGINT`, `SMALLINT`, `serial` | `entier` |
| `TEXT`, `varchar(80)`, `char`, `uuid`, `json` | `texte` |
| `REAL`, `FLOAT`, `DOUBLE PRECISION`, `NUMERIC`, `DECIMAL` | `reel` |
| `BOOLEAN`, `bit`, `tinyint(1)` | `booleen` |
| `DATE` | `date` |
| `timestamp`, `datetime` | `dateheure` |
| aucun type (HFSQL, ODBC) ou inconnu | à choisir par l'utilisateur : ebony ne devine pas |

Limites : un `NULL` est lu comme la valeur par défaut du type (`0`, texte vide, `Faux`), et ebony n'écrit jamais `NULL` ; `date` et `dateheure` sont du texte ISO 8601 (`AAAA-MM-JJ`, `AAAA-MM-JJTHH:MM:SS`), y compris sur PostgreSQL ; `NUMERIC` en `reel` perd la précision d'un nombre décimal exact.

PowerShell découpe `a:entier*,b:texte` en plusieurs arguments avant de les passer : `--champs` prend **tous les arguments qui suivent, jusqu'à la prochaine option**, joints par des virgules. Les deux écritures sont équivalentes.

## `make resource <Nom>` : entité, repositories, tests

Le rôle de chaque fichier, et ce que vous pouvez modifier, est expliqué dans [le code généré, fichier par fichier](code-genere.md).

Le nom est libre (`Client`, `BonDeCommande`, `Bon de commande`) ; seuls sont refusés un nom sans lettre ni chiffre latin et un nom dont le dossier déduit dépasse 40 caractères. Douze fichiers, pour `Client` (onze si un nom de colonne interdit les routes : voir [Les routes](#les-routes-générées)) :

```
app/domaine/client/cClient.owl                      l'entité : objet valeur immuable, accesseurs LitId(), LitNom()…
app/domaine/client/ContratsClient.owl               la Collection qui déclare l'interface iRepoClient
app/donnees/client/cRepoClientMemoire.owl           le repository en mémoire, pour les tests
app/donnees/client/cRepoClientSql.owl               le repository sur la base du projet (cEbBaseResiliente), requêtes paramétrées
app/services/client/cServiceClient.owl              le service : les règles métier, mince au départ ; reçoit le repository par son contrat
tests/unitaires/client/test_cClient.owl
tests/unitaires/client/test_cRepoClientMemoire.owl
tests/integration/client/test_cRepoClientSql.owl    SQLite en mémoire
tests/unitaires/client/test_cServiceClient.owl      le service sur le repository en mémoire
app/domaine/client/ressource.json                  la description de la ressource : ses champs, en données (voir plus bas)
database/factories/client/cFabriqueClient.owl       la fabrique : des clients d'exemple pour les tests et le seeding (voir « La fabrique »)
app/http/client/ControleurClient.owl                 le contrôleur : les six routes REST ; il appelle le service, jamais le repository (un `ServiceREST` à part)
```

Le repository SQL est écrit avec **Burin**, le constructeur de requêtes de la bibliothèque (ebony/requetes/) : il décrit sa table une fois (nom, nature et caractère obligatoire de chaque colonne), puis construit chaque requête par db.Select(), Insert(), Update(), Del() : aucune valeur n'est écrite dans un texte SQL, le dialecte (SQLite ou PostgreSQL) vient de la base du projet, et chaque colonne est lue selon sa nature (un NULL devient la valeur par défaut du type). Le fichier est à vous : vous pouvez y ajouter vos propres requêtes dans la même forme.

Le repository a six méthodes : `Enumere()`, `Existe(cle)`, `Trouve(cle)`, `Ajoute(entite)`, `Modifie(entite)`, `Supprime(cle)`. Une absence ou un échec **lève** une exception : `404` introuvable, `409` clé texte déjà prise (repositories en mémoire et SQL ; dans le repository SQL, la vérification précède l'`INSERT` et n'est pas atomique : deux ajouts simultanés de la même clé peuvent donner `500`), `500` requête refusée par la base, `503` base injoignable.
Avec une clé entière, `Ajoute` ignore la clé de l'entité reçue et rend celle qui est enregistrée (celle de la base, via `RETURNING`).

**Le service** (`cService<Nom>`) est la couche des règles métier, entre le contrôleur et le repository. Il reçoit le repository par son contrat `iRepo<Nom>` : il ne sait pas s'il parle à SQL ou à la mémoire, donc son test (`test_cService<Nom>.owl`) passe le repository en mémoire. Il est **mince au départ** : chaque méthode (`Enumere`, `Trouve`, `Ajoute`, `Modifie`, `Supprime`) passe l'appel au repository. Vous y ajoutez vos règles (« un client inactif ne peut pas commander ») ; une règle violée lève une exception avec un code (`ExceptionDéclenche(409, "…")`), que le contrôleur traduit en réponse JSON. La **validation** de ce que le client envoie (champ obligatoire vide, forme du corps) reste dans le contrôleur, première couche ; le service n'a pas à connaître la forme d'un corps HTTP.

**La table** : sans `--table`, le nom au pluriel naïf en minuscules (`Client` → `clients`, `BonCommande` → `bon_commandes`). Pour une table qui existe déjà, **`--table`** (`--table crm.Clients` : le schéma est accepté). C'est ce qu'envoie un IDE qui part d'une table existante.

**Identifiants** : le mot de l'utilisateur ne devient jamais tel quel un identifiant OWL. Une colonne `Date` donne le champ privé `sDate`, le paramètre `vDate` et l'accesseur `LitDate()` : OWL refuse `Date`, `Etat`, `Libelle`, `Table`, `Colonne`… comme noms de méthode, et la liste complète n'est pas connue, d'où le préfixe `Lit` pour **tous** les accesseurs. Deux colonnes qui donneraient le même identifiant (`Prénom` et `prenom`) sont refusées.

**Les routes sont branchées** (voir plus bas) : rien à ajouter à votre `ServiceREST`. Pour **vos propres routes** : ne déclarez ni le repository ni le service dans le bloc du `ServiceREST` (`oRepository est un cRepoClientSql(...)` au niveau du service OWL) : dans un projet qui a un `ServiceREST`, une variable de bloc d'une classe du projet fait planter `owl test`. Construisez-les dans la procédure de la route, comme le font les contrôleurs générés, et n'appelez que le service : `oRepository est un cRepoClientSql(cEbServiceBase.Base())`, puis `oService est un cServiceClient(oRepository)`.

## Les routes générées

`app/http/<dossier>/Controleur<Nom>.owl` est un **`ServiceREST` à part** (le type d'OWL pour déclarer des routes ; `UrlBase = ["api"]`). `owl serve` monte tous les `ServiceREST` du projet : ajouter une ressource ne modifie donc pas le service de l'application. Ce n'est pas un « service » au sens du [glossaire](glossaire.md) (les règles métier). Pour `Client` :

| Route | Succès | Erreurs |
|---|---|---|
| `GET /api/clients` | 200, `{ "donnees": [...], "meta": {...} }` (une page) | 400, 503, 500 |
| `GET /api/clients/{cle}` | 200 | 404, 503, 500 |
| `POST /api/clients` | 201, l'entité enregistrée (avec sa clé) | 400 (corps non JSON), 409 (clé texte prise, clé étrangère), 422 (données invalides), 503, 500 |
| `PUT /api/clients/{cle}` | 200, l'entité enregistrée (remplace toute la ligne) | 400 (corps non JSON), 404, 409 (clé étrangère), 422 (données invalides), 503, 500 |
| `PATCH /api/clients/{cle}` | 200, l'entité enregistrée (seuls les champs envoyés changent) | 400 (corps non JSON), 404, 409 (clé étrangère), 422 (données invalides), 503, 500 |
| `DELETE /api/clients/{cle}` | 204 | 404, 409 (encore référencée), 503, 500 |

Le segment d'adresse est la dernière partie du nom de la table, en minuscules (`crm.Clients` donne `clients`). Chaque entité est écrite par sa méthode `EnJson()` : une clé par colonne, **au nom de la colonne en minuscules et mots reliés par `_`** (`date_naissance`).

**Les erreurs** sont un JSON `{ "code": "...", "message": "..." }` : `400 invalide` (requête mal formée), `422 invalide` (données invalides : un champ obligatoire absent ou une règle de `ressource.json` violée), `404 introuvable`, `409 conflit`, `503 base_indisponible`, `500 erreur_interne` (`execution/http/EbErreurHttp.owl`, que vos routes peuvent appeler). Le message d'un 400, 404 ou 409 ne contient que le nom du champ ou la clé ; **le détail d'un 500 ou d'un 503 va au journal, jamais au client**. L'exception est attrapée **dans la route** (`QUAND EXCEPTION`) : le `surErreur` d'un service ne reçoit ni le code ni le message d'origine (il reçoit seulement « Exception non gérée »).

**Le corps** d'un `POST`, d'un `PUT` ou d'un `PATCH` est lu par OWL dans une structure `st<Nom>Corps` (un membre par colonne ; la clé générée par la base n'y est pas, elle vient de l'adresse). OWL lie le JSON sans erreur : un champ absent garderait la valeur par défaut du type, ce qui ne se distingue pas d'un zéro. Chaque membre déclare donc **une valeur que personne n'envoie** (texte : `__absent__`, entier : `-999999999`, réel : `-999999999.5`, booléen : un entier valant `-1`), qu'OWL applique aux champs absents : le contrôleur reconnaît ainsi l'absence (aides : `ebony/poincon/EbCorpsRequete.owl`). Un corps qui n'est pas du JSON donne 400 et un autre `Content-Type` donne 415, avec un texte d'OWL (pas du JSON d'ebony), avant que la route ne s'exécute.

**La liste** (`GET /api/clients`) est paginée, triée et filtrable par l'adresse, jamais en entier :

```text
GET /api/clients?page=2&limite=10&tri=nom&ordre=desc&filtre_actif=true
→ 200  { "donnees": [ {...}, ... ],
         "meta": { "total": 37, "page": 2, "limite": 10, "pages": 4 } }
```

- **`page`** (1 par défaut) et **`limite`** (20 par défaut, de 1 à 100) : une page au-delà de la fin rend `donnees` vide, sans erreur (`total` et `pages` disent où l'on en est).
- **`tri`** : une colonne, par sa **clé JSON** (celle que la liste écrit, `date_naissance`), puis **`ordre`** `asc` (défaut) ou `desc`. À égalité, la clé croissante départage : deux pages ne se recouvrent jamais. Sans `tri`, la liste suit la clé.
- **`filtre_<colonne>=<valeur>`** : une **égalité exacte** sur cette colonne (`filtre_nom=Ada`, `filtre_actif=true`, `filtre_note=12.5`, `filtre_naissance=1990-01-02`). Plusieurs filtres sont tous exigés. Le type de la colonne décide de la valeur permise : entier, nombre à point décimal, `true`/`false`/`1`/`0`, date ISO 8601, texte. Une valeur vide n'est pas un filtre : on ne peut pas filtrer sur « vide ».
- **`total`** compte les lignes **sous les mêmes filtres**, toutes pages confondues.
- Les valeurs sont décodées (`%C3%A9` donne `é`, `+` une espace).
- **Un paramètre mal formé** (`page=abc`, `limite=500`, `tri=inconnu`, `ordre=haut`, `filtre_note=abc`) donne **un seul 400** qui les nomme tous (`Le paramètre « page » doit être un entier supérieur ou égal à 1. Le paramètre « tri » doit être l'un de : id, nom, …`) : rien n'est avalé, ni lu comme 0, ni tronqué. Un paramètre inconnu est ignoré.

Les paramètres sont lus en **texte** : OWL rend `Null` un paramètre absent quand un suivant est présent, et remplace un type raté (`abc` donne 0, `2.7` donne 2) sans erreur ; la bibliothèque (`ebony/liste/cEbCriteresListe.owl`) lit, décode et contrôle elle-même. **Ce que la liste ne fait pas** : filtrer autrement que par égalité, chercher dans plusieurs colonnes, trier sur plusieurs colonnes. **Changement par rapport aux versions précédentes** : la liste rendait un tableau JSON de toutes les lignes ; elle rend maintenant l'objet ci-dessus.
**Ce que les routes exigent** est décidé par le **Poinçon** (`ebony/poincon/EbPoincon.owl`) d'après `app/domaine/<dossier>/ressource.json`, **relu à chaque requête** : modifier le fichier prend effet tout de suite, sans régénérer le contrôleur ni redémarrer le service.

- **`POST` et `PUT`** : tout champ qui n'est ni `nullable` ni muni d'un `defaut`, hors la clé générée ; pour `PUT`, la clé texte vient de l'adresse. S'il en manque : **422 `{"code":"invalide","message":"Champs obligatoires absents : nom, note."}`**, une seule réponse qui les nomme tous. Zéro, faux et texte vide, quand ils sont envoyés, sont des valeurs. Un champ absent prend son `defaut`, sinon la valeur par défaut du type (ebony n'écrit jamais NULL). **`PUT` remplace toute la ligne** : un champ absent reprend donc son `defaut`, pas la valeur actuelle.
- **`PATCH`** : seuls les champs envoyés changent ; les autres gardent la valeur de la ligne actuelle. `{}` renvoie la ligne sans rien changer. Le corps est contrôlé **avant** la recherche de la ligne : un corps invalide sur une ligne absente donne 422, pas 404.
- **Dans les trois cas**, chaque champ envoyé est contrôlé par ses `regles` : un texte obligatoire envoyé vide ou fait d'espaces est refusé, une date doit être au format ISO 8601 (`AAAA-MM-JJ` ; `AAAA-MM-JJTHH:MM:SS` pour `dateheure`), et les règles que vous avez écrites sont appliquées. **Une seule réponse 422** nomme toutes les erreurs : les champs absents d'abord, puis les règles violées.

Les règles se posent sur un champ de `ressource.json`, avec un vocabulaire **fermé** selon le type :

```json
{ "nom": "nom", "type": "texte", "regles": { "longueurMin": 3, "motif": "^[A-Z]" } },
{ "nom": "age", "type": "entier", "defaut": 18, "regles": { "min": 0, "max": 150 } }
```

| Type | Règles |
| --- | --- |
| `texte` | `longueurMin`, `longueurMax` (en caractères), `valeurs` (liste de textes permis), `motif` |
| `entier` | `min`, `max`, `valeurs` (liste d'entiers permis) |
| `reel` | `min`, `max` |
| `date`, `dateheure`, `booleen` | aucune (le format ISO 8601 d'une date est toujours contrôlé) |

`motif` est une expression régulière PCRE **non ancrée**, comme le `pattern` de JSON Schema : `[0-9]+` accepte `ab12cd` ; écrivez `^` et `$` pour viser tout le texte. Dans le JSON, une barre oblique inverse s'écrit deux fois (`\\.` pour un point). **Une faute de syntaxe dans un motif est indétectable** (OWL ne lève rien) : le champ refuse alors toutes les valeurs, ce qui se voit au premier essai.

**Une description fautive est une erreur du projet, pas du client** : une règle inconnue ou d'un autre type (`longeurMin`), une valeur de règle du mauvais type, un `min` plus grand que le `max`, un `defaut` du mauvais type, un JSON invalide ou un fichier absent donnent **500** (`erreur_interne`, sans détail dans la réponse) à la première requête qui lit la description (un `POST`, un `PUT` ou un `PATCH` ; pas un `GET`) ; le journal nomme le fichier, le champ et la règle. Le service démarre quand même : rien n'est lu au démarrage. Le fichier est relu à chaque requête, sans mémoire : une lecture et une analyse de JSON par écriture.

**Ce qui n'est pas détecté** (limites de la liaison d'OWL) : un champ du **mauvais type** (`"note":"abc"`) devient 0 ou le texte vide, sans erreur ; une décimale envoyée pour un entier est tronquée ; un `null` explicite compte comme présent et donne la valeur par défaut du type ; un client qui envoie exactement la valeur déclarée (`__absent__`, `-999999999`, `-999999999.5`, `-1` pour un booléen) est pris pour « champ absent ». Pour toute autre règle, ajoutez vos contrôles dans `Cree<Nom>`, `Modifie<Nom>` et `Corrige<Nom>` : ce fichier est à vous. Une clé entière non numérique dans l'adresse est lue comme `0` par OWL : 404.

**Une ressource générée avant `ressource.json` et le Poinçon** garde son contrôleur et ses contrôles d'alors : ebony ne remplace jamais un fichier. Pour l'adopter, relancez **la même commande** avec les mêmes `--champs` : elle écrit `ressource.json` (le seul fichier manquant) et conserve tout le reste. Si le contrôleur conservé ne lit pas la description, une note le dit : copiez vos modifications ailleurs, supprimez le contrôleur, relancez la commande, puis reportez vos modifications. Rien n'est changé tant que vous ne supprimez pas le fichier vous-même.

**Un projet généré avant ces fichiers** a une copie d'`ebony/` sans `ebony/liste/cEbCriteresListe.owl` : le contrôleur ne compilerait pas. `make resource` le détecte et le dit (une note) ; supprimez `ebony/` à la main puis lancez `ebony restore`.
**La clé** : entière, elle est donnée par la base (`POST` ignore toute clé du corps) ; texte, elle vient du corps à la création (409 si elle est prise) et de l'adresse à la modification (celle du corps est ignorée).

**Les routes sont protégées par défaut** : le contrôleur déclare `Authentification = httpAuthBearer` et un `surAuthentification` qui décide par `execution/auth/EbAutorisation.owl`. Sans jeton d'accès valable, la réponse est `401 non_autorise` (JSON, message fixe qui ne dit pas pourquoi), **avant** la route. Créez un jeton avec `ebony token create <nom>` (`docs/guides/token.md`) et envoyez-le dans l'en-tête `Authorization: Bearer <jeton>` ; la route peut lire le nom du jeton dans `MoiMême..Requête..Identité`. `/api/health` reste public (il est dans le service de l'application, pas dans le contrôleur).
**Pour ouvrir les routes** en développement ou pour une API publique, mettez `AUTH_ROUTES=ouvertes` dans `.env` : seule cette valeur les ouvre, toute autre les protège. Dans un projet créé par `ebony new`, la variable est déclarée en liste dans `config/env.json` : une autre écriture (`Ouvertes`, une faute de frappe) est refusée par `ebony env` et au démarrage, au lieu de protéger sans le dire.
**Le garde vient des modules du projet**, pas d'ebony : `make resource` lit le membre `routes` des manifestes de `ebony/modules/*.json` et en écrit les lignes telles quelles (le cœur ne sait pas quel module protège, ni comment). **Aucun garde** (aucun manifeste n'a de `routes`, par exemple si `ebony/modules/` est absent) : le contrôleur est écrit **ouvert**, avec un commentaire `ROUTES OUVERTES` dans le fichier et une note à la fin de la commande. Rien n'est refusé ; un manifeste illisible l'est (code 22).

**Quand les routes ne sont pas écrites** : OWL **ignore en silence** 58 mots comme noms de membre d'une structure (le membre est accepté à la compilation, jamais rempli depuis le JSON) : `liste`, `fin`, `pas`, `est`, `et`, `ou`, `local`, `global`, `tout`, `null`, `vrai`, `faux`… (liste : `EbMotsReservesOwl`). Si le nom d'une colonne du corps en fait partie (ou ne commence pas par une lettre minuscule sans accent), `make resource` écrit les dix autres fichiers, **n'écrit pas les routes** et le dit dans une note : renommez la colonne ou écrivez vos routes.

Chaque route répond comme décrit ci-dessus sur SQLite et sur PostgreSQL 16. Non couverts : un `503` quand la base tombe pendant une requête, et la concurrence (deux `POST` simultanés).

## La description de la ressource : `ressource.json`

`make resource` écrit aussi `app/domaine/<dossier>/ressource.json` : ce que le générateur sait de la ressource (son nom, sa table, ses champs), **en données**. Ebony ne peut pas relire les classes qu'il a générées (OWL ne charge que le projet en cours) ; ce fichier est ce qu'il relit. Comme tout fichier généré, il est écrit une fois, jamais remplacé : il est ensuite à vous.

```json
{
	"ressource": "Client",
	"table": "clients",
	"champs": [
		{ "nom": "id", "type": "entier", "cle": true },
		{ "nom": "email", "type": "texte", "nullable": true },
		{ "nom": "pays_id", "type": "entier", "reference": { "table": "pays", "colonne": "id" } }
	]
}
```

Un champ a un `nom` (celui de la colonne) et un `type` (les mêmes types que `--champs`) ; `cle`, `nullable` et `reference` (`table`, `colonne`) ne sont écrits que s'ils valent quelque chose. Les mêmes règles que `--champs` s'appliquent : une seule clé primaire, entière ou texte, au moins un autre champ, pas deux colonnes qui donnent le même identifiant. `make` ignore les membres qu'il ne connaît pas ; `defaut` (la valeur d'un champ absent, du type du champ) et `regles` (voir « Ce que les routes exigent ») ne sont pas écrits par `make` : ils sont à vous, et c'est le Poinçon qui les lit.

Deux outils le lisent : `make migration` (section suivante) et le contrôleur généré, par le Poinçon, à chaque `POST`, `PUT` ou `PATCH`.

## La fabrique : des entités d'exemple

`make resource` écrit aussi `database/factories/<dossier>/cFabrique<Nom>.owl`, une classe qui construit des entités d'exemple pour les tests et pour remplir une base. Les valeurs viennent d'un **générateur à compteur** de la bibliothèque, `cEbGenerateurCompteur` : la ligne `n` porte le texte `<colonne> n`, l'entier `n`, le réel `n + 0,5`, un booléen alterné, des dates ISO toujours valides. Les mêmes valeurs partout, sous Windows comme sous Linux.

```
oFabrique est une cFabriqueClient(cEbGenerateurCompteur())
oClient est un cClient = oFabrique.Cree()                       // en mémoire, nom = "nom 1"
oAutre  est un cClient = oFabrique.Persiste(oRepository)         // enregistré par le repository
tabSurcharges est un tableau associatif
tabSurcharges["nom"] = "Ada"
oAda    est un cClient = oFabrique.CreeAvec(tabSurcharges)       // un champ fixé, les autres générés
```

`Persiste` et `PersisteAvec(repository, surcharges)` passent par le contrat `iRepo<Nom>` : le repository en mémoire dans un test, le repository SQL ailleurs. Une clé entière générée par la base vaut toujours `0` dans l'entité construite (le repository donne la vraie). Le fichier est à vous, jamais remplacé ; les tests générés l'utilisent (`scenario_fabrique_persiste_des_lignes_distinctes`). Pour des valeurs plus réalistes (prénoms, noms, courriels, villes), le module facultatif `figurant` apporte `cEbGenerateurFigurant(graine)` : voir [les modules](modules.md). Les seeders qui s'en servent sont décrits plus bas (`make seeder`) ; il n'existe pas de commande `ebony seed`.
## `make migration <Nom>` : la création d'une table

`ebony make migration CreeClients --champs …` écrit `database/migrations/M<horodatage>_CreeClients.owl` (horodatage UTC à la minute) : une classe qui implémente `iEbMigration` (`Nom()`, `Monte()`, `Descend()`), et, pour SQLite, son test (`tests/integration/migrations/`).
`Monte()` rend le `CREATE TABLE`, `Descend()` le `DROP TABLE`. `ebony migrate` l'applique (voir [migrate.md](migrate.md)) en **lisant ce fichier** : gardez la forme écrite par ebony (une instruction par `TableauAjoute`).

La table vient de `--table`, ou du nom si celui-ci est `Cree<Table>` (`CreeClients` → `clients`). Un autre nom exige `--table`. Seule la **création** d'une table est écrite (pas d'`ALTER`).

**Sans `--champs`**, la migration prend les champs de la description de la ressource **qui porte cette table** : `ebony make resource Client --champs …`, puis `ebony make migration CreeClients`. La description est cherchée par sa table (`app/domaine/*/ressource.json`), pas par le nom : il n'y a donc rien à répéter. Refusé (code 2, rien d'écrit) s'il n'y en a aucune, s'il y en a plusieurs (le message les nomme : `--champs` tranche), ou si la description est incorrecte (le message nomme le fichier et le champ). Un fichier illisible n'est pas ignoré en silence : le refus le nomme. `--champs`, quand il est donné, reste prioritaire et ne lit aucun fichier.
Dialectes : `sqlite` et `postgresql` (un autre `base.fournisseur` dans `ebony.conf` est refusé, code 38). **HFSQL est refusé** (code 39), pour une migration comme pour une ressource : Burin n'a pas encore de dialecte HFSQL. Une table d'un schéma (`--table crm.Clients`) est gardée telle quelle pour PostgreSQL. Pour SQLite, les tests générés attachent une base en mémoire sous le nom du schéma, et une clé étrangère y vise la table **sans** son schéma (SQLite refuse `REFERENCES "crm"."pays"`).

| | SQLite | PostgreSQL |
|---|---|---|
| clé entière | `INTEGER PRIMARY KEY AUTOINCREMENT` | `INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY` |
| `reel` | `REAL` | `DOUBLE PRECISION` |
| `booleen` | `INTEGER` (0 ou 1) | `BOOLEAN` |
| `texte`, `date`, `dateheure` | `TEXT` | `TEXT` |

La migration implémente `iEbMigration`, ajouté à la bibliothèque `ebony/` après les premiers projets : si la copie d'`ebony/` du projet est plus ancienne, une note le dit (supprimer `ebony/` à la main puis `ebony restore`).

Relancer la même commande **crée une seconde migration** (l'horodatage change) : ebony ne détecte pas qu'une migration de même nom existe déjà (à faire : il faudrait lister le dossier).

## `make seeder <Nom>` : remplir la base de développement

Pour une ressource **déjà générée** (`make resource`), `ebony make seeder Client` écrit :

```
database/seeders/client/cSeederClient.owl         la classe : Remplit(n) ajoute n lignes d'exemple (par la fabrique) si la table est vide
tests/unitaires/client/test_cSeederClient.owl     son test, sur le repository en mémoire
database/seeders/DatabaseSeeder.owl               le lanceur du projet (écrit une seule fois)
```

Le seeder passe par la [fabrique](#la-fabrique-des-entités-d-exemple) de la ressource : les valeurs sont déterministes. Par défaut, le lanceur construit les fabriques avec le générateur à compteur ; si un module du projet propose son propre générateur (c'est le cas de `figurant`, voir [les modules](modules.md)), `make seeder` écrit celui-là, et une note le dit. `Remplit(n)` **ne fait rien si la table contient déjà des lignes** : relancer le remplissage ne double rien et ne touche pas à vos données.

Le lanceur se lance à la main, depuis le dossier du projet, après `ebony migrate` (la table doit exister) :

```
owl database/seeders/DatabaseSeeder.owl --seed
```

Il démarre l'application comme le service, sans HTTP (configuration `.env`, base, journal), **refuse de tourner sauf si `APP_ENV` vaut `developpement` ou `test`** (une base de production n'est jamais remplie par erreur : exception 7012, code de sortie non nul), appelle les seeders, puis arrête l'application. Sans l'option `--seed` il ne fait rien. Le fichier est à vous : le premier `make seeder` y met le bloc de sa ressource avec `Remplit(10)` (changez le nombre) ; pour une deuxième ressource, `make seeder` ne modifie pas le lanceur (ebony ne remplace rien) et **une note donne les quatre lignes à y ajouter**, dans le bloc `SI`, avant `cEbServiceApplication.Arrête()`.

Un projet créé avant `APP_ENV` doit ajouter cette variable à `config/env.json` (liste `developpement`, `test`, `production`, défaut `developpement`) : sans elle le lanceur refuse, et la note le dit. Avec `--dry-run`, rien n'est écrit.

Le seeder remplit une table vide (dix lignes par défaut) ; relancé, il n'ajoute rien. Le lanceur refuse de tourner hors `APP_ENV=developpement` ou `test`, et sans `--seed` il ne fait rien. Non couverts : une ressource à clé texte ou à clé étrangère (l'ordre des seeders est celui que vous écrivez dans le lanceur).

## Ne remplace jamais, `--dry-run`

- Un fichier qui existe est **conservé tel quel** et listé dans `kept`, avec une note par fichier. Seuls les fichiers absents sont créés. Relancer la même commande ne change rien.
- Un chemin occupé autrement (un dossier à la place d'un fichier, un fichier à la place d'un dossier) est un **conflit** : code 28, tous listés, rien d'écrit.
- `--dry-run` renvoie le même résultat (`created` = ce qui serait créé, `dryRun` à `true`) sans toucher au disque.
- Tout est vérifié avant la première écriture. Une écriture qui échoue en route est le code 24.

## Sortie `--json`

Une seule ligne sur la sortie standard, rien d'autre :

```json
{"ok":true,"command":"make resource","name":"Client","table":"clients","dir":"C:\\Projets\\boutique",
 "dryRun":false,"created":["app/domaine/client/cClient.owl", "…"],"kept":[],"notes":["…"]}
```

| Clé | Sens |
|---|---|
| `command` | `make resource` ou `make migration` |
| `name`, `table` | le nom donné et la table visée |
| `dir` | le dossier du projet : les chemins de `created` et `kept` lui sont relatifs, avec des `/` |
| `dryRun` | `true` pour `--dry-run` |
| `created` | les fichiers créés (ou qui le seraient) |
| `kept` | les fichiers qui existaient et n'ont pas été touchés |
| `notes` | ce que l'utilisateur doit savoir ou faire ensuite |

En cas d'échec : `{"ok":false,"error":"…"}`, une ligne, sans pile d'appels. Sans `--json`, la même chose en texte (`ebony : <cause>` pour une erreur).

## Codes de sortie et d'exception

| Sortie | Cas |
|---|---|
| 0 | réussi (y compris tout conservé) |
| 2 | usage incorrect (code 25) : sous-commande, nom, option, `--champs` ou table incorrects |
| 1 | échec : 24 écriture interrompue, 28 conflit de chemin, 29 horloge illisible, 30 OWL mal placé, 31 pas un projet ebony, 32 seeder sans fabrique ou sans registre des composants, 38 `ebony.conf` sans base, 39 HFSQL (migration, ressource ou seeder) |

## Ce qui n'est pas fait

`make entity | repository | service | validator | page | window | auth`, l'authentification, les filtres autres que l'égalité exacte (intervalles, parties de texte), la recherche dans plusieurs colonnes, le tri sur plusieurs colonnes, la validation au-delà du Poinçon (règles croisées entre champs, règles propres à un format), les migrations qui modifient une table, les clés composées, HFSQL (migrations et repository), la détection d'une migration déjà écrite.

**Un défaut d'OWL à connaître** : `owl test` échoue (« Variable inconnue ») dans un projet dont le `ServiceREST` déclare, dans son bloc, une variable d'une classe du projet. Le service que génère `ebony new` n'a pas ce problème : il pose son application dans un membre `GLOBAL` (`cEbServiceApplication`) au lieu d'une variable de bloc. Vos propres variables de bloc le déclencheraient.
