# Le code généré, fichier par fichier

`ebony make resource Produit --champs …` écrit douze fichiers. Ce guide dit à quoi sert chacun, ce que vous pouvez y modifier, et pourquoi les fichiers sont courts : les explications sont ici, et non dans les commentaires du code.

## Le principe

- **Les fichiers sont à vous dès leur écriture.** Ebony ne remplace jamais un fichier qui existe : relancer la commande les laisse tels quels et ne crée que ce qui manque.
- **La description de la ressource est dans `ressource.json`.** C'est elle qui décide des champs, des règles de validation et des valeurs par défaut. Modifiez-la pour changer les règles : elle est relue à chaque requête, sans régénérer le code.
- **Les commentaires sont courts.** Ils ne disent que ce qu'il faut savoir sur place ; le reste est dans ce guide et dans [les routes](make.md).

## Les fichiers

| Fichier | Rôle | À modifier ? |
|---|---|---|
| `app/domaine/produit/cProduit.owl` | l'entité : un objet valeur immuable, rempli par son constructeur, lu par des accesseurs `LitNom()`, `LitPrix()`… | non, sauf pour ajouter un calcul |
| `app/domaine/produit/ContratsProduit.owl` | l'interface `iRepoProduit` : le contrat que tout repository respecte | non |
| `app/domaine/produit/ressource.json` | la description de la ressource : champs, clés, `defaut`, `regles` | **oui**, c'est là que vous fixez les règles |
| `app/donnees/produit/cRepoProduitMemoire.owl` | le repository en mémoire, pour les tests | non |
| `app/donnees/produit/cRepoProduitSql.owl` | le repository sur la base du projet | non, sauf requête spéciale |
| `app/services/produit/cServiceProduit.owl` | le service : **vos règles métier** | **oui** |
| `app/http/produit/ControleurProduit.owl` | les six routes REST | **oui** pour vos propres routes |
| `database/factories/produit/cFabriqueProduit.owl` | une fabrique d'entités d'exemple pour les tests et les seeders | oui, pour les valeurs d'exemple |
| `database/migrations/…` | la table (écrite par `ebony make migration`) | oui, avant de l'appliquer |
| `tests/unitaires/produit/test_cServiceProduit.owl` | les tests du service, sur le repository en mémoire | **oui**, ajoutez un scénario par règle |
| `tests/unitaires/produit/test_cProduit.owl` et `test_cRepoProduitMemoire.owl` | les tests de l'entité et du repository en mémoire | non |
| `tests/integration/produit/test_cRepoProduitSql.owl` | le repository SQL sur une base en mémoire | non |

## Où mettre votre code

- **Une règle métier** (un doublon, une limite, un statut) : dans le service. Il lève une exception avec le code HTTP voulu, par exemple `ExceptionDéclenche(409, "…")` ; la route la traduit (voir [les erreurs](erreurs.md)).
- **Une validation de ce que le client envoie** : dans `ressource.json` (champ obligatoire, longueur, bornes, valeurs permises, motif, date). Le Poinçon l'applique et répond en une seule fois, avec `422` (voir [les routes générées](make.md)).
- **Une route de votre cru** : dans le contrôleur, sur le modèle des routes existantes. Elle appelle le service, jamais le repository.
- **Une requête SQL particulière** : dans le repository SQL, en gardant les valeurs en paramètres.

## Pourquoi `ControleurProduit.owl` ne contient pas de contrôles

Les contrôles viennent de `ressource.json` et sont appliqués par le Poinçon à chaque requête. Le contrôleur ne fait qu'appeler le Poinçon, puis le service. Ainsi, changer une règle ne demande ni de régénérer ni de modifier le contrôleur.

Deux points de ce fichier méritent d'être connus :

- **Les sentinelles** : chaque champ de la structure du corps porte une valeur que personne n'envoie (`"__absent__"`, `-999999999`…). Elle permet de distinguer « champ absent » de « zéro » : OWL remplace un champ absent par la valeur par défaut de son type. Ne changez pas ces valeurs, car le Poinçon les reconnaît. Les limites sont décrites dans [les routes générées](make.md).
- **La protection par jeton** : les routes exigent un jeton (`ebony token create <nom>`), sinon `401`. `AUTH_ROUTES=ouvertes` dans `.env` les ouvre, pour le développement seulement.

## Pourquoi le service de l'application n'a pas de variable de bloc

Le service de l'application (`app/http/Service<Nom>.owl`, celui qui démarre Ebony) ne crée pas l'application dans une variable de son bloc : elle est posée dans un membre `GLOBAL` de `cEbServiceApplication`. Sinon, `owl test` échouerait (voir « Un défaut d'OWL à connaître » dans [make](make.md)). Ne déclarez pas de variable de bloc de vos propres classes dans ce service.

## Pourquoi le repository SQL n'écrit pas l'identifiant

La clé entière est générée par la base : le repository ne l'écrit pas à l'ajout, et `RETURNING` ramène la clé enregistrée. Pour une clé texte, c'est l'appelant qui la fournit.

## Pour les tests

Chaque scénario de test est une procédure `scenario_…` précédée d'un commentaire d'une phrase, qui dit ce que le test vérifie. Les tests générés utilisent le repository en mémoire : ils tournent sans base. Lancez-les avec `owl test` (voir [les tests](tests.md)).
