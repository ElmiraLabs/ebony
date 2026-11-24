# Ebony : feuille de route

Le framework d'applications pour le langage OWL, inspiré d'AdonisJS. Cette page dit ce que l'on construit et dans quel ordre.

> C'est une **direction**, pas un engagement : l'ordre peut changer, une étape peut être revue. Aucune date n'est donnée. Ebony est une préversion ; « disponible » veut dire ce que l'on peut installer aujourd'hui.

## Le cap

Ebony veut donner à OWL ce qu'AdonisJS donne à Node : une structure d'application claire, une commande qui écrit le code, et un cœur léger autour duquel s'ajoutent des modules. Le code généré vous appartient : vous le lisez et vous le modifiez.

## Disponible aujourd'hui

**Une API REST complète à partir d'une commande.**

- `ebony new` crée un projet qui compile et démarre ; `ebony make resource` écrit l'entité, les repositories, le service, le contrôleur et les tests d'une table.
- **Burin** : accès aux bases de données (SQLite, PostgreSQL), migrations, constructeur de requêtes, listes paginées, triées et filtrables.
- **Poinçon** : validation du corps des requêtes, avec des erreurs précises champ par champ.
- **Auth** : jetons d'accès, routes protégées par défaut.
- **Figurant** : fabriques et jeux de données de démonstration.
- `ebony openapi` : le document OpenAPI de votre API.
- Windows et Linux, installation en une commande.

## En construction : le socle

Aujourd'hui, une route est une opération de service générée. Le socle ajoute une manière de déclarer ses routes dans un fichier, comme dans AdonisJS, autour d'un contexte de requête. La syntaxe ci-dessous est **indicative** : les noms ne sont pas arrêtés.

```owl
// start/routes.owl
cRouteur.Get("clients/:id", (c) => c.EcritTexte("Client " + c.LitParam("id"))).Nomme("clients.fiche")
```

- **Routeur** : routes nommées, groupes imbriqués, ressources, contraintes sur les paramètres, domaines.
- **Contexte de requête** : la requête et la réponse au même endroit ; chaque module installé lui ajoute ses capacités (valider un corps, lire la session, obtenir la base).
- **Middlewares** : enchaînement « en oignon », avec paramètres, pour l'authentification, les sessions, la protection CSRF, la limitation de débit, l'identifiant de requête.
- **Gestion centrale des erreurs** : un point unique qui décide de la réponse et du journal.
- **Conteneur d'injection** et **émetteur d'événements**.
- **Fichiers statiques** servis par le routeur.
- **Liste des routes** écrite par ebony (`routes.json`), pour la documentation et l'outillage.

Les routes se déclarent dans un fichier ; le service natif d'OWL devient une porte d'entrée générée, et reste disponible pour les cas particuliers (flux d'événements, envoi de fichiers).

## Ensuite

**Les modules s'appuient sur le socle.**

- Poinçon, Auth et Burin exposent leurs capacités directement dans le contexte de requête.
- Les routes générées par `make resource` s'écrivent dans le fichier de routes.
- Sessions et authentification par cookie, en plus des jetons d'accès.
- Mots de passe, dès qu'un hachage adapté sera disponible dans le langage.

**Bases de données.**

- HFSQL, aux côtés de SQLite et PostgreSQL.
- Générateur de schéma à partir de la description des ressources.
- Commande `ebony seed` et jeux de données plus riches.

**Documentation.**

- Guides complets du socle, de la création d'un module et de la migration d'un projet existant.
- Une première version stable, avec une promesse de compatibilité.

## Plus loin

- **Pages web** : un moteur de gabarits, des formulaires, des vues rendues côté serveur.
- **Applications de bureau**, avec la même structure et les mêmes modules.
- **Modules de tiers** : publier et installer un module écrit par d'autres.
- Temps réel (flux d'événements) et envoi de fichiers.

## Participer

Ebony est développé par ElmiraLabs. Les propositions et les retours passent par les tickets du dépôt [ElmiraLabs/ebony](https://github.com/ElmiraLabs/ebony).

---

Ebony est un projet indépendant pour le langage OWL (NeOwl) ; il n'est pas affilié à l'équipe d'OWL. Licence MIT, ElmiraLabs.
