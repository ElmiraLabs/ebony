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
      text: Installer
      link: /guides/installation
    - theme: alt
      text: Feuille de route
      link: https://github.com/ElmiraLabs/ebony/blob/main/ROADMAP.md
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

::: warning Le cœur est en chantier
Ebony prépare un routeur, un contexte de requête et des middlewares, à la manière d'AdonisJS. Plusieurs guides sont retirés le temps de les réécrire ; ceux qui restent décrivent l'installation, la configuration, les bases de données et les commandes. La direction est décrite dans la [feuille de route](https://github.com/ElmiraLabs/ebony/blob/main/ROADMAP.md).
:::
