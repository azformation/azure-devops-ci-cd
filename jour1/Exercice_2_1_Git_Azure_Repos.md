# Exercice 2.1: Création et Gestion d'un Dépôt Git dans Azure Repos

## Objectif
Ce premier exercice pratique vise à familiariser les participants avec la création d'un dépôt Git dans Azure Repos, le clonage local, l'ajout de fichiers, la réalisation de commits et le push des modifications.

## Contexte
Azure Repos est le service de gestion de code source d'Azure DevOps, offrant des dépôts Git illimités et gratuits. Maîtriser les opérations de base de Git avec Azure Repos est fondamental pour toute équipe de développement.

## Prérequis
*   Un compte Azure DevOps avec une organisation et un projet existants (créés lors du Module 1 ou fournis par le formateur).
*   Git installé sur votre machine locale.
*   Un éditeur de texte ou un IDE (Visual Studio Code, IntelliJ IDEA, etc.).

## Étapes

### Partie 1: Création d'un Dépôt Git dans Azure Repos
1.  **Accéder à Azure Repos**:
    *   Connectez-vous à votre organisation Azure DevOps (`https://dev.azure.com/votre_organisation`).
    *   Naviguez vers votre projet (ex: `MonPremierProjetCI-CD`).
    *   Dans le menu de gauche, cliquez sur `Repos`.

2.  **Créer un nouveau dépôt**:
    *   Si c'est le premier dépôt de votre projet, vous verrez une option pour `Initialize` ou `Import a repository`. Si des dépôts existent déjà, cliquez sur le menu déroulant à côté du nom du dépôt actuel et sélectionnez `New repository`.
    *   **Type de dépôt** : Assurez-vous que `Git` est sélectionné.
    *   **Nom du dépôt** : Donnez un nom significatif (ex: `MonApplicationWeb`).
    *   **Ajouter un README** : Cochez l'option `Add a README` pour initialiser le dépôt avec un fichier README.md.
    *   Cliquez sur `Create`.

### Partie 2: Clonage du Dépôt Localement
1.  **Obtenir l'URL de clonage**:
    *   Une fois le dépôt créé, vous serez redirigé vers sa page. Cliquez sur le bouton `Clone` en haut à droite.
    *   Copiez l'URL de clonage HTTPS (ex: `https://votre_organisation@dev.azure.com/votre_organisation/votre_projet/_git/MonApplicationWeb`).

2.  **Cloner le dépôt**:
    *   Ouvrez votre terminal ou invite de commande.
    *   Naviguez vers le répertoire où vous souhaitez stocker votre projet (ex: `cd C:\projets` ou `cd ~/Documents/projets`).
    *   Exécutez la commande de clonage:
        ```bash
        git clone <URL_de_clonage>
        ```
    *   Entrez vos identifiants Azure DevOps si demandé.

### Partie 3: Ajout de Fichiers, Commit et Push
1.  **Créer un nouveau fichier**:
    *   Naviguez dans le répertoire du dépôt cloné (ex: `cd MonApplicationWeb`).
    *   Créez un nouveau fichier (ex: `index.html`) avec un contenu simple:
        ```html
        <!DOCTYPE html>
        <html>
        <head>
            <title>Ma Première Application</title>
        </head>
        <body>
            <h1>Bienvenue sur ma première application CI/CD!</h1>
        </body>
        </html>
        ```

2.  **Ajouter le fichier à l'index Git (Staging Area)**:
    ```bash
    git add index.html
    ```

3.  **Créer un commit**:
    ```bash
    git commit -m "first commit"


"Ajout du fichier index.html"
    ```

4.  **Pousser les modifications vers Azure Repos**:
    ```bash
    git push origin master
    ```
    *   (Remplacez `master` par `main` si votre branche par défaut est `main`).

### Partie 4: Vérification dans Azure Repos
1.  **Vérifier les modifications en ligne**:
    *   Retournez à Azure Repos dans votre navigateur.
    *   Actualisez la page de votre dépôt `MonApplicationWeb`.
    *   Vous devriez voir le fichier `index.html` et votre dernier commit.

## Questions de Réflexion
*   Quelle est la différence entre `git add` et `git commit` ?
*   Pourquoi est-il important de faire des commits fréquents et avec des messages clairs ?
*   Comment `git push` synchronise-t-il votre dépôt local avec Azure Repos ?

## Livrables
*   Lien vers votre dépôt `MonApplicationWeb` dans Azure Repos.
*   Capture d'écran montrant le fichier `index.html` dans votre dépôt en ligne.
*   Réponses aux questions de réflexion.

