# Exercice 0 : Configurer les prérequis du laboratoire

## Vue d'ensemble
Dans cet exercice, vous allez configurer les prérequis pour le laboratoire.

## Durée estimée
15 minutes

## Tâches

### Tâche 1 : (ignorer si déjà fait) Créer et configurer le projet d'équipe

Dans cette tâche, vous allez créer un projet Azure DevOps **eShopOnWeb\_MultiStageYAML** à utiliser par plusieurs laboratoires.

#### Étapes

1.  Sur votre ordinateur de laboratoire, dans une fenêtre de navigateur, ouvrez votre organisation Azure DevOps. Cliquez sur **Nouveau Projet**. Donnez à votre projet le nom **eShopOnWeb\_MultiStageYAML** et laissez les autres champs avec les valeurs par défaut. Cliquez sur **Créer**.

### Tâche 2 : (ignorer si déjà fait) Importer le référentiel Git eShopOnWeb

Dans cette tâche, vous allez importer le référentiel Git eShopOnWeb qui sera utilisé par plusieurs laboratoires.

#### Étapes

1.  Sur votre ordinateur de laboratoire, dans une fenêtre de navigateur, ouvrez votre organisation Azure DevOps et le projet **eShopOnWeb\_MultiStageYAML** créé précédemment. Cliquez sur **Repos > Fichiers**, **Importer un référentiel**. Sélectionnez **Importer**. Dans la fenêtre **Importer un référentiel Git**, collez l'URL suivante https://github.com/MicrosoftLearning/eShopOnWeb.git et cliquez sur **Importer** :
    
2.  Le référentiel est organisé de la manière suivante :
    *   Le dossier **.ado** contient les pipelines YAML Azure DevOps.
    *   Le dossier **.devcontainer** contient la configuration pour développer en utilisant des conteneurs (soit localement dans VS Code ou GitHub Codespaces).
    *   Le dossier **infra** contient les modèles d'infrastructure en tant que code Bicep et ARM utilisés dans certains scénarios de laboratoire.
    *   Le dossier **.github** contient les définitions de workflow YAML GitHub.
    *   Le dossier **src** contient le site web .NET 8 utilisé dans les scénarios de laboratoire.
    
3.  Allez dans **Repos > Branches**.

4.  Survolez la branche **main** puis cliquez sur les points de suspension à droite de la colonne.

5.  Cliquez sur **Définir comme branche par défaut**.
    
    > **Note** : si la branche main est déjà la branche par défaut, l'option **Définir comme branche par défaut** est grisée. Dans ce cas, continuez avec les instructions

### Tâche 3 : Créer des ressources Azure

Dans cette tâche, vous allez créer une application web Azure en utilisant le portail Azure.

#### Étapes

1.  Depuis l'ordinateur de laboratoire, démarrez un navigateur web, naviguez vers le [**Portail Azure**](), et connectez-vous avec le compte utilisateur qui a le rôle Propriétaire dans l'abonnement Azure que vous utiliserez dans ce laboratoire et qui a le rôle d'Administrateur global dans le locataire Microsoft Entra associé à cet abonnement.

2.  Dans le portail Azure, dans la barre d'outils, cliquez sur l'icône **Cloud Shell** située directement à droite de la zone de texte de recherche.

3.  Si vous êtes invité à sélectionner **Bash** ou **PowerShell**, sélectionnez **Bash**.
    
    > **Note** : Si c'est la première fois que vous démarrez **Cloud Shell** et que vous voyez la fenêtre contextuelle **Prise en main**, sélectionnez **Aucun compte de stockage requis** et l'abonnement que vous utilisez dans ce laboratoire, puis cliquez sur **Appliquer**.

4.  Depuis l'invite **Bash**, dans le volet **Cloud Shell**, exécutez la commande suivante pour créer un groupe de ressources (remplacez l'espace réservé `<region>` par le nom de la région Azure la plus proche de vous comme 'centralus', 'westeurope' ou autre région de votre choix).
    
    ```bash
    LOCATION='<region>'
    ```
    
    ```bash
    RESOURCEGROUPNAME='<votre-prénom-RG'
    ```

5.  Pour créer un plan de service d'application Windows en exécutant la commande suivante :
    
    ```bash
    SERVICEPLANNAME='az400m03l07-sp1'
    az appservice plan create --resource-group $RESOURCEGROUPNAME --name $SERVICEPLANNAME --sku B3
    ```
    
    > **Note** : Si vous obtenez une erreur comme "L'abonnement n'est pas enregistré pour utiliser l'espace de noms 'Microsoft.Web'" lorsque vous exécutez la commande précédente, exécutez la commande suivante `az provider register --namespace Microsoft.Web` puis exécutez à nouveau la commande qui a généré l'erreur.

6.  Créez une application web avec un nom unique.
    
    ```bash
    WEBAPPNAME=eshoponWebYAML$RANDOM$RANDOM
    az webapp create --resource-group $RESOURCEGROUPNAME --plan $SERVICEPLANNAME --name $WEBAPPNAME
    ```
    
    > **Note** : Notez le nom de l'application web. Vous en aurez besoin plus tard dans ce laboratoire.

7.  Fermez Azure Cloud Shell, mais laissez le portail Azure ouvert dans le navigateur.

## Points clés à retenir

- Assurez-vous d'avoir créé le projet Azure DevOps avec le bon nom
- Le référentiel eShopOnWeb contient tous les fichiers nécessaires pour les exercices suivants
- Notez bien le nom de l'application web Azure créée, vous en aurez besoin dans les exercices suivants
- Les ressources Azure créées génèrent des coûts, pensez à les supprimer après le laboratoire

## Prochaine étape

Une fois ces prérequis terminés, vous pouvez passer à l'[Exercice 1 : Configurer les pipelines CI/CD](./exercice_1_pipelines_cicd.md).

