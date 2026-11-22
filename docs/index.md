---
layout: home

hero:
  name: Ebony
  text: Des API OWL structurées, générées par une commande
  tagline: Pour le langage de programmation OWL (sans rapport avec l'OWL du W3C). Préversion 0.1.5.
  image:
    src: /logo-ebony.png
    alt: Logo Ebony
  actions:
    - theme: brand
      text: Démarrer
      link: /guides/premiers-pas
    - theme: alt
      text: Installer
      link: /guides/installation
    - theme: alt
      text: GitHub
      link: https://github.com/ElmiraLabs/ebony

features:
  - title: Un projet prêt à tourner
    details: "ebony new crée un projet qui compile et démarre sous owl serve : configuration, service REST, bibliothèque, tests."
  - title: Un code que vous lisez
    details: "ebony make resource écrit l'entité, les repositories, le service, le contrôleur REST et les tests d'une table. Rien n'est caché."
  - title: Des routes protégées
    details: "Les routes générées demandent un jeton d'accès. Vous le créez avec ebony token create."
  - title: Honnête sur ses limites
    details: "Ce qui est fait, ce qui ne l'est pas encore et ce qui reste à vérifier est dit dans les guides."
---

## Ce que génère une ressource

Une seule commande, `ebony make resource`, écrit les fichiers d'une table. Une requête suit ce chemin : le **contrôleur** reçoit la requête, le **service** applique les règles métier, le **repository** parle à la base, et le **modèle** porte les données.
::: code-group

```owl [1. Contrôleur]
CreeProduit est une OpérationHTTP
    PROPRIETES
        Méthode  = httpPost
        Chemin   = ["produits"]
        CodeÉtat = httpCréé
    FIN

    PROCEDURE surRequête(stCorps est un stProduitCorps) : chaîne
        QUAND EXCEPTION DANS
            jDescription est un JSON = EbPoinconDescription("app/domaine/produit/ressource.json")
            sAbsents est une chaîne = ""
            sErreurs est une chaîne = ""
            SI EbTexteAbsent(stCorps.Nom) ALORS
                SI EbPoinconObligatoire(jDescription, "nom") ALORS
                    sAbsents = EbPoinconAjouteAbsent(sAbsents, "nom")
                FIN
            SINON
                sErreurs += EbPoinconVerifieTexte(jDescription, "nom", "nom", stCorps.Nom)
            FIN
            // …
            EbPoinconRefuse(sAbsents, sErreurs)
            // …
```

```owl [2. Service]
// Les règles métier sont ici : une règle violée lève ExceptionDéclenche(409, « … »).
cServiceProduit est une Classe
PRIVÉ
    oRepository est un iRepoProduit

    PROCEDURE Constructeur(repository est un iRepoProduit)
        :oRepository = repository
    FIN

    PROCEDURE PUBLIQUE Trouve(cle est un entier) : cProduit
        RENVOYER :oRepository.Trouve(cle)
    FIN

    PROCEDURE PUBLIQUE Ajoute(entite est un cProduit) : cProduit
        RENVOYER :oRepository.Ajoute(entite)
    FIN
FIN
```

```owl [3. Repository]
// Repository « Produit » sur la base du projet : les valeurs passent par des paramètres, jamais dans le texte SQL.
cRepoProduitSql est une Classe implemente iRepoProduit
PRIVÉ
    oBase  est un cEbBaseResiliente
    oBurin est un cEbBurin
    oTable est un cEbTable

    PROCEDURE Constructeur(base est un cEbBaseResiliente)
        :oBase = base
        :oBurin = base.Burin()
        oDefinition est un cEbTable("produits")
        oDefinition.AjouteColonne("id", "entier", Vrai, Vrai)
        oDefinition.AjouteColonne("nom", "texte", Vrai, Faux)
        oDefinition.AjouteColonne("prix", "reel", Vrai, Faux)
        oDefinition.AjouteColonne("actif", "booleen", Vrai, Faux)
        :oTable = oDefinition
    FIN

    PROCEDURE PUBLIQUE Trouve(cle est un entier) : cProduit
        oResultat est un cEbResultatSql = EbEnvoieRequete(:oBase, :oBurin.Select().From(:oTable).Where(:ColonneDe("id").Eq(cle)).ToSQL())
        SI oResultat.NbLignes() = 0 ALORS
            ExceptionDéclenche(404, "Produit introuvable : " + cle)
        FIN
        oEntite est un cProduit = :Depuis(EbLignesDe(oResultat)[1])
        RENVOYER oEntite
    FIN
FIN
```

```owl [4. Modèle]
// Entité « Produit » (table « produits »).
cProduit est une Classe
PRIVÉ
    nId    est un entier  = 0
    sNom   est une chaîne = ""
    rPrix  est un réel    = 0
    bActif est un booléen = Faux

    PROCEDURE Constructeur(vId est un entier, vNom est une chaîne, vPrix est un réel, vActif est un booléen)
        :nId = vId
        :sNom = vNom
        :rPrix = vPrix
        :bActif = vActif
    FIN

    PROCEDURE PUBLIQUE LitNom() : chaîne
        RENVOYER :sNom
    FIN
FIN
```

```owl [5. Test]
// Les accesseurs rendent les valeurs données au constructeur.
PROCEDURE scenario_les_accesseurs_rendent_les_valeurs_du_constructeur()
    oEntite est un cProduit(5, "essai", 1.5, Vrai)
    dbgVérifieEgalité(oEntite.LitId(), 5, "id")
    dbgVérifieEgalité(oEntite.LitNom(), "essai", "nom")
    dbgVérifieEgalité(oEntite.LitPrix(), 1.5, "prix")
    dbgVérifieVrai(oEntite.LitActif(), "actif")
FIN
```

:::
