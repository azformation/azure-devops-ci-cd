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