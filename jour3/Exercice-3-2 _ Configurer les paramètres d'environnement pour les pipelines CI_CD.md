# Exercice 2 : Configurer les paramètres d'environnement pour les pipelines CI/CD en tant que code avec YAML dans Azure DevOps

## Vue d'ensemble
Dans cet exercice, vous allez ajouter des approbations à un pipeline basé sur YAML dans Azure DevOps.

## Durée estimée
15 minutes

## Prérequis
- Avoir terminé l'[Exercice 1 : Configurer les pipelines CI/CD](./exercice_1_pipelines_cicd.md)

## Contexte
Les pipelines YAML en tant que code n'ont pas de portes de release/qualité comme nous en avons avec les pipelines de release classiques Azure DevOps. Cependant, certaines similitudes peuvent être configurées pour les pipelines YAML en tant que code en utilisant les environnements.

## Tâches

### Tâche 1 : Configurer les environnements de pipeline

Dans cette tâche, vous utiliserez le mécanisme d'environnements pour configurer les approbations pour l'étape de build.

#### Étapes

1.  Depuis le projet Azure DevOps **eShopOnWeb\_MultiStageYAML**, naviguez vers **Pipelines**.

2.  Sous le menu **Pipelines** à gauche, sélectionnez **Environnements**.

3.  Cliquez sur **Créer un environnement**.

4.  Dans le volet **Nouvel environnement**, ajoutez un **Nom** pour l'environnement, appelé **approvals**.

5.  Sous **Ressources**, sélectionnez **Aucune**.

6.  Confirmez les paramètres en appuyant sur le bouton **Créer**.

7.  Une fois l'environnement créé, sélectionnez l'onglet **Approbations et vérifications** du nouvel environnement **approvals**.

8.  Depuis **Ajouter votre première vérification**, sélectionnez **Approbations**.

9.  Ajoutez votre **Nom de compte utilisateur Azure DevOps** au champ **approbateurs**.
    
    > **Note** : Dans un scénario réel, cela refléterait le nom de votre équipe DevOps travaillant sur ce projet.

10. Confirmez les paramètres d'approbation définis en appuyant sur le bouton **Créer**.

### Tâche 2 : Modifier le pipeline YAML pour utiliser l'environnement

Dans cette tâche, vous allez modifier le pipeline pour utiliser l'environnement d'approbation créé.

#### Étapes

1.  Naviguez vers **Repos**, parcourez le dossier **.ado**, et sélectionnez le fichier pipeline en tant que code **eshoponweb-ci.yml**.

2.  Depuis la vue **Contenu**, cliquez sur le bouton **Modifier** pour passer en mode d'édition.

3.  Naviguez vers le début de la tâche **Deploy** (**-job: Deploy** à la ligne 60)

4.  Ajoutez une nouvelle ligne vide juste en dessous, et ajoutez l'extrait suivant :
    
    ```yaml
    environment: approvals
    ```
    
    L'extrait de code résultant devrait ressembler à ceci :
    
    ```yaml
    jobs:
      - job: Deploy
        environment: approvals
        pool:
          vmImage: "windows-latest"
    ```

5.  Comme l'environnement est un paramètre spécifique d'une étape de déploiement, il ne peut pas être utilisé par les "jobs". Par conséquent, nous devons apporter quelques modifications supplémentaires à la définition de tâche actuelle.

6.  À la ligne 60, renommez "**- job: Deploy**" en **- deployment: Deploy**

7.  Ensuite, sous la ligne 63 (**vmImage: windows-latest**), ajoutez une nouvelle ligne vide.

8.  Collez l'extrait Yaml suivant :
    
    ```yaml
    strategy:
      runOnce:
        deploy:
    ```

9.  Sélectionnez l'extrait restant (ligne 67 jusqu'à la fin), et utilisez la touche **Tab** pour corriger l'indentation YAML.
    
    L'extrait YAML résultant devrait maintenant ressembler à ceci, reflétant l'étape de déploiement :
    
    ```yaml
    - stage: Deploy
      displayName: Deploy to an Azure Web App
      jobs:
        - deployment: Deploy
          environment: approvals
          pool:
            vmImage: "windows-latest"
          strategy:
            runOnce:
              deploy:
                steps:
                  - task: DownloadBuildArtifacts@1
                    inputs:
                      buildType: "current"
                      downloadType: "single"
                      artifactName: "Website"
                      downloadPath: "$(Build.ArtifactStagingDirectory)"
                  - task: AzureRmWebAppDeployment@4
                    inputs:
                      ConnectionType: "AzureRM"
                      azureSubscription: "AZURE SUBSCRIPTION HERE (b999999abc-1234-987a-a1e0-27fb2ea7f9f4)"
                      appType: "webApp"
                      WebAppName: "eshoponWebYAML369825031"
                      packageForLinux: "$(Build.ArtifactStagingDirectory)/**/Web.zip"
                      AppSettings: "-UseOnlyInMemoryDatabase true -ASPNETCORE_ENVIRONMENT Development"
    ```

10. Confirmez les modifications du fichier de code YAML en cliquant sur **Valider** et en cliquant à nouveau sur **Valider** dans le volet **Valider** qui apparaît.

### Tâche 3 : Tester le processus d'approbation

Dans cette tâche, vous allez tester le nouveau processus d'approbation.

#### Étapes

1.  Naviguez vers le menu du projet Azure DevOps à gauche, sélectionnez **Pipelines**, sélectionnez **Pipelines** et remarquez le pipeline **EshopOnWeb\_MultiStageYAML** utilisé précédemment.

2.  Ouvrez le pipeline.

3.  Cliquez sur **Exécuter le pipeline** pour déclencher une nouvelle exécution de pipeline ; confirmez en cliquant sur **Exécuter**.

4.  Tout comme avant, l'étape **Build** démarre comme prévu. Attendez qu'elle se termine avec succès.

5.  Ensuite, puisque nous avons l'**environment:approvals** configuré pour l'étape de déploiement, il demandera une confirmation d'approbation avant de démarrer.

6.  Ceci est visible depuis la vue du pipeline, où il indique **En attente (1 vérification en cours)**. Un message de notification s'affiche également indiquant **1 approbation nécessite un examen avant que cette exécution puisse continuer vers Déployer vers une application web Azure**.

7.  Cliquez sur le bouton **Examiner** à côté de ce message.

8.  Depuis le volet qui apparaît **En attente d'examen**, cliquez sur le bouton **Approuver**.

9.  Cela permet à l'étape de déploiement de démarrer et de déployer avec succès le code source de l'application web Azure.

## Points clés à retenir

- Les environnements Azure DevOps permettent d'ajouter des contrôles de qualité aux pipelines YAML
- Les approbations manuelles peuvent être configurées pour contrôler les déploiements
- D'autres types de vérifications sont disponibles (Azure Monitor, API REST, etc.)
- La transformation de `job` en `deployment` est nécessaire pour utiliser les environnements
- Les stratégies de déploiement comme `runOnce` offrent plus de contrôle sur le processus

## Nettoyage

> **[!IMPORTANT]** N'oubliez pas de supprimer les ressources créées dans le portail Azure pour éviter des frais inutiles.

Pour supprimer les ressources :

1. Connectez-vous au portail Azure
2. Naviguez vers le groupe de ressources **az400m03l07-RG**
3. Cliquez sur **Supprimer le groupe de ressources**
4. Confirmez la suppression en tapant le nom du groupe de ressources

## Révision

Dans ce laboratoire, vous avez configuré des pipelines CI/CD en tant que code avec YAML dans Azure DevOps, incluant :

- La création d'un pipeline de build YAML
- L'ajout d'une étape de déploiement
- La configuration d'environnements avec approbations
- Le test du processus complet de CI/CD avec contrôles de qualité

Ces compétences sont essentielles pour implémenter des pratiques DevOps modernes avec Azure DevOps.

