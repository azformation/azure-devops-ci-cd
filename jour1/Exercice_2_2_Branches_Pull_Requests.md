# Exercice 2.2: Gestion des Branches et Pull Requests

## Objectif
Apprendre à créer et gérer des branches, à effectuer des modifications sur une branche, et à utiliser les Pull Requests pour fusionner le code de manière contrôlée.

## Contexte
Les branches sont un élément fondamental de Git, permettant aux développeurs de travailler sur de nouvelles fonctionnalités ou des corrections de bugs sans affecter la ligne principale de développement. Les Pull Requests (PR) sont un mécanisme clé pour la revue de code et l'intégration sécurisée des modifications.

## Prérequis
*   Un dépôt Git existant dans Azure Repos (créé lors de l'Exercice 2.1).
*   Git installé sur votre machine locale.
*   Un éditeur de texte ou un IDE.

## Étapes

### Partie 1: Création d'une Nouvelle Branche
1.  **Assurez-vous d'être sur la branche principale (main/master)**:
    ```bash
    git checkout main
    git pull origin main
    ```
    *   (Remplacez `main` par `master` si c'est votre branche par défaut).

2.  **Créer une nouvelle branche pour une fonctionnalité**:
    ```bash
    git checkout -b feature/nouvelle-fonctionnalite
    ```
3.  **Vérifier que vous êtes sur la nouvelle branche**:
    ```bash
    git checkout
    ``` 
4. **Pour basculer vers une branche existante**:
    ```bash
    git checkout <nom_de_la_barnche>
    
    ```
### Partie 2: Effectuer des Modifications et Commiter
1.  **Modifier un fichier existant ou en créer un nouveau**:
    *   Ouvrez `index.html` (ou un autre fichier de votre choix) et ajoutez une nouvelle ligne ou modifiez du texte.
    *   Exemple d'ajout dans `index.html`:
        ```html
        <p>Ceci est une nouvelle fonctionnalité ajoutée sur une branche.</p>
        ```

2.  **Ajouter et commiter les modifications**:
    ```bash
    git add .
    git commit -m "Ajout de la nouvelle fonctionnalité"
    ```

3.  **Pousser la nouvelle branche vers Azure Repos**:
    ```bash
    git push origin feature/nouvelle-fonctionnalite
    ```

### Partie 3: Création d'une Pull Request dans Azure Repos
1.  **Accéder à Azure Repos**:
    *   Retournez à votre dépôt dans Azure Repos (`https://dev.azure.com/votre_organisation/votre_projet/_git/MonApplicationWeb`).

2.  **Créer une Pull Request**:
    *   Vous devriez voir une notification vous invitant à créer une Pull Request pour votre nouvelle branche. Cliquez dessus, ou naviguez vers `Pull requests` dans le menu de gauche et cliquez sur `New pull request`.
    *   **Source branch** : `feature/nouvelle-fonctionnalite`.
    *   **Target branch** : `main` (ou `master`).
    *   **Titre** : Donnez un titre clair (ex: `Ajout de la nouvelle fonctionnalité`).
    *   **Description** : Décrivez les modifications apportées.
    *   **Reviewers** : Ajoutez-vous comme reviewer (ou un autre participant si vous travaillez en binôme).
    *   Cliquez sur `Create`.

### Partie 4: Revue de Code et Fusion
1.  **Revoir la Pull Request**:
    *   En tant que reviewer, examinez les modifications proposées. Vous pouvez ajouter des commentaires.
    *   Cliquez sur `Approve` si les modifications sont satisfaisantes.

2.  **Compléter la Pull Request**:
    *   Une fois approuvée, cliquez sur `Complete`.
    *   Choisissez l'option de fusion (ex: `Merge (no fast-forward)` ou `Squash commit`).
    *   Cliquez sur `Complete merge`.

3.  **Vérifier la branche principale**:
    *   Retournez à la branche `main` (ou `master`) de votre dépôt en ligne. Vous devriez voir les modifications fusionnées.
    *   Dans votre terminal local, mettez à jour votre branche principale:
        ```bash
        git checkout main
        git pull origin main
        ```

## Questions de Réflexion
*   Pourquoi est-il préférable de travailler sur des branches séparées plutôt que directement sur la branche principale ?
*   Quel est le rôle des Pull Requests dans le processus de développement collaboratif ?
*   Quels sont les avantages de la revue de code avant la fusion ?

## Livrables
*   Lien vers la Pull Request complétée dans Azure Repos.
*   Capture d'écran montrant les modifications fusionnées dans la branche principale en ligne.
*   Réponses aux questions de réflexion.

