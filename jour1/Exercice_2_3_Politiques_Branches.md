
# Exercice 2.3: Mise en œuvre de Politiques de Branches

## Objectif
Apprendre à configurer et appliquer des politiques de branches dans Azure Repos pour renforcer la qualité du code et la conformité.

## Contexte
Les politiques de branches sont des règles configurables qui peuvent être appliquées à des branches spécifiques (généralement la branche principale ou de développement) pour garantir que le code qui y est fusionné respecte certains critères. Cela inclut l'exigence de revues de code, de builds réussis, et d'autres vérifications.

## Prérequis
*   Un dépôt Git existant dans Azure Repos (créé lors de l'Exercice 2.1).
*   Un projet Azure DevOps.
*   Des droits d'administrateur ou de contributeur avec la permission de gérer les politiques de branches.

## Étapes

### Partie 1: Configuration d'une Politique de Branche de Base
1.  **Accéder aux Politiques de Branches**:
    *   Connectez-vous à votre organisation Azure DevOps et naviguez vers votre projet.
    *   Dans le menu de gauche, cliquez sur `Repos` -> `Branches`.
    *   Trouvez votre branche principale (`main` ou `master`). Cliquez sur les trois points (`...`) à droite de la branche et sélectionnez `Branch policies`.

2.  **Exiger une Revue de Code Minimale**:
    *   Dans la section `Branch Policies`, activez l'option `Require a minimum number of reviewers`.
    *   Définissez le nombre de relecteurs requis à `1`.
    *   Cochez `Allow requestors to approve their own changes` (pour cet exercice, mais en production, il est souvent préférable de ne pas l'autoriser).
    *   Cliquez sur `Save changes`.

### Partie 2: Exiger la Réussite des Builds
1.  **Ajouter une Politique de Build**:
    *   Dans la même page des politiques de branches, sous la section `Build Validation`, cliquez sur `+ Add policy`.
    *   Sélectionnez un pipeline de build existant (si vous en avez un, sinon, vous devrez en créer un simple qui se contente de compiler un projet ou de lancer un script).
    *   **Path filter** (Optionnel) : Laissez vide pour appliquer à tout le dépôt, ou spécifiez un chemin si vous voulez que le build ne se déclenche que pour les changements dans un sous-dossier.
    *   **Policy requirement** : Choisissez `Required`.
    *   Cliquez sur `Save`.

### Partie 3: Tester les Politiques de Branches
1.  **Créer une nouvelle branche et des modifications**:
    *   Depuis votre terminal local, assurez-vous d'être sur la branche principale (`git checkout main`).
    *   Créez une nouvelle branche de fonctionnalité : `git checkout -b feature/test-policies`.
    *   Modifiez un fichier existant ou créez un nouveau fichier.
    *   Commitez vos modifications : `git commit -m "Test des politiques de branches"`.
    *   Poussez la branche vers Azure Repos : `git push origin feature/test-policies`.

2.  **Créer une Pull Request**:
    *   Dans Azure Repos, créez une Pull Request de `feature/test-policies` vers `main`.

3.  **Observer les Politiques Appliquées**:
    *   Dans la page de la Pull Request, vous devriez voir les politiques de branches que vous avez configurées. Elles indiqueront si les exigences (revue de code, build réussi) sont satisfaites ou non.
    *   Tentez de compléter la Pull Request sans avoir satisfait toutes les exigences. Observez le message d'erreur ou le blocage.

4.  **Satisfaire les Politiques et Compléter la PR**:
    *   En tant que relecteur, approuvez la Pull Request.
    *   Si un build est requis, assurez-vous qu'il se déclenche et réussisse.
    *   Une fois toutes les politiques satisfaites, complétez la Pull Request.

## Questions de Réflexion
*   Comment les politiques de branches contribuent-elles à la qualité et à la stabilité de la branche principale ?
*   Quels sont les avantages d'exiger un build réussi avant la fusion du code ?
*   Imaginez une autre politique de branche qui pourrait être utile pour votre équipe. Décrivez-la.

## Livrables
*   Capture d'écran des politiques de branches configurées dans Azure Repos.
*   Capture d'écran d'une Pull Request montrant les politiques appliquées et leur statut.
*   Réponses aux questions de réflexion.

