# La description d'une ressource : `ressource.json`

`ebony make resource` écrit `app/domaine/<dossier>/ressource.json` : la description de la ressource (son nom, sa table, ses champs). Elle est écrite une fois, jamais remplacée, puis elle est à vous.

C'est elle qui décide de la validation : le **Poinçon** la relit à chaque `POST`, `PUT` ou `PATCH`. Modifier le fichier prend effet tout de suite, sans régénérer le contrôleur ni redémarrer le service.

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

## Les champs

Un champ a un `nom` (celui de la colonne) et un `type` (les mêmes types que `--champs`). Les membres `cle`, `nullable` et `reference` ne sont écrits que s'ils valent quelque chose.

Deux membres sont à vous, `make` ne les écrit pas :

- **`defaut`** : la valeur d'un champ absent, du type du champ.
- **`regles`** : les contrôles à appliquer à la valeur.

## Les règles

Les règles se posent sur un champ. Le vocabulaire est fermé, selon le type :

```json
{ "nom": "nom", "type": "texte", "regles": { "longueurMin": 3, "motif": "^[A-Z]" } },
{ "nom": "age", "type": "entier", "defaut": 18, "regles": { "min": 0, "max": 150 } }
```

| Type | Règles |
|---|---|
| `texte` | `longueurMin`, `longueurMax` (en caractères), `valeurs` (liste de textes permis), `motif` |
| `entier` | `min`, `max`, `valeurs` (liste d'entiers permis) |
| `reel` | `min`, `max` |
| `date`, `dateheure`, `booleen` | aucune : le format ISO 8601 d'une date est toujours contrôlé |

`motif` est une expression régulière **non ancrée** : `[0-9]+` accepte `ab12cd`. Écrivez `^` et `$` pour viser tout le texte. Dans le JSON, une barre oblique inverse s'écrit deux fois (`\\.` pour un point).

## Ce que les routes exigent

- **`POST` et `PUT`** : tout champ qui n'est ni `nullable` ni muni d'un `defaut` est obligatoire (hors la clé générée par la base). S'il en manque, la réponse est un **422**, une seule, qui les nomme tous :

  ```json
  {"code":"invalide","message":"Champs obligatoires absents : nom, note."}
  ```

  Zéro, `false` et le texte vide, quand ils sont envoyés, sont des valeurs. Un champ absent prend son `defaut`, sinon la valeur par défaut de son type.

- **`PUT` remplace toute la ligne** : un champ absent reprend donc son `defaut`, pas la valeur actuelle.

- **`PATCH`** change seulement les champs envoyés. `{}` renvoie la ligne sans rien changer. Le corps est contrôlé avant la recherche de la ligne : un corps invalide sur une ligne absente donne 422, pas 404.

- **Dans les trois cas**, chaque champ envoyé est contrôlé par ses `regles` : un texte obligatoire vide ou fait d'espaces est refusé, une date doit être au format ISO 8601 (`AAAA-MM-JJ`, ou `AAAA-MM-JJTHH:MM:SS` pour `dateheure`). Une seule réponse 422 nomme les champs absents, puis les règles violées.

## Une description incorrecte

Une description incorrecte est une erreur de votre projet, pas du client : règle inconnue ou d'un autre type (`longeurMin`), valeur de règle du mauvais type, `min` plus grand que `max`, `defaut` du mauvais type, JSON invalide ou fichier absent.

Elle donne un **500** à la première requête qui lit la description (un `POST`, un `PUT` ou un `PATCH`, pas un `GET`). La réponse ne donne aucun détail ; le journal nomme le fichier, le champ et la règle. Le service démarre quand même.

## Pièges courants

- **Un champ du mauvais type est refusé** : `"note":"abc"` ou `"note":"12"` donne `422` (« doit être un nombre »), tout comme une décimale pour un entier (`2.7`, mais aussi `5.0`) ou `1` pour un booléen. Le contrôle porte sur le texte reçu, pas sur une valeur déjà convertie.
- **Un `null` n'est permis que pour un champ `nullable`** : il donne alors la valeur par défaut du type. Pour un autre champ, c'est un `422`.
- **Un texte vide ou d'espaces** n'est pas une valeur pour un champ obligatoire (`422`) ; il est permis pour un champ `nullable` ou muni d'un `defaut`, et alors aucune règle ne s'applique.
- **Les clés JSON** ne distinguent pas la casse (`NOM` remplit `nom`), et un champ inconnu de la description est ignoré. Une colonne dont le nom a des espaces ou des accents (`date naissance`) s'envoie sous sa clé en minuscules reliées par `_` (`date_naissance`).
- **Une faute de syntaxe dans `motif`** n'est pas détectée : le champ refuse alors toutes les valeurs, ce qui se voit au premier essai.
- **Pour les autres règles** (règles entre deux champs, par exemple), ajoutez vos contrôles dans le service, ou dans `Cree<Nom>`, `Modifie<Nom>` et `Corrige<Nom>` du contrôleur : ces fichiers sont à vous.
