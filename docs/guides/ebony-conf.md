# `ebony.conf` : le fichier qui désigne un projet

`ebony.conf` est un fichier JSON à la **racine** du projet. C'est lui qui fait d'un dossier un projet Ebony : `ebony migrate`, `make`, `token`, `env` et `upgrade` le cherchent dans le dossier courant (pas dans les dossiers parents) et répondent « Ce dossier n'est pas un projet ebony : ebony.conf est introuvable » sans lui. `ebony new` et `ebony init` l'écrivent. **Il se versionne avec git**, contrairement à `ebony/`.

## Un exemple

Celui d'un projet créé par `ebony new boutique` (kit `api`) :

```json
{
	"ebony": {
		"version": "0.1.5"
	},
	"projet": {
		"Nom": "boutique",
		"dossier": "boutique",
		"identifiant": "AppBoutique",
		"type": "api",
		"kit": "api"
	},
	"modules": [
		"burin",
		"auth"
	],
	"base": {
		"fournisseur": "sqlite"
	}
}
```

| Membre | Rôle | Lu par |
|---|---|---|
| `ebony.version` | version **minimale** de la bibliothèque `ebony/` que le projet demande | `ebony restore`, `ebony upgrade`, `ebony doctor` |
| `modules` | les modules du projet, hors cœur (`["burin","poincon","auth"]` pour le kit `api`, `[]` pour `slim`) | `migrate`, `make`, `token`, `restore`, `upgrade` |
| `base.fournisseur` | `sqlite`, `postgresql` ou `hfsql` | `migrate`, `make`, `token` |
| `projet.Nom`, `dossier`, `identifiant` | le nom libre, le dossier déduit (`Café de la Gare` donne `cafe-de-la-gare`) et l'identifiant OWL (`AppCafeDeLaGare`) | informatifs |
| `projet.type`, `projet.kit` | le type d'application (toujours `"api"`) et le kit | informatifs (un outil, comme un IDE, peut les lire) |
| `auth` | présent avec `--auth` : `{"jetons":true,"table":"utilisateurs","mode":"opaque"}` | informatif |

« Informatif » veut dire qu'aucune commande d'Ebony ne relit ce membre : le modifier ne change rien à leur comportement. Un projet `slim` n'a ni `base` ni `auth`.

## `ebony.version` : une version minimale

Comme un `^0.1.0` dans un `package.json` : le projet demande une bibliothèque **au moins aussi récente, de la même génération**, c'est-à-dire le même numéro majeur, et le même mineur tant que le majeur est 0. Une 0.1.3 satisfait `0.1.0` ; une 0.0.9 et une 0.9.0 non.

Ce qui se passe avec l'Ebony 0.1.5 installé :

| `ebony.version` | Résultat |
|---|---|
| `0.1.5` | tout va bien |
| une version de la génération suivante (plus récente que l'installation) | `ebony doctor` avertit ; `ebony restore` refuse (code 1) : installez un Ebony d'au moins la version demandée. `ebony upgrade` ne rétrograde jamais un projet. |
| `0.0.5` (autre génération, plus ancienne) | `ebony doctor` avertit et conseille `ebony upgrade` ; `ebony upgrade` écrit `ebony.version` = `0.1.5` et laisse les autres membres tels quels |
| `abc` ou absente | `ebony doctor` donne une erreur (code 1) : « ebony.version entre guillemets, par exemple 0.1.5 » |

`ebony upgrade` réécrit le fichier en entier dans la forme d'`ebony new` (tabulations, fins de ligne LF, saut de ligne final). Le JSON n'a pas de commentaires, donc rien n'est perdu, mais une mise en forme personnelle serait refaite.

## `modules` : ce que le projet a

Les modules sont choisis à la création par le kit (voir [Modules et kits](modules.md)). Avec `"modules": ["burin"]`, `ebony token create` refuse : « Ce projet n'a pas le module « auth » : « ebony token » en dépend » (code 1).

Ajouter un nom à la main ne **copie** pas le module : seules `ebony restore` et `ebony upgrade` recopient les modules listés dans `ebony/`. Pour ajouter un module à un projet qui existe, utilisez [`ebony add`](ajouter-un-module.md) : il copie la bibliothèque du module, écrit ses fichiers et note le module ici, en dernier. Le `kit` noté ne change pas : il dit le point de départ du projet, alors que `modules` dit ce qu'il a. Il n'y a pas de commande pour retirer un module.

## `base.fournisseur` : la base

Avec une valeur inconnue (`"mysql"`, par exemple), `ebony migrate` et `ebony make migration` refusent et listent les bases connues : `sqlite`, `postgresql`, `hfsql`. Avec `"hfsql"`, `ebony migrate` refuse aussi : il n'applique pas encore de migration sur HFSQL. Un texte qui n'est pas du JSON donne le même refus.

`ebony env` ne regarde pas ce membre : il contrôle les variables de `.env` (voir [Configuration](configuration.md)).

Le fournisseur d'`ebony.conf` doit être le même que celui du registre des composants : `cEbServiceBase("sqlite")` dans `app/Composants.owl`, que `ebony new`, `ebony init` et `ebony add` écrivent d'après `ebony.conf` ([Adopter Ebony](adopter-un-projet.md)).

## Éditer à la main

- Écrivez du **JSON strict** : guillemets doubles, pas de virgule finale, pas de commentaire.
- Après une modification, `ebony doctor` relit `ebony.version`, et `ebony migrate` ou `ebony make` relisent `base.fournisseur` et `modules`. Un fichier abîmé donne un message à la lecture.
- Sans `ebony.conf`, `ebony doctor` dit « sans objet : ce dossier n'est pas un projet ebony » et les autres commandes refusent.

## Pièges courants

- **Changer le fournisseur sans changer le registre** : si vous modifiez `base.fournisseur` à la main sans toucher à `app/Composants.owl` (ou l'inverse), Ebony ne le détecte pas.
- **Un module listé que l'installation n'a pas** : `ebony restore` et `ebony upgrade` ne peuvent pas le recopier. Installez une version d'Ebony qui le contient.
