# Exercice 2 : Configurer un Pipeline d'Intégration Continue (CI) avec YAML

**Objectif :** Créer et configurer un pipeline d'intégration continue Azure DevOps avec YAML qui se déclenchera à chaque modification de la branche principale.

---

### Tâche 1 : Créer un pipeline de build d'intégration continue

1.  Dans le menu vertical de gauche du portail Azure DevOps, cliquez sur l'icône **Pipelines**.
2.  Dans le volet **Pipelines**, cliquez sur **Create Pipeline** (Créer un pipeline).
3.  Sur la page **Where is your code?**, cliquez sur **Azure Repos Git (YAML)**.
4.  Sur la page **Select a repository**, cliquez sur le dépôt **eShopOnWeb**.
5.  Sur la page **Configure your pipeline**, sélectionnez **Existing Azure Pipelines YAML file**.
6.  Sur la page **Select an existing YAML file**, spécifiez les paramètres suivants :
    - **Branch** (Branche) : `main`
    - **Path** (Chemin) : `/.ado/eshoponweb-ci.yml`
7.  Cliquez sur **Continue**.
8.  Sur la page **Review your pipeline YAML**, examinez le contenu du pipeline.
    > **Note :** Le pipeline est composé des tâches suivantes :
    > - **dotnet restore** : restaure les dépendances NuGet.
    > - **dotnet build** : compile le projet.
    > - **dotnet test** : exécute les tests unitaires.
    > - **dotnet publish** : publie les sorties du projet.
    > - **Publish build artifacts** : publie les artefacts générés.
9.  Sur la page **Review your pipeline YAML**, cliquez sur **Run** (Exécuter).
    > **Note :** Le déclencheur (`trigger`) de ce pipeline est configuré pour s'exécuter à chaque commit sur la branche `main`. Comme vous venez de fusionner une pull request dans la branche `main` (à la fin de l'exercice 1), le pipeline devrait déjà être en cours d'exécution ou s'être exécuté.
10. Dans le volet **Pipelines**, cliquez sur l'entrée représentant la nouvelle build pour surveiller sa progression.
11. Attendez que la build se termine.
12. Une fois la build terminée, l'onglet **Summary** (Résumé) affichera les détails de l'exécution. Dans la section **Related** (Associé), cliquez sur le lien **1 published** pour voir les artefacts de build.