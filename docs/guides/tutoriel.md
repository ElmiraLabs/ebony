# Tutoriel : construire une petite boutique

Les [premiers pas](premiers-pas.md) génèrent une ressource. Ce tutoriel va plus loin : **deux tables liées**, une **validation** dans `ressource.json`, une **règle métier** dans le service, une **route de votre cru**, et un **test** de la règle. À la fin, vous savez où écrire quoi dans un projet Ebony ; la carte des couches est dans [le chemin d'une requête](architecture.md). Base : SQLite. Les réponses citées sont celles du service.

Prérequis : Ebony installé ([installation](installation.md)), `ebony doctor` sans erreur. Sous Linux, `cp` remplace `Copy-Item` et `curl` remplace `curl.exe`.

## 1. Deux ressources liées

Une catégorie a plusieurs produits ; un produit référence sa catégorie.

```powershell
ebony new boutique ; cd boutique
Copy-Item .env.exemple .env ; Copy-Item .env.secrets.exemple .env.secrets

ebony make migration CreeCategories --champs 'id:entier*,nom:texte' --table categories
ebony make migration CreeProduits   --champs 'id:entier*,nom:texte,prix:reel,categorie:entier@categories.id' --table produits
ebony make resource Categorie --champs 'id:entier*,nom:texte' --table categories
ebony make resource Produit   --champs 'id:entier*,nom:texte,prix:reel,categorie:entier@categories.id' --table produits

ebony migrate
ebony token create tuto            # copiez le secret (eb_…)
```

`categorie:entier@categories.id` déclare une clé étrangère : la migration écrit `"categorie" INTEGER NOT NULL REFERENCES "categories" ("id")`. Les migrations sont appliquées dans l'ordre alphabétique de leur nom quand elles portent la même minute : ici `CreeCategories` passe avant `CreeProduits`, ce qu'il faut pour la clé étrangère.

Lancez le service (`owl serve --port 8080`), puis, dans un second terminal, avec le secret à la place de `eb_…` :

```powershell
curl.exe -s -X POST -H "Authorization: Bearer eb_…" -H "Content-Type: application/json" --data-binary "@categorie.json" http://127.0.0.1:8080/api/categories
# {"id":1,"nom":"Papeterie"}
```

(`categorie.json` contient `{"nom":"Papeterie"}` : écrivez le corps dans un fichier, voir les [premiers pas](premiers-pas.md).) Un produit se crée de la même façon avec `{"nom":"Cahier","prix":2.5,"categorie":1}` sur `/api/produits`. Créez-en un second, `{"nom":"Stylo","prix":1,"categorie":1}` : la suite du tutoriel les utilise.

## 2. La validation : dans `ressource.json`

Le contrôleur vérifie **ce que le client envoie** avec le Poinçon, d'après `app/domaine/produit/ressource.json` : un champ obligatoire absent ou une valeur qui viole une règle donne un `422` qui nomme tout. Il n'y a rien à écrire dans le contrôleur. Ajoutons : un prix ne peut pas être négatif. Dans `ressource.json`, donnez une règle au champ `prix` :

```json
{ "nom": "prix", "type": "reel", "regles": { "min": 0 } }
```

Le fichier est relu à chaque requête : pas de régénération, pas de redémarrage. Un prix négatif donne :

```text
POST /api/produits  {"nom":"Gomme","prix":-1,"categorie":1}
  → 422  {"code":"invalide","message":"Le champ « prix » doit être supérieur ou égal à 0."}
```

Les règles possibles (longueurs, bornes, valeurs permises, motif, dates) sont décrites dans [la description d'une ressource](ressource-json.md). Un contrôle que ce vocabulaire ne permet pas s'écrit dans la route, avec `ExceptionDéclenche(422, "…")` : la route attrape l'exception et la traduit en statut HTTP et en JSON (voir [les erreurs](erreurs.md)).

## 3. La règle métier : dans le service

Une règle métier ne dépend ni du HTTP ni de la base. Règle : **deux produits d'une même catégorie ne portent pas le même nom** (casse ignorée). Dans `app/services/produit/cServiceProduit.owl`, remplacez la méthode `Ajoute` :

```owl
// Règle métier : deux produits d'une même catégorie ne portent pas le même nom (casse ignorée).
PROCEDURE PUBLIQUE Ajoute(entite est un cProduit) : cProduit
	POUR TOUT oExistant DE :oRepository.Enumere()
		SI oExistant.LitCategorie() = entite.LitCategorie() ET Minuscule(oExistant.LitNom()) = Minuscule(entite.LitNom()) ALORS
			ExceptionDéclenche(409, "Ce produit existe déjà dans cette catégorie")
		FIN
	FIN
	RENVOYER :oRepository.Ajoute(entite)
FIN
```

Le service ne sait pas d'où vient l'appel : il lève une exception, la route la traduit. Avec « Cahier » déjà présent dans la catégorie 1 :

```text
POST /api/produits  {"nom":"cahier","prix":3,"categorie":1}
  → 409  {"code":"conflit","message":"Ce produit existe déjà dans cette catégorie"}
POST /api/produits  {"nom":"Cahier","prix":2,"categorie":2}     (autre catégorie)
  → 201  {"id":3,"nom":"Cahier","prix":2,"categorie":2}
```

## 4. Une route de votre cru

Les produits d'une catégorie : `GET /api/categories/{cle}/produits`. Ajoutez, à la fin de `ControleurProduit.owl` (avant le dernier `FIN`), une `OpérationHTTP` sur le modèle de `ListeProduit` :

```owl
// Une route à vous : les produits d'une catégorie (GET /api/categories/{cle}/produits).
ProduitsDeCategorie est une OpérationHTTP
	PROPRIETES
		Méthode  = httpGet
		Chemin   = ["categories", cle, "produits"]
		Réponses = [httpOK, httpServiceIndisponible, httpErreurServeur]
		CodeÉtat = httpOK
	FIN
	PROCEDURE surRequête(cle est un entier) : chaîne
		oRepository est un cRepoProduitSql(cEbServiceBase.Base())
		oService    est un cServiceProduit(oRepository)
		sCode       est une chaîne                                                     = ""
		QUAND EXCEPTION DANS
			sJson est une chaîne = ""
			POUR TOUT oEntite DE oService.Enumere()
				SI oEntite.LitCategorie() = cle ALORS
					SI sJson <> "" ALORS
						sJson += ","
					FIN
					sJson += oEntite.EnJson()
				FIN
			FIN
			MoiMême..Réponse..TypeContenu = "application/json"
			MoiMême..Réponse..Corps       = "[" + sJson + "]"
		FAIRE
			sCode = ExceptionInfo(errCode)
			EbJournaliseErreurHttp(sCode, ExceptionInfo(errMessage))
			MoiMême..Réponse..CodeÉtat    = EbStatutHttpDeCode(sCode)
			MoiMême..Réponse..TypeContenu = "application/json"
			MoiMême..Réponse..Corps       = EbCorpsErreurHttp(sCode, ExceptionInfo(errMessage))
		FIN
		RENVOYER ""
	FIN
FIN
```

Le paramètre `cle` de la route est lu depuis l'adresse (`/api/categories/1/produits`) ; la route est **protégée par jeton** comme les autres, sans rien écrire. Elle appelle le **service** (le repository n'est construit que pour lui être donné, jamais appelé directement).

```text
GET /api/categories/1/produits  →  200  [{"id":1,"nom":"Cahier","prix":2.5,"categorie":1},{"id":2,"nom":"Stylo","prix":1,"categorie":1}]
GET /api/categories/2/produits  →  200  [{"id":3,"nom":"Cahier","prix":2,"categorie":2}]
```

## 5. Tester la règle, sans base

Les tests générés utilisent le repository **en mémoire** : ils s'exécutent sans base ni fichier. Ajoutez, à la fin de `tests/unitaires/produit/test_cServiceProduit.owl`, un scénario par règle :

```owl
// Deux produits de la même catégorie ne portent pas le même nom (casse ignorée) : le service lève 409 et n'enregistre pas le doublon.
PROCEDURE scenario_service_refuse_un_doublon_dans_la_meme_categorie()
	oRepository est un cRepoProduitMemoire
	oService    est un cServiceProduit(oRepository)
	oPremier    est un cProduit(0, "Cahier", 2.5, 1)
	oService.Ajoute(oPremier)
	oDoublon est un cProduit(0, "cahier", 3, 1)
	sCode    est une chaîne = ""
	QUAND EXCEPTION DANS
		oService.Ajoute(oDoublon)
	FAIRE
		sCode = ExceptionInfo(errCode)
	FIN
	dbgVérifieEgalité(sCode, "409", "le doublon est refusé")
	dbgVérifieEgalité(oService.Enumere()..Occurrence, 1, "le doublon n'est pas enregistré")
FIN
```

```powershell
owl test -vv --filter test_cServiceProduit
# ✓ scenario scenario_service_refuse_un_doublon_dans_la_meme_categorie
# STATUS: ALL CLEAR (1 suites, 18 assertions, 7 scenarios)
```

Écrivez de la même façon un scénario « le même nom dans une autre catégorie est permis ».

## À savoir

- **La clé étrangère est appliquée.** Un produit d'une catégorie qui n'existe pas (`"categorie":99`) est refusé : `409 {"code":"conflit","message":"Opération refusée : elle viole une clé étrangère (la ligne visée n'existe pas, ou elle est encore visée par une autre)."}`. Ebony active la contrainte à chaque ouverture de la connexion SQLite ; PostgreSQL l'applique d'office (non couvert ici).
- **Un `PUT` remplace toute la ressource** (il exige tous les champs obligatoires) ; `PATCH` ne change que les champs envoyés ([détail](architecture.md#le-corps-dune-requête--absent-présent-partiel)).
- **Chaque couche reste à sa place** : la validation de ce que le client envoie dans `ressource.json` (le Poinçon, appelé par le contrôleur), les règles de l'application dans le service, le SQL dans le repository. Ajouter une règle ne demande jamais de toucher à la base ni au HTTP.

## Pour aller plus loin

- [Les erreurs](erreurs.md) : tous les codes, et comment répondre avec un autre statut.
- [Référence des commandes](commandes.md) : options de `make`, `migrate`, `token`.
- [Configuration et secrets](configuration.md) : passer à PostgreSQL, régler le TLS, préparer la production.
