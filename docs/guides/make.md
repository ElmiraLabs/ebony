# `ebony make` : générer une ressource ou une migration

`ebony make` écrit le code d'une table : la **ressource** (entité, repositories, service, contrôleur, tests), la **migration** qui crée la table, et un **seeder** qui la remplit d'exemples.

```
ebony make resource <Nom> --champs <liste> [--table <table>] [--dry-run] [--json]
ebony make migration <Nom> [--champs <liste>] [--table <table>] [--dry-run] [--json]
ebony make seeder <Nom> [--dry-run] [--json]
```

À lancer dans le dossier d'un projet créé par `ebony new` ou `ebony init` (celui qui contient `ebony.conf`). `ebony aide` liste les commandes et leurs options.

## Décrire les champs avec `--champs`

Les champs sont séparés par des virgules. Chacun s'écrit `nom:type`, suivi de marqueurs facultatifs :

```
id:entier*,nom:texte,email:texte?,client_id:entier@clients,actif:booleen
```

| Partie | Sens |
|---|---|
| `nom` | le nom de la colonne dans la base, tel quel (accents, espaces et majuscules acceptés). |
| `type` | `entier`, `texte`, `reel`, `booleen`, `date` ou `dateheure`. |
| `*` | clé primaire. Une seule : `entier` (générée par la base) ou `texte` (fournie par l'appelant). |
| `?` | la colonne accepte `NULL`. Sans `?`, elle est obligatoire. |
| `@table` | clé étrangère vers `table.id`. `@table.colonne` vise une autre colonne. |
| `~sorte` | pour un champ `texte`, ce qu'il représente : `prenom`, `nom-de-famille`, `produit`, `courriel`, `telephone`, `ville`, `pays`, `adresse`, `code-postal`, `societe`. La fabrique s'en sert pour écrire des valeurs d'exemple réalistes. |

Les marqueurs suivent le type, dans l'ordre que vous voulez, sauf `@` qui vient en dernier : `pays:texte?@pays.code`, `nom:texte~produit`.

Un type inconnu est refusé, avec la liste des types permis. Les dates sont du texte au format ISO 8601 (`AAAA-MM-JJ`, `AAAA-MM-JJTHH:MM:SS`).

Sous PowerShell, `a:entier*,b:texte` est découpé en plusieurs arguments : ce n'est pas un problème, `--champs` prend tous les arguments jusqu'à la prochaine option.

## `make resource` : ce qui est écrit

```
ebony make resource Client --champs 'id:entier*,nom:texte,actif:booleen'
```

Le nom est libre (`Client`, `BonDeCommande`, `Bon de commande`). La commande écrit douze fichiers :

```
app/domaine/client/cClient.owl                    l'entité
app/domaine/client/ContratsClient.owl             le contrat du repository (iRepoClient)
app/domaine/client/ressource.json                 la description de la ressource
app/donnees/client/cRepoClientMemoire.owl         le repository en mémoire, pour les tests
app/donnees/client/cRepoClientSql.owl             le repository sur la base du projet
app/services/client/cServiceClient.owl            le service : vos règles métier
app/http/client/ControleurClient.owl              les six routes REST
database/factories/client/cFabriqueClient.owl     la fabrique d'entités d'exemple
tests/unitaires/client/test_cClient.owl
tests/unitaires/client/test_cRepoClientMemoire.owl
tests/unitaires/client/test_cServiceClient.owl
tests/integration/client/test_cRepoClientSql.owl
```

Le rôle de chaque fichier, et ce que vous pouvez y modifier, est dans [le code généré, fichier par fichier](code-genere.md).

**La table.** Sans `--table`, le nom est mis au pluriel en minuscules (`Client` donne `clients`). Pour une table qui existe déjà, utilisez `--table` (`--table crm.Clients` est accepté).

**Les noms.** Un mot de la base ne devient jamais tel quel un identifiant OWL. Une colonne `Date` donne le champ `sDate` et l'accesseur `LitDate()`. Deux colonnes qui donneraient le même identifiant (`Prénom` et `prenom`) sont refusées.

**Le service** est mince au départ : chaque méthode passe l'appel au repository. Vous y ajoutez vos règles. Une règle violée lève une exception avec un code HTTP, par exemple `ExceptionDéclenche(409, "…")`, que la route traduit en réponse.

**Les routes** sont branchées toutes seules : rien à ajouter à votre service. Elles sont décrites dans [les routes générées](routes-generees.md), et leur validation dans [la description d'une ressource](ressource-json.md).

## La fabrique : des entités d'exemple

Chaque ressource a une fabrique, `database/factories/<dossier>/cFabrique<Nom>.owl`, qui construit des entités d'exemple pour les tests et pour remplir une base. Les valeurs sont les mêmes à chaque exécution, sous Windows comme sous Linux : la ligne `n` porte le texte `<colonne> n`, l'entier `n`, et ainsi de suite.

```owl
oFabrique est une cFabriqueClient(cEbGenerateurCompteur())
oClient est un cClient = oFabrique.Cree()                  // en mémoire, nom = "nom 1"
oAutre  est un cClient = oFabrique.Persiste(oRepository)    // enregistré par le repository
tabSurcharges est un tableau associatif
tabSurcharges["nom"] = "Ada"
oAda    est un cClient = oFabrique.CreeAvec(tabSurcharges)  // un champ fixé, les autres générés
```

Pour des valeurs plus réalistes (prénoms, noms, courriels, villes), le module facultatif `figurant` apporte un générateur : voir [les modules](modules.md).

## `make migration` : créer une table

```
ebony make migration CreeClients --champs 'id:entier*,nom:texte'
```

La commande écrit `database/migrations/M<horodatage>_CreeClients.owl` : une classe avec `Monte()` (le `CREATE TABLE`) et `Descend()` (le `DROP TABLE`), et, pour SQLite, son test. `ebony migrate` l'applique : voir [migrate](migrate.md). Gardez la forme écrite par Ebony : `migrate` lit le SQL dans le fichier.

La table vient de `--table`, ou du nom si celui-ci est `Cree<Table>` (`CreeClients` donne `clients`). Seule la création d'une table est écrite, pas les modifications.

**Sans `--champs`**, la migration reprend les champs de la ressource qui porte cette table : lancez `ebony make resource Client --champs …`, puis `ebony make migration CreeClients`. Rien n'est écrit si aucune ressource ne correspond, ou s'il y en a plusieurs : le message le dit.

Les types suivent la base du projet :

| | SQLite | PostgreSQL |
|---|---|---|
| clé entière | `INTEGER PRIMARY KEY AUTOINCREMENT` | `INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY` |
| `reel` | `REAL` | `DOUBLE PRECISION` |
| `booleen` | `INTEGER` (0 ou 1) | `BOOLEAN` |
| `texte`, `date`, `dateheure` | `TEXT` | `TEXT` |

## `make seeder` : remplir la base de développement

Pour une ressource déjà générée, `ebony make seeder Client` écrit :

```
database/seeders/client/cSeederClient.owl         ajoute des lignes d'exemple si la table est vide
tests/unitaires/client/test_cSeederClient.owl     son test
database/seeders/DatabaseSeeder.owl               le lanceur du projet (écrit une seule fois)
```

Le seeder utilise la fabrique de la ressource. Il ne fait rien si la table contient déjà des lignes : le relancer ne double rien. Après `ebony migrate`, lancez-le depuis le dossier du projet :

```
owl database/seeders/DatabaseSeeder.owl --seed
```

Le lanceur démarre l'application sans HTTP, puis appelle les seeders. Il ne tourne que si `APP_ENV` vaut `developpement` ou `test` : une base de production n'est jamais remplie par erreur. Pour une deuxième ressource, Ebony ne modifie pas le lanceur : une note donne les quatre lignes à y ajouter.

## Ne rien remplacer, `--dry-run`

- Un fichier qui existe est **conservé tel quel** et listé dans `kept`. Seuls les fichiers absents sont créés : relancer la commande ne change rien.
- Un chemin occupé autrement (un dossier à la place d'un fichier, par exemple) est un conflit : rien n'est écrit.
- `--dry-run` fait le même travail sans toucher au disque : il dit ce qui serait créé.

## Sortie `--json`

Pour un outil : une seule ligne sur la sortie standard.

```json
{"ok":true,"command":"make resource","name":"Client","table":"clients","dir":"C:\\Projets\\boutique",
 "dryRun":false,"created":["app/domaine/client/cClient.owl", "…"],"kept":[],"notes":["…"]}
```

`created` liste les fichiers créés (ou qui le seraient), `kept` ceux qui existaient, `notes` ce qu'il reste à faire. En cas d'échec : `{"ok":false,"error":"…"}`.

## Codes de sortie

| Code | Cas |
|---|---|
| 0 | réussi (y compris quand tout était déjà là) |
| 2 | usage incorrect : sous-commande, nom, option, `--champs` ou table |
| 1 | échec : écriture interrompue, conflit de chemin, projet introuvable, seeder sans fabrique, base non reconnue |

## Pièges courants

- **Un champ du mauvais type devient 0.** Un `"prix":"abc"` n'est pas refusé : il est lu comme 0. Voir [la description d'une ressource](ressource-json.md).
- **Un nom de colonne réservé par OWL** (`liste`, `fin`, `pas`, `est`, `et`, `ou`…) empêche l'écriture des routes. La commande écrit les autres fichiers et le dit : renommez la colonne, ou écrivez vos routes. Voir [les routes générées](routes-generees.md).
- **Relancer `make migration`** crée une seconde migration : Ebony ne détecte pas qu'une migration de même nom existe.
- **Vos propres routes.** Ne déclarez pas le repository ni le service dans le bloc du `ServiceREST` : `owl test` échouerait. Construisez-les dans la procédure de la route, comme le font les contrôleurs générés : `oRepository est un cRepoClientSql(cEbServiceBase.Base())`, puis `oService est un cServiceClient(oRepository)`.
- **Une clé non numérique dans l'adresse** (`/api/clients/abc`) est lue comme 0 et donne 404.
