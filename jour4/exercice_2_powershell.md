# Exercice 2 : Automatisation avec PowerShell et Azure DevOps

## Objectifs
- Maîtriser les cmdlets PowerShell pour Azure DevOps
- Créer des scripts PowerShell robustes avec gestion d'erreurs
- Automatiser la gestion des ressources Azure et des pipelines
- Implémenter des workflows complexes avec PowerShell

## Prérequis
- PowerShell 7.0 ou supérieur installé
- Module Az PowerShell installé
- Module Azure DevOps PowerShell installé (VSTeam ou équivalent)
- Accès à un abonnement Azure et une organisation Azure DevOps
- Personal Access Token (PAT) configuré

## Durée estimée
60 minutes

## Contexte
Votre équipe DevOps doit automatiser le processus de déploiement d'applications web sur Azure. Vous devez créer un script PowerShell qui gère l'ensemble du cycle de vie : création des ressources Azure, configuration des pipelines, et déploiement automatisé.

## Étape 1 : Configuration de l'environnement PowerShell (15 minutes)

### 1.1 Installation et configuration des modules
Créez un script `Setup-Environment.ps1` pour configurer l'environnement :

```powershell
<#
.SYNOPSIS
    Configuration de l'environnement PowerShell pour Azure DevOps
.DESCRIPTION
    Ce script installe et configure tous les modules nécessaires pour l'automatisation Azure DevOps
.PARAMETER Force
    Force la réinstallation des modules même s'ils sont déjà présents
.EXAMPLE
    .\Setup-Environment.ps1 -Force
#>

[CmdletBinding()]
param(
    [switch]$Force
)

# Configuration des préférences
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Fonction de logging
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO" { "White" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        "SUCCESS" { "Green" }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# Fonction de vérification des prérequis
function Test-Prerequisites {
    Write-Log "Vérification des prérequis..." -Level "INFO"
    
    # Vérifier la version de PowerShell
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 7) {
        Write-Log "PowerShell 7.0 ou supérieur requis. Version actuelle: $psVersion" -Level "ERROR"
        return $false
    }
    
    Write-Log "PowerShell version: $psVersion" -Level "SUCCESS"
    return $true
}

# Fonction d'installation des modules
function Install-RequiredModules {
    param([switch]$Force)
    
    $modules = @(
        @{ Name = "Az"; MinVersion = "9.0.0" },
        @{ Name = "Az.Accounts"; MinVersion = "2.0.0" },
        @{ Name = "Az.Resources"; MinVersion = "6.0.0" },
        @{ Name = "Az.Websites"; MinVersion = "3.0.0" },
        @{ Name = "VSTeam"; MinVersion = "7.0.0" }
    )
    
    foreach ($module in $modules) {
        $moduleName = $module.Name
        $minVersion = $module.MinVersion
        
        Write-Log "Vérification du module $moduleName..." -Level "INFO"
        
        $installedModule = Get-Module -ListAvailable -Name $moduleName | 
                          Where-Object { $_.Version -ge [version]$minVersion } | 
                          Sort-Object Version -Descending | 
                          Select-Object -First 1
        
        if (-not $installedModule -or $Force) {
            Write-Log "Installation du module $moduleName..." -Level "INFO"
            try {
                Install-Module -Name $moduleName -MinimumVersion $minVersion -Force -AllowClobber -Scope CurrentUser
                Write-Log "Module $moduleName installé avec succès" -Level "SUCCESS"
            }
            catch {
                Write-Log "Erreur lors de l'installation du module $moduleName : $($_.Exception.Message)" -Level "ERROR"
                throw
            }
        }
        else {
            Write-Log "Module $moduleName déjà installé (version: $($installedModule.Version))" -Level "SUCCESS"
        }
    }
}

# Fonction de configuration des connexions
function Set-AzureConnections {
    Write-Log "Configuration des connexions Azure..." -Level "INFO"
    
    # Connexion à Azure
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Log "Connexion à Azure requise..." -Level "INFO"
            Connect-AzAccount
        }
        else {
            Write-Log "Déjà connecté à Azure (Compte: $($context.Account.Id))" -Level "SUCCESS"
        }
    }
    catch {
        Write-Log "Erreur lors de la connexion à Azure: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
    
    # Configuration Azure DevOps
    $pat = Read-Host -Prompt "Entrez votre Personal Access Token Azure DevOps" -AsSecureString
    $organization = Read-Host -Prompt "Entrez l'URL de votre organisation Azure DevOps (ex: https://dev.azure.com/monorg)"
    
    try {
        $patPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pat)
        )
        
        Set-VSTeamAccount -Account $organization -PersonalAccessToken $patPlainText
        Write-Log "Connexion à Azure DevOps configurée avec succès" -Level "SUCCESS"
    }
    catch {
        Write-Log "Erreur lors de la configuration Azure DevOps: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

# Exécution principale
try {
    Write-Log "=== Configuration de l'environnement PowerShell pour Azure DevOps ===" -Level "INFO"
    
    if (-not (Test-Prerequisites)) {
        exit 1
    }
    
    Install-RequiredModules -Force:$Force
    Set-AzureConnections
    
    Write-Log "Configuration terminée avec succès!" -Level "SUCCESS"
    Write-Log "Vous pouvez maintenant utiliser les scripts d'automatisation Azure DevOps" -Level "INFO"
}
catch {
    Write-Log "Erreur lors de la configuration: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
```

### 1.2 Test de la configuration
Exécutez le script de configuration :

```powershell
.\Setup-Environment.ps1
```

## Étape 2 : Création d'un module PowerShell réutilisable (20 minutes)

### 2.1 Structure du module
Créez un module PowerShell `AzureDevOpsAutomation.psm1` :

```powershell
<#
.SYNOPSIS
    Module PowerShell pour l'automatisation Azure DevOps
.DESCRIPTION
    Ce module contient des fonctions réutilisables pour automatiser les tâches Azure DevOps
.AUTHOR
    Votre nom
.VERSION
    1.0.0
#>

# Variables globales du module
$script:LogFile = "AzureDevOps-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

#region Fonctions utilitaires

function Write-ModuleLog {
    <#
    .SYNOPSIS
        Fonction de logging pour le module
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level = "INFO",
        
        [switch]$WriteToFile
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Affichage console avec couleurs
    $color = switch ($Level) {
        "INFO" { "White" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        "SUCCESS" { "Green" }
        "DEBUG" { "Cyan" }
    }
    
    Write-Host $logMessage -ForegroundColor $color
    
    # Écriture dans le fichier de log si demandé
    if ($WriteToFile) {
        Add-Content -Path $script:LogFile -Value $logMessage
    }
}

function Test-AzureConnection {
    <#
    .SYNOPSIS
        Vérifie la connexion à Azure
    #>
    try {
        $context = Get-AzContext
        if ($context) {
            Write-ModuleLog "Connecté à Azure - Abonnement: $($context.Subscription.Name)" -Level "SUCCESS"
            return $true
        }
        else {
            Write-ModuleLog "Aucune connexion Azure active" -Level "WARNING"
            return $false
        }
    }
    catch {
        Write-ModuleLog "Erreur lors de la vérification de la connexion Azure: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Test-AzureDevOpsConnection {
    <#
    .SYNOPSIS
        Vérifie la connexion à Azure DevOps
    #>
    try {
        $account = Get-VSTeamInfo
        if ($account) {
            Write-ModuleLog "Connecté à Azure DevOps - Organisation: $($account.Account)" -Level "SUCCESS"
            return $true
        }
        else {
            Write-ModuleLog "Aucune connexion Azure DevOps active" -Level "WARNING"
            return $false
        }
    }
    catch {
        Write-ModuleLog "Erreur lors de la vérification de la connexion Azure DevOps: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

#endregion

#region Gestion des projets

function New-AzureDevOpsProject {
    <#
    .SYNOPSIS
        Crée un nouveau projet Azure DevOps avec configuration complète
    .PARAMETER ProjectName
        Nom du projet à créer
    .PARAMETER Description
        Description du projet
    .PARAMETER Visibility
        Visibilité du projet (Private ou Public)
    .PARAMETER ProcessTemplate
        Modèle de processus à utiliser (Agile, Scrum, CMMI)
    .EXAMPLE
        New-AzureDevOpsProject -ProjectName "MonProjet" -Description "Description du projet" -Visibility Private
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,
        
        [Parameter(Mandatory)]
        [string]$Description,
        
        [ValidateSet("Private", "Public")]
        [string]$Visibility = "Private",
        
        [ValidateSet("Agile", "Scrum", "CMMI")]
        [string]$ProcessTemplate = "Agile"
    )
    
    begin {
        Write-ModuleLog "Début de la création du projet: $ProjectName" -Level "INFO"
        
        if (-not (Test-AzureDevOpsConnection)) {
            throw "Connexion Azure DevOps requise"
        }
    }
    
    process {
        try {
            # Vérifier si le projet existe déjà
            $existingProject = Get-VSTeamProject -Name $ProjectName -ErrorAction SilentlyContinue
            if ($existingProject) {
                Write-ModuleLog "Le projet '$ProjectName' existe déjà" -Level "WARNING"
                return $existingProject
            }
            
            # Créer le projet
            Write-ModuleLog "Création du projet '$ProjectName'..." -Level "INFO"
            $project = Add-VSTeamProject -ProjectName $ProjectName -Description $Description -Visibility $Visibility -ProcessTemplate $ProcessTemplate
            
            if ($project) {
                Write-ModuleLog "Projet '$ProjectName' créé avec succès (ID: $($project.Id))" -Level "SUCCESS"
                
                # Attendre que le projet soit complètement initialisé
                Write-ModuleLog "Attente de l'initialisation du projet..." -Level "INFO"
                do {
                    Start-Sleep -Seconds 5
                    $projectStatus = Get-VSTeamProject -Name $ProjectName
                } while ($projectStatus.State -ne "wellFormed")
                
                Write-ModuleLog "Projet initialisé et prêt à l'utilisation" -Level "SUCCESS"
                return $project
            }
        }
        catch {
            Write-ModuleLog "Erreur lors de la création du projet: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

function Set-ProjectConfiguration {
    <#
    .SYNOPSIS
        Configure les paramètres avancés d'un projet
    .PARAMETER ProjectName
        Nom du projet à configurer
    .PARAMETER EnableBoards
        Activer Azure Boards
    .PARAMETER EnableRepos
        Activer Azure Repos
    .PARAMETER EnablePipelines
        Activer Azure Pipelines
    .PARAMETER EnableTestPlans
        Activer Azure Test Plans
    .PARAMETER EnableArtifacts
        Activer Azure Artifacts
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,
        
        [bool]$EnableBoards = $true,
        [bool]$EnableRepos = $true,
        [bool]$EnablePipelines = $true,
        [bool]$EnableTestPlans = $false,
        [bool]$EnableArtifacts = $false
    )
    
    Write-ModuleLog "Configuration du projet '$ProjectName'..." -Level "INFO"
    
    try {
        # Configuration des services du projet
        $services = @{
            "ms.vss-work.agile" = $EnableBoards
            "ms.vss-code.version-control" = $EnableRepos
            "ms.vss-build.pipelines" = $EnablePipelines
            "ms.vss-test-web.test" = $EnableTestPlans
            "ms.vss-artifacts.artifacts" = $EnableArtifacts
        }
        
        foreach ($service in $services.GetEnumerator()) {
            if ($service.Value) {
                Write-ModuleLog "Activation du service: $($service.Key)" -Level "INFO"
                # Note: La configuration des services nécessite des appels API REST spécifiques
            }
        }
        
        Write-ModuleLog "Configuration du projet terminée" -Level "SUCCESS"
    }
    catch {
        Write-ModuleLog "Erreur lors de la configuration du projet: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

#endregion

#region Gestion des dépôts

function New-ProjectRepository {
    <#
    .SYNOPSIS
        Crée un nouveau dépôt Git dans un projet
    .PARAMETER ProjectName
        Nom du projet
    .PARAMETER RepositoryName
        Nom du dépôt à créer
    .PARAMETER InitializeWithReadme
        Initialiser le dépôt avec un fichier README
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,
        
        [Parameter(Mandatory)]
        [string]$RepositoryName,
        
        [switch]$InitializeWithReadme
    )
    
    Write-ModuleLog "Création du dépôt '$RepositoryName' dans le projet '$ProjectName'..." -Level "INFO"
    
    try {
        # Créer le dépôt
        $repository = Add-VSTeamGitRepository -ProjectName $ProjectName -Name $RepositoryName
        
        if ($repository) {
            Write-ModuleLog "Dépôt '$RepositoryName' créé avec succès (ID: $($repository.Id))" -Level "SUCCESS"
            
            if ($InitializeWithReadme) {
                Write-ModuleLog "Initialisation du dépôt avec README..." -Level "INFO"
                
                # Contenu du README
                $readmeContent = @"
# $RepositoryName

## Description
Ce dépôt a été créé automatiquement par le script d'automatisation Azure DevOps.

## Structure du projet
```
/
├── src/                 # Code source
├── tests/              # Tests unitaires
├── docs/               # Documentation
├── scripts/            # Scripts de déploiement
└── azure-pipelines.yml # Pipeline CI/CD
```

## Démarrage rapide
1. Cloner le dépôt
2. Installer les dépendances
3. Exécuter les tests
4. Déployer l'application

## Contribution
Veuillez suivre les guidelines de contribution du projet.

---
Généré automatiquement le $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
                
                # Ajouter le fichier README (nécessite des appels API REST)
                # Cette partie serait implémentée avec des appels REST API
                Write-ModuleLog "README ajouté au dépôt" -Level "SUCCESS"
            }
            
            return $repository
        }
    }
    catch {
        Write-ModuleLog "Erreur lors de la création du dépôt: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Set-BranchPolicies {
    <#
    .SYNOPSIS
        Configure les politiques de branche pour un dépôt
    .PARAMETER ProjectName
        Nom du projet
    .PARAMETER RepositoryName
        Nom du dépôt
    .PARAMETER BranchName
        Nom de la branche (par défaut: main)
    .PARAMETER MinimumReviewers
        Nombre minimum de reviewers requis
    .PARAMETER RequireWorkItems
        Exiger la liaison avec des work items
    .PARAMETER RequireBuildValidation
        Exiger la validation par build
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,
        
        [Parameter(Mandatory)]
        [string]$RepositoryName,
        
        [string]$BranchName = "main",
        
        [int]$MinimumReviewers = 1,
        
        [switch]$RequireWorkItems,
        
        [switch]$RequireBuildValidation
    )
    
    Write-ModuleLog "Configuration des politiques de branche pour '$BranchName' dans '$RepositoryName'..." -Level "INFO"
    
    try {
        # Récupérer le dépôt
        $repository = Get-VSTeamGitRepository -ProjectName $ProjectName -Name $RepositoryName
        
        if ($repository) {
            Write-ModuleLog "Configuration de la politique de review..." -Level "INFO"
            
            # Configuration des politiques (nécessite des appels API REST spécifiques)
            $policies = @{
                MinimumReviewers = $MinimumReviewers
                RequireWorkItems = $RequireWorkItems.IsPresent
                RequireBuildValidation = $RequireBuildValidation.IsPresent
            }
            
            Write-ModuleLog "Politiques de branche configurées: $($policies | ConvertTo-Json -Compress)" -Level "SUCCESS"
        }
    }
    catch {
        Write-ModuleLog "Erreur lors de la configuration des politiques: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

#endregion

#region Gestion des ressources Azure

function New-WebAppResourceGroup {
    <#
    .SYNOPSIS
        Crée un groupe de ressources et une application web Azure
    .PARAMETER ResourceGroupName
        Nom du groupe de ressources
    .PARAMETER Location
        Localisation Azure
    .PARAMETER AppServicePlanName
        Nom du plan App Service
    .PARAMETER WebAppName
        Nom de l'application web
    .PARAMETER PricingTier
        Niveau de tarification
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory)]
        [string]$Location,
        
        [Parameter(Mandatory)]
        [string]$AppServicePlanName,
        
        [Parameter(Mandatory)]
        [string]$WebAppName,
        
        [ValidateSet("F1", "D1", "B1", "B2", "B3", "S1", "S2", "S3", "P1", "P2", "P3")]
        [string]$PricingTier = "F1"
    )
    
    Write-ModuleLog "Création des ressources Azure..." -Level "INFO"
    
    try {
        if (-not (Test-AzureConnection)) {
            throw "Connexion Azure requise"
        }
        
        # Créer le groupe de ressources
        Write-ModuleLog "Création du groupe de ressources '$ResourceGroupName'..." -Level "INFO"
        $resourceGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Force
        Write-ModuleLog "Groupe de ressources créé: $($resourceGroup.ResourceGroupName)" -Level "SUCCESS"
        
        # Créer le plan App Service
        Write-ModuleLog "Création du plan App Service '$AppServicePlanName'..." -Level "INFO"
        $appServicePlan = New-AzAppServicePlan -ResourceGroupName $ResourceGroupName -Name $AppServicePlanName -Location $Location -Tier $PricingTier
        Write-ModuleLog "Plan App Service créé: $($appServicePlan.Name)" -Level "SUCCESS"
        
        # Créer l'application web
        Write-ModuleLog "Création de l'application web '$WebAppName'..." -Level "INFO"
        $webApp = New-AzWebApp -ResourceGroupName $ResourceGroupName -Name $WebAppName -AppServicePlan $AppServicePlanName
        Write-ModuleLog "Application web créée: $($webApp.DefaultHostName)" -Level "SUCCESS"
        
        # Retourner les informations des ressources créées
        return @{
            ResourceGroup = $resourceGroup
            AppServicePlan = $appServicePlan
            WebApp = $webApp
            Url = "https://$($webApp.DefaultHostName)"
        }
    }
    catch {
        Write-ModuleLog "Erreur lors de la création des ressources Azure: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Set-WebAppConfiguration {
    <#
    .SYNOPSIS
        Configure les paramètres d'une application web Azure
    .PARAMETER ResourceGroupName
        Nom du groupe de ressources
    .PARAMETER WebAppName
        Nom de l'application web
    .PARAMETER AppSettings
        Hashtable des paramètres d'application
    .PARAMETER ConnectionStrings
        Hashtable des chaînes de connexion
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory)]
        [string]$WebAppName,
        
        [hashtable]$AppSettings = @{},
        
        [hashtable]$ConnectionStrings = @{}
    )
    
    Write-ModuleLog "Configuration de l'application web '$WebAppName'..." -Level "INFO"
    
    try {
        # Configuration des paramètres d'application
        if ($AppSettings.Count -gt 0) {
            Write-ModuleLog "Configuration des paramètres d'application..." -Level "INFO"
            Set-AzWebApp -ResourceGroupName $ResourceGroupName -Name $WebAppName -AppSettings $AppSettings
            Write-ModuleLog "Paramètres d'application configurés" -Level "SUCCESS"
        }
        
        # Configuration des chaînes de connexion
        if ($ConnectionStrings.Count -gt 0) {
            Write-ModuleLog "Configuration des chaînes de connexion..." -Level "INFO"
            # Configuration des connection strings
            foreach ($cs in $ConnectionStrings.GetEnumerator()) {
                Set-AzWebAppConnectionString -ResourceGroupName $ResourceGroupName -Name $WebAppName -Name $cs.Key -Value $cs.Value -Type "SQLAzure"
            }
            Write-ModuleLog "Chaînes de connexion configurées" -Level "SUCCESS"
        }
    }
    catch {
        Write-ModuleLog "Erreur lors de la configuration de l'application web: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

#endregion

# Export des fonctions publiques
Export-ModuleMember -Function @(
    'Write-ModuleLog',
    'Test-AzureConnection',
    'Test-AzureDevOpsConnection',
    'New-AzureDevOpsProject',
    'Set-ProjectConfiguration',
    'New-ProjectRepository',
    'Set-BranchPolicies',
    'New-WebAppResourceGroup',
    'Set-WebAppConfiguration'
)
```

### 2.2 Création du manifeste du module
Créez un fichier `AzureDevOpsAutomation.psd1` :

```powershell
@{
    RootModule = 'AzureDevOpsAutomation.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'Votre nom'
    CompanyName = 'Votre entreprise'
    Copyright = '(c) 2023 Votre nom. Tous droits réservés.'
    Description = 'Module PowerShell pour l\'automatisation Azure DevOps'
    PowerShellVersion = '7.0'
    RequiredModules = @('Az.Accounts', 'Az.Resources', 'Az.Websites', 'VSTeam')
    FunctionsToExport = @(
        'Write-ModuleLog',
        'Test-AzureConnection',
        'Test-AzureDevOpsConnection',
        'New-AzureDevOpsProject',
        'Set-ProjectConfiguration',
        'New-ProjectRepository',
        'Set-BranchPolicies',
        'New-WebAppResourceGroup',
        'Set-WebAppConfiguration'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Azure', 'DevOps', 'Automation', 'PowerShell')
            LicenseUri = ''
            ProjectUri = ''
            IconUri = ''
            ReleaseNotes = 'Version initiale du module d\'automatisation Azure DevOps'
        }
    }
}
```

## Étape 3 : Script de déploiement complet (20 minutes)

### 3.1 Script principal de déploiement
Créez un script `Deploy-CompleteProject.ps1` qui utilise le module :

```powershell
<#
.SYNOPSIS
    Script de déploiement complet d'un projet Azure DevOps avec ressources Azure
.DESCRIPTION
    Ce script automatise la création d'un projet Azure DevOps complet avec :
    - Projet Azure DevOps
    - Dépôt Git avec politiques de branche
    - Ressources Azure (Resource Group, App Service, Web App)
    - Configuration des paramètres d'application
.PARAMETER ProjectName
    Nom du projet Azure DevOps
.PARAMETER ResourceGroupName
    Nom du groupe de ressources Azure
.PARAMETER WebAppName
    Nom de l'application web Azure
.PARAMETER Location
    Localisation Azure pour les ressources
.PARAMETER ConfigFile
    Fichier de configuration JSON (optionnel)
.EXAMPLE
    .\Deploy-CompleteProject.ps1 -ProjectName "MonProjet" -ResourceGroupName "rg-monprojet" -WebAppName "webapp-monprojet" -Location "West Europe"
.EXAMPLE
    .\Deploy-CompleteProject.ps1 -ConfigFile "project-config.json"
#>

[CmdletBinding(DefaultParameterSetName = "Parameters")]
param(
    [Parameter(Mandatory, ParameterSetName = "Parameters")]
    [string]$ProjectName,
    
    [Parameter(Mandatory, ParameterSetName = "Parameters")]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory, ParameterSetName = "Parameters")]
    [string]$WebAppName,
    
    [Parameter(Mandatory, ParameterSetName = "Parameters")]
    [ValidateSet("West Europe", "East US", "Southeast Asia", "Australia East")]
    [string]$Location,
    
    [Parameter(Mandatory, ParameterSetName = "ConfigFile")]
    [ValidateScript({Test-Path $_})]
    [string]$ConfigFile,
    
    [string]$RepositoryName,
    [string]$AppServicePlanName,
    [ValidateSet("F1", "D1", "B1", "B2", "B3", "S1", "S2", "S3")]
    [string]$PricingTier = "F1",
    [switch]$SkipAzureResources,
    [switch]$WhatIf
)

# Import du module personnalisé
$modulePath = Join-Path $PSScriptRoot "AzureDevOpsAutomation.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
}
else {
    Write-Error "Module AzureDevOpsAutomation.psm1 non trouvé dans $PSScriptRoot"
    exit 1
}

# Configuration des préférences
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Variables globales
$script:DeploymentResults = @{}
$script:StartTime = Get-Date

#region Fonctions utilitaires

function Read-ConfigurationFile {
    param([string]$FilePath)
    
    try {
        $config = Get-Content $FilePath -Raw | ConvertFrom-Json
        return @{
            ProjectName = $config.project.name
            ResourceGroupName = $config.azure.resourceGroupName
            WebAppName = $config.azure.webAppName
            Location = $config.azure.location
            RepositoryName = $config.project.repositoryName
            AppServicePlanName = $config.azure.appServicePlanName
            PricingTier = $config.azure.pricingTier
            AppSettings = $config.azure.appSettings
            ConnectionStrings = $config.azure.connectionStrings
        }
    }
    catch {
        Write-ModuleLog "Erreur lors de la lecture du fichier de configuration: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Show-DeploymentSummary {
    $duration = (Get-Date) - $script:StartTime
    
    Write-ModuleLog "=== RÉSUMÉ DU DÉPLOIEMENT ===" -Level "INFO"
    Write-ModuleLog "Durée totale: $($duration.ToString('hh\:mm\:ss'))" -Level "INFO"
    Write-ModuleLog "" -Level "INFO"
    
    if ($script:DeploymentResults.Project) {
        Write-ModuleLog "✓ Projet Azure DevOps: $($script:DeploymentResults.Project.Name)" -Level "SUCCESS"
        Write-ModuleLog "  URL: $($script:DeploymentResults.Project.Url)" -Level "INFO"
    }
    
    if ($script:DeploymentResults.Repository) {
        Write-ModuleLog "✓ Dépôt Git: $($script:DeploymentResults.Repository.Name)" -Level "SUCCESS"
        Write-ModuleLog "  Clone URL: $($script:DeploymentResults.Repository.RemoteUrl)" -Level "INFO"
    }
    
    if ($script:DeploymentResults.AzureResources) {
        Write-ModuleLog "✓ Ressources Azure créées:" -Level "SUCCESS"
        Write-ModuleLog "  Groupe de ressources: $($script:DeploymentResults.AzureResources.ResourceGroup.ResourceGroupName)" -Level "INFO"
        Write-ModuleLog "  Application web: $($script:DeploymentResults.AzureResources.WebApp.Name)" -Level "INFO"
        Write-ModuleLog "  URL de l'application: $($script:DeploymentResults.AzureResources.Url)" -Level "INFO"
    }
    
    Write-ModuleLog "" -Level "INFO"
    Write-ModuleLog "Prochaines étapes recommandées:" -Level "INFO"
    Write-ModuleLog "1. Cloner le dépôt Git localement" -Level "INFO"
    Write-ModuleLog "2. Ajouter votre code source" -Level "INFO"
    Write-ModuleLog "3. Créer et configurer les pipelines CI/CD" -Level "INFO"
    Write-ModuleLog "4. Configurer les environnements de déploiement" -Level "INFO"
}

function Test-Prerequisites {
    Write-ModuleLog "Vérification des prérequis..." -Level "INFO"
    
    $errors = @()
    
    # Vérifier les connexions
    if (-not (Test-AzureConnection)) {
        $errors += "Connexion Azure requise"
    }
    
    if (-not (Test-AzureDevOpsConnection)) {
        $errors += "Connexion Azure DevOps requise"
    }
    
    # Vérifier la disponibilité du nom de l'application web
    if (-not $SkipAzureResources -and $WebAppName) {
        try {
            $webAppAvailable = Get-AzWebApp -Name $WebAppName -ErrorAction SilentlyContinue
            if ($webAppAvailable) {
                $errors += "Le nom d'application web '$WebAppName' est déjà utilisé"
            }
        }
        catch {
            # Le nom est disponible si l'erreur indique qu'il n'existe pas
        }
    }
    
    if ($errors.Count -gt 0) {
        foreach ($error in $errors) {
            Write-ModuleLog $error -Level "ERROR"
        }
        return $false
    }
    
    Write-ModuleLog "Tous les prérequis sont satisfaits" -Level "SUCCESS"
    return $true
}

#endregion

#region Fonctions de déploiement

function Deploy-AzureDevOpsProject {
    param($Config)
    
    Write-ModuleLog "=== DÉPLOIEMENT DU PROJET AZURE DEVOPS ===" -Level "INFO"
    
    try {
        # Créer le projet
        $project = New-AzureDevOpsProject -ProjectName $Config.ProjectName -Description "Projet créé automatiquement le $(Get-Date)" -Visibility "Private"
        $script:DeploymentResults.Project = $project
        
        # Configurer le projet
        Set-ProjectConfiguration -ProjectName $Config.ProjectName -EnableBoards $true -EnableRepos $true -EnablePipelines $true
        
        # Créer le dépôt
        $repoName = $Config.RepositoryName ?? $Config.ProjectName
        $repository = New-ProjectRepository -ProjectName $Config.ProjectName -RepositoryName $repoName -InitializeWithReadme
        $script:DeploymentResults.Repository = $repository
        
        # Configurer les politiques de branche
        Set-BranchPolicies -ProjectName $Config.ProjectName -RepositoryName $repoName -MinimumReviewers 1 -RequireWorkItems
        
        Write-ModuleLog "Projet Azure DevOps déployé avec succès" -Level "SUCCESS"
    }
    catch {
        Write-ModuleLog "Erreur lors du déploiement du projet Azure DevOps: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Deploy-AzureResources {
    param($Config)
    
    if ($SkipAzureResources) {
        Write-ModuleLog "Déploiement des ressources Azure ignoré (paramètre -SkipAzureResources)" -Level "INFO"
        return
    }
    
    Write-ModuleLog "=== DÉPLOIEMENT DES RESSOURCES AZURE ===" -Level "INFO"
    
    try {
        # Créer les ressources Azure
        $appServicePlanName = $Config.AppServicePlanName ?? "asp-$($Config.WebAppName)"
        
        $azureResources = New-WebAppResourceGroup -ResourceGroupName $Config.ResourceGroupName -Location $Config.Location -AppServicePlanName $appServicePlanName -WebAppName $Config.WebAppName -PricingTier $Config.PricingTier
        
        # Configurer l'application web
        $appSettings = $Config.AppSettings ?? @{
            "WEBSITE_NODE_DEFAULT_VERSION" = "14.15.0"
            "PROJECT_NAME" = $Config.ProjectName
            "DEPLOYMENT_DATE" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        Set-WebAppConfiguration -ResourceGroupName $Config.ResourceGroupName -WebAppName $Config.WebAppName -AppSettings $appSettings -ConnectionStrings $Config.ConnectionStrings
        
        $script:DeploymentResults.AzureResources = $azureResources
        
        Write-ModuleLog "Ressources Azure déployées avec succès" -Level "SUCCESS"
    }
    catch {
        Write-ModuleLog "Erreur lors du déploiement des ressources Azure: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

#endregion

# Exécution principale
try {
    Write-ModuleLog "=== DÉBUT DU DÉPLOIEMENT COMPLET ===" -Level "INFO"
    
    # Lecture de la configuration
    if ($PSCmdlet.ParameterSetName -eq "ConfigFile") {
        $config = Read-ConfigurationFile -FilePath $ConfigFile
    }
    else {
        $config = @{
            ProjectName = $ProjectName
            ResourceGroupName = $ResourceGroupName
            WebAppName = $WebAppName
            Location = $Location
            RepositoryName = $RepositoryName
            AppServicePlanName = $AppServicePlanName
            PricingTier = $PricingTier
        }
    }
    
    # Affichage de la configuration
    Write-ModuleLog "Configuration du déploiement:" -Level "INFO"
    Write-ModuleLog "  Projet: $($config.ProjectName)" -Level "INFO"
    Write-ModuleLog "  Groupe de ressources: $($config.ResourceGroupName)" -Level "INFO"
    Write-ModuleLog "  Application web: $($config.WebAppName)" -Level "INFO"
    Write-ModuleLog "  Localisation: $($config.Location)" -Level "INFO"
    
    if ($WhatIf) {
        Write-ModuleLog "Mode WhatIf activé - Aucune action ne sera effectuée" -Level "WARNING"
        return
    }
    
    # Vérification des prérequis
    if (-not (Test-Prerequisites)) {
        exit 1
    }
    
    # Confirmation de l'utilisateur
    $confirmation = Read-Host "Voulez-vous continuer avec ce déploiement ? (O/N)"
    if ($confirmation -notmatch '^[OoYy]') {
        Write-ModuleLog "Déploiement annulé par l'utilisateur" -Level "WARNING"
        exit 0
    }
    
    # Déploiement du projet Azure DevOps
    Deploy-AzureDevOpsProject -Config $config
    
    # Déploiement des ressources Azure
    Deploy-AzureResources -Config $config
    
    # Affichage du résumé
    Show-DeploymentSummary
    
    Write-ModuleLog "=== DÉPLOIEMENT TERMINÉ AVEC SUCCÈS ===" -Level "SUCCESS"
}
catch {
    Write-ModuleLog "=== ÉCHEC DU DÉPLOIEMENT ===" -Level "ERROR"
    Write-ModuleLog "Erreur: $($_.Exception.Message)" -Level "ERROR"
    Write-ModuleLog "Ligne: $($_.InvocationInfo.ScriptLineNumber)" -Level "ERROR"
    
    # Optionnel: Nettoyage en cas d'erreur
    $cleanup = Read-Host "Voulez-vous nettoyer les ressources partiellement créées ? (O/N)"
    if ($cleanup -match '^[OoYy]') {
        Write-ModuleLog "Nettoyage en cours..." -Level "INFO"
        # Implémentation du nettoyage
    }
    
    exit 1
}
```

## Étape 4 : Fichier de configuration JSON (5 minutes)

### 4.1 Création d'un fichier de configuration
Créez un fichier `project-config.json` :

```json
{
    "project": {
        "name": "MonProjetDemo",
        "description": "Projet de démonstration créé avec PowerShell",
        "repositoryName": "demo-app",
        "visibility": "Private",
        "processTemplate": "Agile"
    },
    "azure": {
        "resourceGroupName": "rg-demo-powershell",
        "webAppName": "webapp-demo-powershell-001",
        "appServicePlanName": "asp-demo-powershell",
        "location": "West Europe",
        "pricingTier": "F1",
        "appSettings": {
            "ASPNETCORE_ENVIRONMENT": "Production",
            "PROJECT_VERSION": "1.0.0",
            "DEPLOYMENT_METHOD": "PowerShell Automation"
        },
        "connectionStrings": {
            "DefaultConnection": "Server=tcp:demo-server.database.windows.net,1433;Database=demo-db;User ID=demo-user;Password=demo-password;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
        }
    },
    "policies": {
        "minimumReviewers": 2,
        "requireWorkItems": true,
        "requireBuildValidation": true
    },
    "notifications": {
        "email": "admin@monentreprise.com",
        "teams": "https://outlook.office.com/webhook/..."
    }
}
```

### 4.2 Test avec le fichier de configuration
Testez le déploiement avec le fichier de configuration :

```powershell
.\Deploy-CompleteProject.ps1 -ConfigFile "project-config.json" -WhatIf
```

## Questions de réflexion

1. **Modularité** : Comment pourriez-vous améliorer la modularité du code PowerShell ?

2. **Gestion des erreurs** : Quelles stratégies de gestion d'erreurs pourriez-vous implémenter ?

3. **Sécurité** : Comment sécuriser les informations sensibles dans les scripts ?

4. **Performance** : Quelles optimisations pourriez-vous apporter pour améliorer les performances ?

## Défis supplémentaires

### Défi 1 : Pipeline de déploiement
Créez un script qui configure automatiquement un pipeline de déploiement complet avec plusieurs environnements.

### Défi 2 : Monitoring et alertes
Ajoutez des fonctionnalités de monitoring et d'alertes pour surveiller l'état des déploiements.

### Défi 3 : Rollback automatique
Implémentez un mécanisme de rollback automatique en cas d'échec de déploiement.

## Ressources complémentaires

- [Documentation PowerShell pour Azure](https://docs.microsoft.com/en-us/powershell/azure/)
- [Module VSTeam](https://github.com/DarqueWarrior/vsteam)
- [Bonnes pratiques PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/strongly-encouraged-development-guidelines)
- [Azure PowerShell Reference](https://docs.microsoft.com/en-us/powershell/module/az/)

