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