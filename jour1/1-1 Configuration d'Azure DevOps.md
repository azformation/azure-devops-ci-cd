### Tutoriel : Configuration d'Azure DevOps avec un processus Scrum

#### Partie 2 : Configuration d'Azure DevOps

##### Étape 1 : Créer un nouveau projet dans Azure DevOps

1. **Se connecter à Azure DevOps :**
   - Rendez-vous sur [Azure DevOps](https://dev.azure.com) et connectez-vous avec votre compte Microsoft.

2. **Créer un nouveau projet :**
   - Cliquez sur "New Project".
   - Entrez le nom du projet : `DevOpsTraining-[votre-nom]` en remplaçant `[votre-nom]` par votre nom.
   - Choisissez la visibilité du projet (public ou privé).
   - Sélectionnez la méthodologie "Scrum" pour configurer Azure Boards.
   - Cliquez sur "Create".

##### Étape 2 : Configurer Azure Boards avec une méthodologie Scrum

1. **Accéder à Azure Boards :**
   - Dans votre nouveau projet, allez dans le menu de gauche et sélectionnez "Boards", puis "Backlogs" pour accéder à la vue du backlog produit.

2. **Créer un backlog produit :**

   - **Ajouter un Product Backlog Item :**
     - Cliquez sur le bouton "+ New Work Item" ou "+ Add to top" pour ajouter un nouveau Product Backlog Item.
     - Une nouvelle ligne apparaîtra dans votre backlog où vous pourrez entrer les détails du PBI.

   - **Remplir les Détails du Product Backlog Item :**
     - **Titre :** Donnez un titre clair et concis au PBI. Par exemple, "En tant qu'utilisateur, je veux pouvoir me connecter afin d'accéder à mon compte."
     - **Description :** Ajoutez une description détaillée incluant des critères d'acceptation ou des détails supplémentaires sur ce que le PBI doit accomplir.

   - **Ajouter Cinq Product Backlog Items :**
     - Répétez le processus d'ajout en cliquant sur "+ New Work Item" pour chaque nouveau PBI. Voici des exemples de titres pour cinq PBI :
       1. "En tant qu'utilisateur, je veux pouvoir réinitialiser mon mot de passe afin de regagner l'accès à mon compte si je l'oublie."
       2. "En tant qu'utilisateur, je veux pouvoir mettre à jour mon profil afin de garder mes informations à jour."
       3. "En tant qu'utilisateur, je veux recevoir des notifications par e-mail pour les mises à jour importantes."
       4. "En tant qu'administrateur, je veux pouvoir voir une liste de tous les utilisateurs afin de gérer les comptes."
       5. "En tant qu'utilisateur, je veux pouvoir télécharger des fichiers afin de les partager avec d'autres utilisateurs."

   - **Sauvegarder et Organiser :**
     - Assurez-vous que tous les PBI sont sauvegardés.
     - Les PBI sont automatiquement ajoutés au "Sprint 1" par défaut.

##### Étape 3 : Vérifier le Sprint 1

1. **Accéder au Sprint 1 :**
   - Allez dans "Boards" > "Sprints".
   - Vous verrez que "Sprint 1" est déjà créé par défaut et contient les PBI que vous avez ajoutés.

##### Étape 4 : Configurer Azure Repos pour utiliser Git

1. **Configurer Azure Repos :**
   - Allez dans "Repos" dans le menu de gauche.
   - Initialisez un dépôt Git en cliquant sur "Initialize" pour créer un dépôt vide ou avec un fichier README.md.

##### Étape 5 : Établir une connexion entre votre dépôt GitHub et Azure DevOps

1. **Configurer la connexion GitHub :**
   - Allez dans "Project Settings" en bas à gauche.
   - Dans le menu "Project Settings", trouvez et cliquez sur "Service connections" sous la section "Pipelines".
   - Cliquez sur "New service connection" et choisissez "GitHub".
   - Vous serez redirigé vers une nouvelle fenêtre pour configurer la connexion GitHub.
   - Choisissez le type d'autorisation (OAuth est généralement recommandé pour une connexion sécurisée).
   - Suivez les instructions pour autoriser Azure DevOps à accéder à votre compte GitHub.
   - Une fois l'autorisation accordée, donnez un nom à votre connexion de service et enregistrez-la.

### Conclusion

Vous avez maintenant configuré un projet Azure DevOps avec un backlog produit, un sprint par défaut (Sprint 1) contenant vos PBI, et une connexion à un dépôt GitHub. Cela vous permet de gérer vos projets de développement de manière efficace en utilisant les outils de gestion de projet et de contrôle de version intégrés.