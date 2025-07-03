# Exercice 1 : Configurer les pipelines CI/CD en tant que code avec YAML dans Azure DevOps

## Vue d'ensemble
Dans cet exercice, vous allez configurer les pipelines CI/CD en tant que code avec YAML dans Azure DevOps.

## Durée estimée
20 minutes

## Prérequis
- Avoir terminé l'[Exercice 0 : Configurer les prérequis du laboratoire](./exercice_0_prerequis.md)

## Tâches

### Tâche 1 : Ajouter une définition de build YAML

Dans cette tâche, vous allez ajouter une définition de build YAML au projet existant.

#### Étapes

1.  Retournez au volet **Pipelines** du hub **Pipelines**.

2.  Dans la fenêtre **Créer votre premier pipeline**, cliquez sur **Créer un pipeline**.
    
    > **Note** : Nous utiliserons l'assistant pour créer une nouvelle définition de pipeline YAML basée sur notre projet.

3.  Dans le volet **Où est votre code ?**, cliquez sur l'option **Azure Repos Git (YAML)**.

4.  Dans le volet **Sélectionner un référentiel**, cliquez sur **eShopOnWeb\_MultiStageYAML**.

5.  Dans le volet **Configurer votre pipeline**, faites défiler vers le bas et sélectionnez **Fichier YAML Azure Pipelines existant**.

6.  Dans le panneau **Sélection d'un fichier YAML existant**, spécifiez les paramètres suivants :
    *   Branche : **main**
    *   Chemin : **.ado/eshoponweb-ci.yml**

7.  Cliquez sur **Continuer** pour enregistrer ces paramètres.

8.  Depuis l'écran **Examiner votre pipeline YAML**, cliquez sur **Exécuter** pour démarrer le processus de pipeline de build.

9.  Attendez que le pipeline de build se termine avec succès. Ignorez tous les avertissements concernant le code source lui-même, car ils ne sont pas pertinents pour cet exercice de laboratoire.
    
    > **Note** : Chaque tâche du fichier YAML est disponible pour examen, y compris tous les avertissements et erreurs.

### Tâche 2 : Ajouter la livraison continue à la définition YAML

Dans cette tâche, vous allez ajouter la livraison continue à la définition basée sur YAML du pipeline que vous avez créé dans la tâche précédente.

> **Note** : Maintenant que les processus de build et de test sont réussis, nous pouvons maintenant ajouter la livraison à la définition YAML.

#### Étapes

1.  Dans le volet d'exécution du pipeline, cliquez sur le symbole des points de suspension dans le coin supérieur droit et, dans le menu déroulant, cliquez sur **Modifier le pipeline**.

2.  Dans le volet affichant le contenu du fichier **eShopOnWeb\_MultiStageYAML/.ado/eshoponweb-ci.yml**, naviguez jusqu'à la fin du fichier (ligne 56), et appuyez sur **Entrée/Retour** pour ajouter une nouvelle ligne vide.

3.  En étant sur la ligne **57**, ajoutez le contenu suivant pour définir l'étape **Release** dans le pipeline YAML.
    
    > **Note** : Vous pouvez définir les étapes dont vous avez besoin pour mieux organiser et suivre la progression du pipeline.
    
    ```yaml
    - stage: Deploy
      displayName: Deploy to an Azure Web App
      jobs:
      - job: Deploy
        pool:
          vmImage: 'windows-latest'
        steps:
        - task: DownloadBuildArtifacts@1
          inputs:
            buildType: 'current'
            downloadType: 'single'
            artifactName: 'Website'
            downloadPath: '$(Build.ArtifactStagingDirectory)'
        - task: AzureRmWebAppDeployment@4
          inputs:
            ConnectionType: 'AzureRM'
            azureSubscription: 'AZURE SUBSCRIPTION HERE (b999999abc-1234-987a-a1e0-27fb2ea7f9f4)'
            appType: 'webApp'
            WebAppName: 'eshoponWebYAML369825031'
            packageForLinux: '$(Build.ArtifactStagingDirectory)/**/Web.zip'
            AppSettings: '-UseOnlyInMemoryDatabase true -ASPNETCORE_ENVIRONMENT Development'
    ```

4.  Si la valeur du paramètre **WebAppName** (eshoponWebYAML369825031) diffère du nom de l'application web que vous avez créée plus tôt dans ce laboratoire, remplacez-la par ce dernier.

5.  Si la valeur du paramètre **azureSubscription** diffère du nom de l'abonnement Azure que vous utilisez dans ce laboratoire, remplacez-la par ce dernier.
    
    > **Note** : Pour identifier le nom de votre abonnement, dans le portail Azure, dans la zone de texte **Rechercher des ressources, services et documents**, tapez **Abonnements** et, dans la liste des résultats, cliquez sur **Abonnements**. Le nom de l'abonnement est répertorié dans la colonne **Nom de l'abonnement**.
    
    > **Note** : Pour identifier le nom de votre connexion de service, dans le portail Azure DevOps, ouvrez les **Paramètres du projet**, dans la section **Pipelines**, cliquez sur **Connexions de service**. Le nom de la connexion de service est répertorié dans la colonne **Nom**. Vous pouvez également créer une nouvelle connexion de service en utilisant le bouton **Nouvelle connexion de service**.

6.  Dans le coin supérieur droit du volet, cliquez sur **Enregistrer** et, dans le volet **Enregistrer**, cliquez à nouveau sur **Enregistrer**. Cela déclenchera automatiquement le build basé sur ce pipeline.

7.  Dans le portail Azure DevOps, dans le volet de navigation vertical sur le côté gauche, dans la section **Pipelines**, cliquez sur **Pipelines**.

8.  Dans le volet **Pipelines**, cliquez sur l'entrée représentant le pipeline nouvellement créé.

9.  Dans le volet **eShopOnWeb\_MultiStageYAML**, cliquez sur l'entrée représentant l'exécution la plus récente.

10. Dans le volet d'exécution du pipeline, examinez la disposition du volet, qui comprend :
    *   La représentation des tâches incluses dans le pipeline dans la section **Tâches**.
    *   L'état actuel de l'exécution du pipeline dans la partie supérieure du volet.

11. Dans la section **Tâches**, cliquez sur **Build** et, dans le volet résultant, examinez les tâches incluses dans la tâche.

12. Retournez au volet d'exécution du pipeline en cliquant sur la flèche de retour dans le coin supérieur gauche du volet.

13. Dans la section **Tâches**, cliquez sur **Deploy** et, dans le volet résultant, examinez les tâches incluses dans la tâche.

14. Attendez que les deux tâches se terminent avec succès.

15. Retournez au volet d'exécution du pipeline en cliquant sur la flèche de retour dans le coin supérieur gauche du volet.

16. Notez qu'à ce stade, vous avez implémenté avec succès un pipeline CI/CD qui construit et déploie une application en utilisant un pipeline Azure DevOps basé sur YAML.

### Tâche 3 : Examiner le site déployé

Dans cette tâche, vous allez vérifier que l'application a été correctement déployée.

#### Étapes

1.  Retournez à la fenêtre du navigateur web affichant le portail Azure.

2.  Dans le portail Azure, naviguez vers le panneau affichant les propriétés de l'application web Azure que vous avez déployée plus tôt dans ce laboratoire.

3.  Dans le panneau de l'application web Azure, cliquez sur **Parcourir** pour ouvrir votre site dans un nouvel onglet de navigateur web.

4.  Vérifiez que le site déployé se charge comme prévu dans le nouvel onglet du navigateur, affichant le site web de commerce électronique eShopOnWeb.

## Points clés à retenir

- Les pipelines YAML permettent de définir l'infrastructure de déploiement en tant que code
- Un pipeline multi-étapes permet de séparer clairement les phases de build et de déploiement
- Les artefacts de build sont automatiquement transmis entre les étapes
- La configuration YAML est versionnée avec le code source

## Prochaine étape

Une fois cet exercice terminé, vous pouvez passer à l'[Exercice 2 : Configurer les environnements](./exercice_2_environnements.md).

