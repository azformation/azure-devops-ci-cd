# Exercice 1 : Automatisation avec Azure CLI

## Objectifs
- Maîtriser les commandes Azure CLI pour Azure DevOps
- Automatiser la création et la gestion de projets
- Créer des scripts de déploiement automatisés

## Prérequis
- Azure CLI installé et configuré
- Extension Azure DevOps pour Azure CLI installée
- Accès à une organisation Azure DevOps
- Personal Access Token (PAT) configuré

## Durée estimée
45 minutes

## Contexte
Vous êtes développeur DevOps dans une entreprise qui souhaite automatiser la création de nouveaux projets et la configuration des pipelines CI/CD. Votre mission est de créer un script Azure CLI qui automatise ces tâches répétitives.

## Étape 1 : Configuration initiale (10 minutes)

### 1.1 Vérification de l'installation
Vérifiez que Azure CLI et l'extension Azure DevOps sont correctement installés :

```bash
# Vérifier la version d'Azure CLI
az --version

# Vérifier l'extension Azure DevOps
az extension list --query "[?name=='azure-devops'].version"

# Si l'extension n'est pas installée
az extension add --name azure-devops
```

### 1.2 Configuration de l'organisation par défaut
Configurez votre organisation Azure DevOps par défaut :

```bash
# Remplacez par votre organisation
az devops configure --defaults organization=https://dev.azure.com/votre-organisation

# Connexion avec votre PAT
az devops login
```

### 1.3 Test de connectivité
Testez la connexion en listant vos projets existants :

```bash
az devops project list --output table
```

## Étape 2 : Création d'un script de gestion de projet (15 minutes)

### 2.1 Création du script principal
Créez un fichier `create-project.sh` (Linux/macOS) ou `create-project.bat` (Windows) :

```bash
#!/bin/bash
# Script de création automatisée d'un projet Azure DevOps
# Auteur: Votre nom
# Date: $(date +%Y-%m-%d)

# Paramètres
PROJECT_NAME="$1"
PROJECT_DESCRIPTION="$2"
REPO_NAME="$3"

# Validation des paramètres
if [ -z "$PROJECT_NAME" ] || [ -z "$PROJECT_DESCRIPTION" ] || [ -z "$REPO_NAME" ]; then
    echo "Usage: $0 <nom_projet> <description> <nom_repo>"
    echo "Exemple: $0 'MonProjet' 'Description du projet' 'mon-repo'"
    exit 1
fi

echo "=== Création du projet Azure DevOps ==="
echo "Nom du projet: $PROJECT_NAME"
echo "Description: $PROJECT_DESCRIPTION"
echo "Nom du dépôt: $REPO_NAME"
echo

# Création du projet
echo "Étape 1: Création du projet..."
PROJECT_ID=$(az devops project create \
    --name "$PROJECT_NAME" \
    --description "$PROJECT_DESCRIPTION" \
    --visibility private \
    --query "id" \
    --output tsv)

if [ $? -eq 0 ]; then
    echo "✓ Projet créé avec succès (ID: $PROJECT_ID)"
else
    echo "✗ Erreur lors de la création du projet"
    exit 1
fi

# Attendre que le projet soit complètement initialisé
echo "Attente de l'initialisation du projet..."
sleep 10

# Création du dépôt Git
echo "Étape 2: Création du dépôt Git..."
REPO_ID=$(az repos create \
    --name "$REPO_NAME" \
    --project "$PROJECT_NAME" \
    --query "id" \
    --output tsv)

if [ $? -eq 0 ]; then
    echo "✓ Dépôt créé avec succès (ID: $REPO_ID)"
else
    echo "✗ Erreur lors de la création du dépôt"
fi

# Affichage des informations du projet
echo
echo "=== Résumé ==="
echo "Projet: $PROJECT_NAME"
echo "URL du projet: https://dev.azure.com/$(az devops configure -l | grep organization | cut -d'=' -f2 | sed 's|https://dev.azure.com/||')/$PROJECT_NAME"
echo "Dépôt: $REPO_NAME"
echo
echo "Prochaines étapes:"
echo "1. Cloner le dépôt: az repos list --project '$PROJECT_NAME' --query '[0].remoteUrl'"
echo "2. Configurer les politiques de branche"
echo "3. Créer les pipelines CI/CD"
```

### 2.2 Test du script
Rendez le script exécutable et testez-le :

```bash
# Linux/macOS
chmod +x create-project.sh
./create-project.sh "Projet-Test-CLI" "Projet de test pour l'exercice Azure CLI" "test-repo"

# Windows
create-project.bat "Projet-Test-CLI" "Projet de test pour l'exercice Azure CLI" "test-repo"
```

## Étape 3 : Automatisation des pipelines (15 minutes)

### 3.1 Création d'un fichier de pipeline YAML
Créez un fichier `azure-pipelines.yml` basique :

```yaml
# Pipeline CI/CD basique
trigger:
- main

pool:
  vmImage: 'ubuntu-latest'

variables:
  buildConfiguration: 'Release'

stages:
- stage: Build
  displayName: 'Build stage'
  jobs:
  - job: Build
    displayName: 'Build job'
    steps:
    - task: DotNetCoreCLI@2
      displayName: 'Restore packages'
      inputs:
        command: 'restore'
        projects: '**/*.csproj'

    - task: DotNetCoreCLI@2
      displayName: 'Build application'
      inputs:
        command: 'build'
        projects: '**/*.csproj'
        arguments: '--configuration $(buildConfiguration)'

    - task: DotNetCoreCLI@2
      displayName: 'Run tests'
      inputs:
        command: 'test'
        projects: '**/*Tests.csproj'
        arguments: '--configuration $(buildConfiguration) --collect "Code coverage"'

- stage: Deploy
  displayName: 'Deploy stage'
  dependsOn: Build
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:
  - deployment: Deploy
    displayName: 'Deploy job'
    environment: 'production'
    strategy:
      runOnce:
        deploy:
          steps:
          - script: echo "Déploiement en cours..."
            displayName: 'Deploy application'
```

### 3.2 Script de création de pipeline
Créez un script `create-pipeline.sh` pour automatiser la création de pipelines :

```bash
#!/bin/bash
# Script de création de pipeline Azure DevOps

PROJECT_NAME="$1"
PIPELINE_NAME="$2"
REPO_NAME="$3"
YAML_PATH="${4:-azure-pipelines.yml}"

if [ -z "$PROJECT_NAME" ] || [ -z "$PIPELINE_NAME" ] || [ -z "$REPO_NAME" ]; then
    echo "Usage: $0 <nom_projet> <nom_pipeline> <nom_repo> [chemin_yaml]"
    exit 1
fi

echo "=== Création du pipeline ==="
echo "Projet: $PROJECT_NAME"
echo "Pipeline: $PIPELINE_NAME"
echo "Dépôt: $REPO_NAME"
echo "Fichier YAML: $YAML_PATH"
echo

# Création du pipeline
PIPELINE_ID=$(az pipelines create \
    --name "$PIPELINE_NAME" \
    --description "Pipeline CI/CD pour $REPO_NAME" \
    --repository "$REPO_NAME" \
    --repository-type tfsgit \
    --branch main \
    --yml-path "$YAML_PATH" \
    --project "$PROJECT_NAME" \
    --query "id" \
    --output tsv)

if [ $? -eq 0 ]; then
    echo "✓ Pipeline créé avec succès (ID: $PIPELINE_ID)"
    
    # Exécution du pipeline
    echo "Lancement du premier build..."
    BUILD_ID=$(az pipelines run \
        --name "$PIPELINE_NAME" \
        --project "$PROJECT_NAME" \
        --query "id" \
        --output tsv)
    
    if [ $? -eq 0 ]; then
        echo "✓ Build lancé avec succès (ID: $BUILD_ID)"
        echo "Suivi du build: az pipelines build show --id $BUILD_ID --project '$PROJECT_NAME'"
    fi
else
    echo "✗ Erreur lors de la création du pipeline"
fi
```

## Étape 4 : Script de gestion complète (10 minutes)

### 4.1 Script maître
Créez un script `setup-complete-project.sh` qui combine toutes les étapes :

```bash
#!/bin/bash
# Script de configuration complète d'un projet Azure DevOps

set -e  # Arrêter en cas d'erreur

# Paramètres
PROJECT_NAME="$1"
PROJECT_DESCRIPTION="$2"
REPO_NAME="$3"
PIPELINE_NAME="${4:-$REPO_NAME-CI}"

# Validation
if [ -z "$PROJECT_NAME" ] || [ -z "$PROJECT_DESCRIPTION" ] || [ -z "$REPO_NAME" ]; then
    echo "Usage: $0 <nom_projet> <description> <nom_repo> [nom_pipeline]"
    exit 1
fi

echo "=== Configuration complète du projet Azure DevOps ==="
echo "Projet: $PROJECT_NAME"
echo "Description: $PROJECT_DESCRIPTION"
echo "Dépôt: $REPO_NAME"
echo "Pipeline: $PIPELINE_NAME"
echo

# Fonction de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Fonction de gestion d'erreur
handle_error() {
    echo "❌ Erreur à l'étape: $1"
    echo "Nettoyage en cours..."
    # Optionnel: supprimer le projet en cas d'erreur
    # az devops project delete --id "$PROJECT_ID" --yes
    exit 1
}

# Étape 1: Création du projet
log "Création du projet..."
PROJECT_ID=$(az devops project create \
    --name "$PROJECT_NAME" \
    --description "$PROJECT_DESCRIPTION" \
    --visibility private \
    --query "id" \
    --output tsv) || handle_error "Création du projet"

log "✓ Projet créé (ID: $PROJECT_ID)"

# Étape 2: Attente de l'initialisation
log "Attente de l'initialisation du projet..."
sleep 15

# Étape 3: Création du dépôt
log "Création du dépôt Git..."
REPO_ID=$(az repos create \
    --name "$REPO_NAME" \
    --project "$PROJECT_NAME" \
    --query "id" \
    --output tsv) || handle_error "Création du dépôt"

log "✓ Dépôt créé (ID: $REPO_ID)"

# Étape 4: Configuration des politiques de branche
log "Configuration des politiques de branche..."
az repos policy create \
    --project "$PROJECT_NAME" \
    --repository-id "$REPO_ID" \
    --branch "main" \
    --policy-type "Minimum number of reviewers" \
    --minimum-approver-count 1 \
    --creator-vote-counts false \
    --allow-downvotes false \
    --reset-on-source-push true || log "⚠️ Politique de branche non configurée"

# Étape 5: Création du fichier de pipeline (si nécessaire)
YAML_FILE="azure-pipelines.yml"
if [ ! -f "$YAML_FILE" ]; then
    log "Création du fichier de pipeline par défaut..."
    cat > "$YAML_FILE" << 'EOF'
trigger:
- main

pool:
  vmImage: 'ubuntu-latest'

steps:
- script: echo "Hello, World!"
  displayName: 'Run a one-line script'

- script: |
    echo "Add other tasks to build, test, and deploy your project."
    echo "See https://aka.ms/yaml"
  displayName: 'Run a multi-line script'
EOF
fi

# Étape 6: Affichage du résumé
log "=== Configuration terminée avec succès ==="
echo
echo "📋 Résumé du projet:"
echo "   Nom: $PROJECT_NAME"
echo "   ID: $PROJECT_ID"
echo "   URL: https://dev.azure.com/$(az devops configure -l | grep organization | cut -d'=' -f2 | sed 's|https://dev.azure.com/||')/$PROJECT_NAME"
echo
echo "📁 Dépôt Git:"
echo "   Nom: $REPO_NAME"
echo "   ID: $REPO_ID"
echo "   Clone URL: $(az repos show --repository "$REPO_NAME" --project "$PROJECT_NAME" --query "remoteUrl" --output tsv)"
echo
echo "🚀 Prochaines étapes:"
echo "   1. Cloner le dépôt localement"
echo "   2. Ajouter votre code source"
echo "   3. Créer et configurer les pipelines CI/CD"
echo "   4. Configurer les environnements de déploiement"
echo
echo "💡 Commandes utiles:"
echo "   - Lister les projets: az devops project list"
echo "   - Voir les dépôts: az repos list --project '$PROJECT_NAME'"
echo "   - Gérer les pipelines: az pipelines list --project '$PROJECT_NAME'"
```

## Étape 5 : Tests et validation (5 minutes)

### 5.1 Test du script complet
Exécutez le script de configuration complète :

```bash
./setup-complete-project.sh "Projet-Demo-Complet" "Projet de démonstration complet" "demo-repo" "demo-pipeline"
```

### 5.2 Vérification des résultats
Vérifiez que tout a été créé correctement :

```bash
# Lister les projets
az devops project list --output table

# Vérifier les dépôts du projet
az repos list --project "Projet-Demo-Complet" --output table

# Vérifier les pipelines (si créés)
az pipelines list --project "Projet-Demo-Complet" --output table
```

## Questions de réflexion

1. **Gestion des erreurs** : Comment pourriez-vous améliorer la gestion des erreurs dans les scripts ?

2. **Paramétrage** : Quels autres paramètres pourriez-vous ajouter pour rendre les scripts plus flexibles ?

3. **Sécurité** : Comment s'assurer que les scripts respectent les bonnes pratiques de sécurité ?

4. **Réutilisabilité** : Comment structurer les scripts pour maximiser leur réutilisabilité ?

## Défis supplémentaires

### Défi 1 : Script de nettoyage
Créez un script qui supprime automatiquement les projets de test créés pendant l'exercice.

### Défi 2 : Configuration avancée
Étendez le script pour inclure :
- Configuration des équipes et des permissions
- Création de tableaux de bord personnalisés
- Configuration des notifications

### Défi 3 : Intégration avec Git
Modifiez le script pour :
- Initialiser automatiquement le dépôt avec un README
- Créer une structure de dossiers standard
- Configurer les hooks Git

## Solutions et bonnes pratiques

### Gestion des erreurs robuste
```bash
# Fonction de vérification de prérequis
check_prerequisites() {
    local errors=0
    
    # Vérifier Azure CLI
    if ! command -v az &> /dev/null; then
        echo "❌ Azure CLI n'est pas installé"
        errors=$((errors + 1))
    fi
    
    # Vérifier l'extension Azure DevOps
    if ! az extension list --query "[?name=='azure-devops']" | grep -q "azure-devops"; then
        echo "❌ Extension Azure DevOps non installée"
        errors=$((errors + 1))
    fi
    
    # Vérifier la connexion
    if ! az devops project list &> /dev/null; then
        echo "❌ Impossible de se connecter à Azure DevOps"
        errors=$((errors + 1))
    fi
    
    if [ $errors -gt 0 ]; then
        echo "Veuillez corriger les erreurs ci-dessus avant de continuer."
        exit 1
    fi
    
    echo "✓ Tous les prérequis sont satisfaits"
}
```

### Configuration par fichier
```bash
# Utilisation d'un fichier de configuration
CONFIG_FILE="project-config.json"

# Exemple de fichier de configuration
cat > "$CONFIG_FILE" << 'EOF'
{
    "project": {
        "name": "MonProjet",
        "description": "Description du projet",
        "visibility": "private"
    },
    "repository": {
        "name": "mon-repo",
        "type": "Git"
    },
    "pipeline": {
        "name": "CI-Pipeline",
        "yamlPath": "azure-pipelines.yml"
    },
    "policies": {
        "minimumReviewers": 2,
        "requireWorkItems": true
    }
}
EOF

# Lecture de la configuration
PROJECT_NAME=$(jq -r '.project.name' "$CONFIG_FILE")
PROJECT_DESC=$(jq -r '.project.description' "$CONFIG_FILE")
```

## Ressources complémentaires

- [Documentation Azure CLI pour Azure DevOps](https://docs.microsoft.com/en-us/cli/azure/devops)
- [Référence des commandes az devops](https://docs.microsoft.com/en-us/cli/azure/devops/project)
- [Exemples de scripts Azure CLI](https://github.com/Azure/azure-cli/tree/dev/src/azure-cli/azure/cli/command_modules/devops)
- [Bonnes pratiques pour les scripts shell](https://google.github.io/styleguide/shellguide.html)

