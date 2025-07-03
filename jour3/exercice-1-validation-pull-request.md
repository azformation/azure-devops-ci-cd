# Exercice 1 : Valider une Pull Request avec un Pipeline de Build

**Objectif :** Créer et configurer un pipeline de build Azure DevOps qui sera utilisé pour valider une pull request afin de protéger la branche principale.

---

### Tâche 1 : Créer un pipeline de build pour la validation de pull request

1.  Dans le menu vertical de gauche du portail Azure DevOps, cliquez sur l'icône **Pipelines**.
2.  Dans le volet **Pipelines**, cliquez sur **Create Pipeline** (Créer un pipeline).
3.  Sur la page **Where is your code?** (Où est votre code ?), cliquez sur **Azure Repos Git (YAML)**.
4.  Sur la page **Select a repository** (Sélectionner un dépôt), cliquez sur le dépôt **eShopOnWeb**.
5.  Sur la page **Configure your pipeline** (Configurer votre pipeline), sélectionnez **Existing Azure Pipelines YAML file** (Utiliser un fichier YAML existant).
6.  Sur la page **Select an existing YAML file** (Sélectionner un fichier YAML existant), spécifiez les paramètres suivants :
    - **Branch** (Branche) : `main`
    - **Path** (Chemin) : `/.ado/eshoponweb-ci-pr.yml`
7.  Cliquez sur **Continue** (Continuer).
8.  Sur la page **Review your pipeline YAML** (Vérifier votre pipeline YAML), cliquez sur la flèche pointant vers le bas à côté du bouton **Run** (Exécuter), puis cliquez sur **Save** (Enregistrer).
    > **Note :** Nous n'exécutons pas le pipeline maintenant car notre objectif est de l'utiliser comme un pipeline de validation de pull request.

### Tâche 2 : Configurer la politique de branche pour la validation de build

1.  Dans le portail Azure DevOps, naviguez vers le hub **Repos**.
2.  Dans le volet **Repos**, cliquez sur **Branches**.
3.  Dans le volet **Branches**, survolez l'entrée de la branche **main** pour révéler l'icône des points de suspension (`...`) à droite.
4.  Cliquez sur les points de suspension et, dans le menu contextuel, cliquez sur **Branch policies** (Politiques de branche).
5.  Sur la page des politiques de la branche **main**, à côté de **Build Validation**, cliquez sur le bouton **+**.
6.  Dans la boîte de dialogue **Add build policy** (Ajouter une politique de build), dans la liste déroulante **Build pipeline**, sélectionnez **eShopOnWeb** et cliquez sur **Save** (Enregistrer).
    > **Note :** À partir de maintenant, toute pull request ciblant la branche `main` déclenchera automatiquement l'exécution de ce pipeline.

### Tâche 3 : Créer une pull request pour déclencher le pipeline de build

1.  Dans le portail Azure DevOps, naviguez vers le hub **Repos** > **Files** (Fichiers).
2.  Assurez-vous que la branche **main** est sélectionnée, naviguez jusqu'au fichier `/src/Web/Program.cs` et cliquez sur **Edit** (Modifier).
3.  Ajoutez un commentaire (`//`) au début du fichier pour simuler une modification.
4.  Cliquez sur **Commit** (Valider).
5.  Dans la boîte de dialogue **Commit**, sélectionnez **Create a new branch** (Créer une nouvelle branche), tapez `test-pr` dans le champ **Branch name** (Nom de la branche), cochez la case **Create a pull request**, puis cliquez sur **Commit**.
6.  Sur la page **New pull request**, cliquez sur **Create**.
7.  Vérifiez que la pull request a été créée et que la build de validation a été automatiquement déclenchée.
8.  Attendez que la build se termine avec succès, puis cliquez sur **Complete** et **Complete merge** pour finaliser la fusion.

