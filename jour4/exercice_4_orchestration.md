# Exercice 4 : Orchestration complète et intégration des outils d'automatisation

## Objectifs
- Intégrer Azure CLI, PowerShell et l'API REST dans un workflow unifié
- Créer un système d'orchestration robuste avec gestion d'erreurs avancée
- Implémenter un pipeline de déploiement end-to-end automatisé
- Développer des mécanismes de monitoring et de notification

## Prérequis
- Tous les outils des exercices précédents configurés
- Azure CLI avec extension Azure DevOps
- PowerShell 7.0+ avec modules Az et VSTeam
- Accès à Azure DevOps et Azure
- Connaissance des exercices 1, 2 et 3

## Durée estimée
90 minutes

## Contexte
Votre organisation souhaite mettre en place un système d'automatisation complet qui :
- Crée automatiquement l'infrastructure Azure
- Configure les projets Azure DevOps
- Déploie les applications
- Surveille les performances
- Envoie des notifications en cas de problème

Vous devez créer un orchestrateur qui combine tous les outils d'automatisation pour réaliser ce workflow complexe.

## Étape 1 : Architecture de l'orchestrateur (20 minutes)

### 1.1 Création du module d'orchestration principal
Créez un fichier `DevOpsOrchestrator.psm1` :

```powershell
<#
.SYNOPSIS
    Module d'orchestration pour l'automatisation Azure DevOps complète
.DESCRIPTION
    Ce module orchestre l'utilisation d'Azure CLI, PowerShell et l'API REST pour automatiser
    l'ensemble du cycle de vie des projets Azure DevOps
.AUTHOR
    Votre nom
.VERSION
    1.0.0
#>

# Import des modules requis
Import-Module Az.Accounts -Force
Import-Module Az.Resources -Force
Import-Module Az.Websites -Force

# Variables globales
$script:LogFile = "orchestrator-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$script:ConfigFile = ""
$script:ExecutionContext = @{}

#region Configuration et initialisation

class OrchestrationConfig {
    [string]$ProjectName
    [string]$OrganizationUrl
    [string]$AzureSubscriptionId
    [string]$ResourceGroupName
    [string]$Location
    [string]$WebAppName
    [string]$AppServicePlanName
    [hashtable]$NotificationSettings
    [hashtable]$AzureDevOpsSettings
    [hashtable]$DeploymentSettings
    [array]$Environments
    
    OrchestrationConfig() {
        $this.NotificationSettings = @{}
        $this.AzureDevOpsSettings = @{}
        $this.DeploymentSettings = @{}
        $this.Environments = @()
    }
}

function Initialize-Orchestrator {
    <#
    .SYNOPSIS
        Initialise l'orchestrateur avec la configuration
    .PARAMETER ConfigPath
        Chemin vers le fichier de configuration JSON
    .PARAMETER ValidateOnly
        Valide uniquement la configuration sans initialiser
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_})]
        [string]$ConfigPath,
        
        [switch]$ValidateOnly
    )
    
    try {
        Write-OrchestratorLog "Initialisation de l'orchestrateur..." -Level "INFO"
        
        # Lecture de la configuration
        $configContent = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        $script:ConfigFile = $ConfigPath
        
        # Création de l'objet de configuration
        $config = [OrchestrationConfig]::new()
        $config.ProjectName = $configContent.project.name
        $config.OrganizationUrl = $configContent.azureDevOps.organizationUrl
        $config.AzureSubscriptionId = $configContent.azure.subscriptionId
        $config.ResourceGroupName = $configContent.azure.resourceGroupName
        $config.Location = $configContent.azure.location
        $config.WebAppName = $configContent.azure.webAppName
        $config.AppServicePlanName = $configContent.azure.appServicePlanName
        $config.NotificationSettings = $configContent.notifications
        $config.AzureDevOpsSettings = $configContent.azureDevOps
        $config.DeploymentSettings = $configContent.deployment
        $config.Environments = $configContent.environments
        
        # Validation de la configuration
        $validationResult = Test-OrchestrationConfig -Config $config
        if (-not $validationResult.IsValid) {
            throw "Configuration invalide: $($validationResult.Errors -join ', ')"
        }
        
        if ($ValidateOnly) {
            Write-OrchestratorLog "Configuration validée avec succès" -Level "SUCCESS"
            return $config
        }
        
        # Initialisation des connexions
        Initialize-Connections -Config $config
        
        # Stockage du contexte d'exécution
        $script:ExecutionContext = @{
            Config = $config
            StartTime = Get-Date
            ExecutionId = [Guid]::NewGuid().ToString()
            Steps = @()
        }
        
        Write-OrchestratorLog "Orchestrateur initialisé avec succès (ID: $($script:ExecutionContext.ExecutionId))" -Level "SUCCESS"
        return $config
    }
    catch {
        Write-OrchestratorLog "Erreur lors de l'initialisation: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Test-OrchestrationConfig {
    <#
    .SYNOPSIS
        Valide la configuration de l'orchestrateur
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [OrchestrationConfig]$Config
    )
    
    $errors = @()
    
    # Validation des champs obligatoires
    if (-not $Config.ProjectName) { $errors += "ProjectName manquant" }
    if (-not $Config.OrganizationUrl) { $errors += "OrganizationUrl manquant" }
    if (-not $Config.AzureSubscriptionId) { $errors += "AzureSubscriptionId manquant" }
    if (-not $Config.ResourceGroupName) { $errors += "ResourceGroupName manquant" }
    if (-not $Config.Location) { $errors += "Location manquant" }
    if (-not $Config.WebAppName) { $errors += "WebAppName manquant" }
    
    # Validation des formats
    if ($Config.OrganizationUrl -and $Config.OrganizationUrl -notmatch '^https://dev\.azure\.com/') {
        $errors += "Format OrganizationUrl invalide"
    }
    
    if ($Config.AzureSubscriptionId -and $Config.AzureSubscriptionId -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
        $errors += "Format AzureSubscriptionId invalide"
    }
    
    # Validation des environnements
    if ($Config.Environments.Count -eq 0) {
        $errors += "Au moins un environnement doit être défini"
    }
    
    return @{
        IsValid = ($errors.Count -eq 0)
        Errors = $errors
    }
}

function Initialize-Connections {
    <#
    .SYNOPSIS
        Initialise toutes les connexions nécessaires
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [OrchestrationConfig]$Config
    )
    
    Write-OrchestratorLog "Initialisation des connexions..." -Level "INFO"
    
    # Connexion Azure
    try {
        $azContext = Get-AzContext
        if (-not $azContext -or $azContext.Subscription.Id -ne $Config.AzureSubscriptionId) {
            Write-OrchestratorLog "Connexion à Azure (Subscription: $($Config.AzureSubscriptionId))..." -Level "INFO"
            Set-AzContext -SubscriptionId $Config.AzureSubscriptionId
        }
        Write-OrchestratorLog "✓ Connexion Azure établie" -Level "SUCCESS"
    }
    catch {
        throw "Erreur de connexion Azure: $($_.Exception.Message)"
    }
    
    # Configuration Azure CLI
    try {
        Write-OrchestratorLog "Configuration Azure CLI..." -Level "INFO"
        $null = az account set --subscription $Config.AzureSubscriptionId
        $null = az devops configure --defaults organization=$Config.OrganizationUrl
        Write-OrchestratorLog "✓ Azure CLI configuré" -Level "SUCCESS"
    }
    catch {
        throw "Erreur de configuration Azure CLI: $($_.Exception.Message)"
    }
    
    # Test des connexions
    $connectionTests = @(
        @{ Name = "Azure PowerShell"; Test = { Get-AzContext } },
        @{ Name = "Azure CLI"; Test = { az account show } },
        @{ Name = "Azure DevOps CLI"; Test = { az devops project list } }
    )
    
    foreach ($test in $connectionTests) {
        try {
            $null = & $test.Test
            Write-OrchestratorLog "✓ $($test.Name) opérationnel" -Level "SUCCESS"
        }
        catch {
            Write-OrchestratorLog "✗ $($test.Name) non opérationnel: $($_.Exception.Message)" -Level "ERROR"
        }
    }
}

#endregion

#region Logging et monitoring

function Write-OrchestratorLog {
    <#
    .SYNOPSIS
        Fonction de logging pour l'orchestrateur
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level = "INFO",
        
        [string]$Component = "ORCHESTRATOR",
        
        [switch]$WriteToFile
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $executionId = $script:ExecutionContext.ExecutionId ?? "INIT"
    $logMessage = "[$timestamp] [$executionId] [$Component] [$Level] $Message"
    
    # Affichage console avec couleurs
    $color = switch ($Level) {
        "INFO" { "White" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        "SUCCESS" { "Green" }
        "DEBUG" { "Cyan" }
    }
    
    Write-Host $logMessage -ForegroundColor $color
    
    # Écriture dans le fichier de log
    if ($WriteToFile -or $Level -in @("ERROR", "WARNING")) {
        Add-Content -Path $script:LogFile -Value $logMessage
    }
}

function Start-OrchestrationStep {
    <#
    .SYNOPSIS
        Démarre une étape d'orchestration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StepName,
        
        [string]$Description,
        [hashtable]$Parameters = @{}
    )
    
    $step = @{
        Name = $StepName
        Description = $Description
        StartTime = Get-Date
        Parameters = $Parameters
        Status = "Running"
        Result = $null
        Error = $null
    }
    
    $script:ExecutionContext.Steps += $step
    
    Write-OrchestratorLog "=== DÉBUT: $StepName ===" -Level "INFO" -Component "STEP"
    if ($Description) {
        Write-OrchestratorLog $Description -Level "INFO" -Component "STEP"
    }
    
    return $step
}

function Complete-OrchestrationStep {
    <#
    .SYNOPSIS
        Termine une étape d'orchestration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Step,
        
        [Parameter(Mandatory)]
        [ValidateSet("Success", "Failed", "Warning")]
        [string]$Status,
        
        [object]$Result = $null,
        [string]$ErrorMessage = $null
    )
    
    $Step.EndTime = Get-Date
    $Step.Duration = $Step.EndTime - $Step.StartTime
    $Step.Status = $Status
    $Step.Result = $Result
    $Step.Error = $ErrorMessage
    
    $level = switch ($Status) {
        "Success" { "SUCCESS" }
        "Failed" { "ERROR" }
        "Warning" { "WARNING" }
    }
    
    $durationText = $Step.Duration.ToString('mm\:ss')
    Write-OrchestratorLog "=== FIN: $($Step.Name) - $Status ($durationText) ===" -Level $level -Component "STEP"
    
    if ($ErrorMessage) {
        Write-OrchestratorLog "Erreur: $ErrorMessage" -Level "ERROR" -Component "STEP"
    }
}

#endregion

#region Orchestration des déploiements

function Start-CompleteDeployment {
    <#
    .SYNOPSIS
        Lance un déploiement complet orchestré
    .PARAMETER ConfigPath
        Chemin vers le fichier de configuration
    .PARAMETER TargetEnvironment
        Environnement cible pour le déploiement
    .PARAMETER SkipInfrastructure
        Ignorer la création de l'infrastructure
    .PARAMETER DryRun
        Exécution à blanc sans modifications réelles
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory)]
        [string]$TargetEnvironment,
        
        [switch]$SkipInfrastructure,
        [switch]$DryRun
    )
    
    try {
        # Initialisation
        $config = Initialize-Orchestrator -ConfigPath $ConfigPath
        
        if ($DryRun) {
            Write-OrchestratorLog "MODE DRY RUN - Aucune modification ne sera effectuée" -Level "WARNING"
        }
        
        # Validation de l'environnement cible
        $environment = $config.Environments | Where-Object { $_.name -eq $TargetEnvironment }
        if (-not $environment) {
            throw "Environnement '$TargetEnvironment' non trouvé dans la configuration"
        }
        
        Write-OrchestratorLog "Déploiement vers l'environnement: $TargetEnvironment" -Level "INFO"
        
        # Étapes du déploiement
        $deploymentSteps = @(
            @{ Name = "Infrastructure"; Function = "Deploy-Infrastructure"; Skip = $SkipInfrastructure },
            @{ Name = "AzureDevOpsProject"; Function = "Deploy-AzureDevOpsProject"; Skip = $false },
            @{ Name = "Pipelines"; Function = "Deploy-Pipelines"; Skip = $false },
            @{ Name = "Application"; Function = "Deploy-Application"; Skip = $false },
            @{ Name = "Monitoring"; Function = "Configure-Monitoring"; Skip = $false },
            @{ Name = "Validation"; Function = "Validate-Deployment"; Skip = $false }
        )
        
        $deploymentResults = @{}
        
        foreach ($stepConfig in $deploymentSteps) {
            if ($stepConfig.Skip) {
                Write-OrchestratorLog "Étape '$($stepConfig.Name)' ignorée" -Level "WARNING"
                continue
            }
            
            $step = Start-OrchestrationStep -StepName $stepConfig.Name -Description "Exécution de l'étape $($stepConfig.Name)"
            
            try {
                $stepResult = & $stepConfig.Function -Config $config -Environment $environment -DryRun:$DryRun
                $deploymentResults[$stepConfig.Name] = $stepResult
                Complete-OrchestrationStep -Step $step -Status "Success" -Result $stepResult
            }
            catch {
                Complete-OrchestrationStep -Step $step -Status "Failed" -ErrorMessage $_.Exception.Message
                
                # Gestion des erreurs critiques
                if ($stepConfig.Name -in @("Infrastructure", "AzureDevOpsProject")) {
                    Write-OrchestratorLog "Erreur critique détectée, arrêt du déploiement" -Level "ERROR"
                    throw
                }
                else {
                    Write-OrchestratorLog "Erreur non critique, continuation du déploiement" -Level "WARNING"
                }
            }
        }
        
        # Génération du rapport final
        $deploymentSummary = Generate-DeploymentSummary -Results $deploymentResults -Config $config -Environment $environment
        
        # Notifications
        Send-DeploymentNotifications -Summary $deploymentSummary -Config $config
        
        Write-OrchestratorLog "=== DÉPLOIEMENT TERMINÉ ===" -Level "SUCCESS"
        return $deploymentSummary
    }
    catch {
        Write-OrchestratorLog "=== ÉCHEC DU DÉPLOIEMENT ===" -Level "ERROR"
        Write-OrchestratorLog "Erreur: $($_.Exception.Message)" -Level "ERROR"
        
        # Notification d'échec
        Send-FailureNotification -Error $_.Exception.Message -Config $config
        
        throw
    }
}

function Deploy-Infrastructure {
    <#
    .SYNOPSIS
        Déploie l'infrastructure Azure
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [OrchestrationConfig]$Config,
        
        [Parameter(Mandatory)]
        [object]$Environment,
        
        [switch]$DryRun
    )
    
    Write-OrchestratorLog "Déploiement de l'infrastructure Azure..." -Level "INFO" -Component "INFRA"
    
    if ($DryRun) {
        Write-OrchestratorLog "DRY RUN: Simulation du déploiement d'infrastructure" -Level "WARNING" -Component "INFRA"
        return @{
            ResourceGroup = @{ Name = $Config.ResourceGroupName; Status = "Simulated" }
            AppServicePlan = @{ Name = $Config.AppServicePlanName; Status = "Simulated" }
            WebApp = @{ Name = $Config.WebAppName; Status = "Simulated" }
        }
    }
    
    try {
        # Utilisation d'Azure CLI pour la création rapide
        Write-OrchestratorLog "Création du groupe de ressources..." -Level "INFO" -Component "INFRA"
        $rgResult = az group create --name $Config.ResourceGroupName --location $Config.Location | ConvertFrom-Json
        
        Write-OrchestratorLog "Création du plan App Service..." -Level "INFO" -Component "INFRA"
        $aspResult = az appservice plan create --name $Config.AppServicePlanName --resource-group $Config.ResourceGroupName --sku $Environment.appServiceSku | ConvertFrom-Json
        
        Write-OrchestratorLog "Création de l'application web..." -Level "INFO" -Component "INFRA"
        $webAppResult = az webapp create --name $Config.WebAppName --resource-group $Config.ResourceGroupName --plan $Config.AppServicePlanName | ConvertFrom-Json
        
        # Configuration avec PowerShell pour les paramètres avancés
        if ($Environment.appSettings) {
            Write-OrchestratorLog "Configuration des paramètres d'application..." -Level "INFO" -Component "INFRA"
            Set-AzWebApp -ResourceGroupName $Config.ResourceGroupName -Name $Config.WebAppName -AppSettings $Environment.appSettings
        }
        
        return @{
            ResourceGroup = $rgResult
            AppServicePlan = $aspResult
            WebApp = $webAppResult
        }
    }
    catch {
        Write-OrchestratorLog "Erreur lors du déploiement d'infrastructure: $($_.Exception.Message)" -Level "ERROR" -Component "INFRA"
        throw
    }
}

function Deploy-AzureDevOpsProject {
    <#
    .SYNOPSIS
        Déploie le projet Azure DevOps
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [OrchestrationConfig]$Config,
        
        [Parameter(Mandatory)]
        [object]$Environment,
        
        [switch]$DryRun
    )
    
    Write-OrchestratorLog "Déploiement du projet Azure DevOps..." -Level "INFO" -Component "DEVOPS"
    
    if ($DryRun) {
        Write-OrchestratorLog "DRY RUN: Simulation du déploiement Azure DevOps" -Level "WARNING" -Component "DEVOPS"
        return @{ ProjectId = "simulated-project-id"; Status = "Simulated" }
    }
    
    try {
        # Vérification si le projet existe
        $existingProject = az devops project show --project $Config.ProjectName 2>$null | ConvertFrom-Json
        
        if ($existingProject) {
            Write-OrchestratorLog "Projet '$($Config.ProjectName)' existe déjà" -Level "WARNING" -Component "DEVOPS"
            return @{ ProjectId = $existingProject.id; Status = "Existing" }
        }
        
        # Création du projet
        Write-OrchestratorLog "Création du projet Azure DevOps..." -Level "INFO" -Component "DEVOPS"
        $projectResult = az devops project create --name $Config.ProjectName --description "Projet créé automatiquement par l'orchestrateur" | ConvertFrom-Json
        
        # Attente de l'initialisation
        Write-OrchestratorLog "Attente de l'initialisation du projet..." -Level "INFO" -Component "DEVOPS"
        do {
            Start-Sleep -Seconds 5
            $projectStatus = az devops project show --project $Config.ProjectName | ConvertFrom-Json
        } while ($projectStatus.state -ne "wellFormed")
        
        # Création du dépôt
        Write-OrchestratorLog "Création du dépôt Git..." -Level "INFO" -Component "DEVOPS"
        $repoResult = az repos create --name $Config.AzureDevOpsSettings.repositoryName --project $Config.ProjectName | ConvertFrom-Json
        
        return @{
            ProjectId = $projectResult.id
            Project = $projectResult
            Repository = $repoResult
            Status = "Created"
        }
    }
    catch {
        Write-OrchestratorLog "Erreur lors du déploiement Azure DevOps: $($_.Exception.Message)" -Level "ERROR" -Component "DEVOPS"
        throw
    }
}

function Deploy-Pipelines {
    <#
    .SYNOPSIS
        Déploie les pipelines CI/CD
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [OrchestrationConfig]$Config,
        
        [Parameter(Mandatory)]
        [object]$Environment,
        
        [switch]$DryRun
    )
    
    Write-OrchestratorLog "Déploiement des pipelines..." -Level "INFO" -Component "PIPELINE"
    
    if ($DryRun) {
        Write-OrchestratorLog "DRY RUN: Simulation du déploiement des pipelines" -Level "WARNING" -Component "PIPELINE"
        return @{ PipelineId = "simulated-pipeline-id"; Status = "Simulated" }
    }
    
    try {
        # Création du fichier de pipeline YAML
        $pipelineYaml = Generate-PipelineYaml -Config $Config -Environment $Environment
        
        # Sauvegarde temporaire du fichier YAML
        $tempYamlPath = [System.IO.Path]::GetTempFileName() + ".yml"
        $pipelineYaml | Out-File -FilePath $tempYamlPath -Encoding UTF8
        
        try {
            # Création du pipeline
            Write-OrchestratorLog "Création du pipeline CI/CD..." -Level "INFO" -Component "PIPELINE"
            $pipelineResult = az pipelines create --name "$($Config.ProjectName)-CI-CD" --description "Pipeline CI/CD automatisé" --repository $Config.AzureDevOpsSettings.repositoryName --repository-type tfsgit --branch main --yml-path "azure-pipelines.yml" --project $Config.ProjectName | ConvertFrom-Json
            
            return @{
                PipelineId = $pipelineResult.id
                Pipeline = $pipelineResult
                Status = "Created"
            }
        }
        finally {
            # Nettoyage du fichier temporaire
            if (Test-Path $tempYamlPath) {
                Remove-Item $tempYamlPath -Force
            }
        }
    }
    catch {
        Write-OrchestratorLog "Erreur lors du déploiement des pipelines: $($_.Exception.Message)" -Level "ERROR" -Component "PIPELINE"
        throw
    }
}

function Generate-PipelineYaml {
    <#
    .SYNOPSIS
        Génère le contenu YAML du pipeline
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [OrchestrationConfig]$Config,
        
        [Parameter(Mandatory)]
        [object]$Environment
    )
    
    return @"
# Pipeline CI/CD généré automatiquement
# Projet: $($Config.ProjectName)
# Environnement: $($Environment.name)
# Généré le: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

trigger:
- main
- develop

pool:
  vmImage: 'ubuntu-latest'

variables:
  buildConfiguration: 'Release'
  webAppName: '$($Config.WebAppName)'
  resourceGroupName: '$($Config.ResourceGroupName)'
  azureSubscription: '$($Config.AzureSubscriptionId)'

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
        arguments: '--configuration `$(buildConfiguration)'

    - task: DotNetCoreCLI@2
      displayName: 'Run tests'
      inputs:
        command: 'test'
        projects: '**/*Tests.csproj'
        arguments: '--configuration `$(buildConfiguration) --collect "Code coverage"'

    - task: DotNetCoreCLI@2
      displayName: 'Publish application'
      inputs:
        command: 'publish'
        projects: '**/*.csproj'
        arguments: '--configuration `$(buildConfiguration) --output `$(Build.ArtifactStagingDirectory)'

    - task: PublishBuildArtifacts@1
      displayName: 'Publish artifacts'
      inputs:
        PathtoPublish: '`$(Build.ArtifactStagingDirectory)'
        ArtifactName: 'drop'

- stage: Deploy
  displayName: 'Deploy stage'
  dependsOn: Build
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:
  - deployment: Deploy
    displayName: 'Deploy job'
    environment: '$($Environment.name)'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: AzureWebApp@1
            displayName: 'Deploy to Azure Web App'
            inputs:
              azureSubscription: '`$(azureSubscription)'
              appType: 'webApp'
              appName: '`$(webAppName)'
              package: '`$(Pipeline.Workspace)/drop/**/*.zip'

          - task: PowerShell@2
            displayName: 'Post-deployment validation'
            inputs:
              targetType: 'inline'
              script: |
                `$url = "https://`$(webAppName).azurewebsites.net"
                `$response = Invoke-WebRequest -Uri `$url -UseBasicParsing
                if (`$response.StatusCode -eq 200) {
                  Write-Host "✓ Application déployée avec succès"
                } else {
                  Write-Error "✗ Échec de la validation du déploiement"
                  exit 1
                }
"@
}

#endregion

# Export des fonctions publiques
Export-ModuleMember -Function @(
    'Initialize-Orchestrator',
    'Start-CompleteDeployment',
    'Write-OrchestratorLog'
)
```

### 1.2 Fichier de configuration JSON
Créez un fichier `orchestration-config.json` :

```json
{
    "project": {
        "name": "ProjetOrchestre",
        "description": "Projet créé par l'orchestrateur d'automatisation"
    },
    "azureDevOps": {
        "organizationUrl": "https://dev.azure.com/votre-organisation",
        "repositoryName": "app-orchestree",
        "processTemplate": "Agile"
    },
    "azure": {
        "subscriptionId": "votre-subscription-id",
        "resourceGroupName": "rg-orchestrateur-demo",
        "location": "West Europe",
        "webAppName": "webapp-orchestrateur-001",
        "appServicePlanName": "asp-orchestrateur"
    },
    "environments": [
        {
            "name": "development",
            "appServiceSku": "F1",
            "appSettings": {
                "ASPNETCORE_ENVIRONMENT": "Development",
                "DEPLOYMENT_METHOD": "Orchestrateur",
                "ENVIRONMENT": "Development"
            },
            "deploymentSlots": false,
            "monitoring": {
                "enabled": true,
                "alertRules": [
                    {
                        "name": "High CPU Usage",
                        "metric": "CpuPercentage",
                        "threshold": 80,
                        "operator": "GreaterThan"
                    }
                ]
            }
        },
        {
            "name": "production",
            "appServiceSku": "S1",
            "appSettings": {
                "ASPNETCORE_ENVIRONMENT": "Production",
                "DEPLOYMENT_METHOD": "Orchestrateur",
                "ENVIRONMENT": "Production"
            },
            "deploymentSlots": true,
            "monitoring": {
                "enabled": true,
                "alertRules": [
                    {
                        "name": "High CPU Usage",
                        "metric": "CpuPercentage",
                        "threshold": 70,
                        "operator": "GreaterThan"
                    },
                    {
                        "name": "High Memory Usage",
                        "metric": "MemoryPercentage",
                        "threshold": 80,
                        "operator": "GreaterThan"
                    }
                ]
            }
        }
    ],
    "deployment": {
        "strategy": "BlueGreen",
        "rollbackOnFailure": true,
        "healthCheckUrl": "/health",
        "healthCheckTimeout": 300,
        "preDeploymentSteps": [
            {
                "type": "backup",
                "enabled": true
            },
            {
                "type": "notification",
                "enabled": true,
                "message": "Déploiement en cours..."
            }
        ],
        "postDeploymentSteps": [
            {
                "type": "healthCheck",
                "enabled": true
            },
            {
                "type": "notification",
                "enabled": true,
                "message": "Déploiement terminé"
            }
        ]
    },
    "notifications": {
        "email": {
            "enabled": true,
            "recipients": ["admin@monentreprise.com"],
            "smtpServer": "smtp.office365.com",
            "smtpPort": 587
        },
        "teams": {
            "enabled": true,
            "webhookUrl": "https://outlook.office.com/webhook/..."
        },
        "slack": {
            "enabled": false,
            "webhookUrl": ""
        }
    },
    "monitoring": {
        "applicationInsights": {
            "enabled": true,
            "instrumentationKey": ""
        },
        "logAnalytics": {
            "enabled": true,
            "workspaceId": ""
        },
        "customMetrics": [
            {
                "name": "DeploymentSuccess",
                "type": "counter"
            },
            {
                "name": "DeploymentDuration",
                "type": "histogram"
            }
        ]
    }
}
```

## Étape 2 : Implémentation des fonctions de déploiement (25 minutes)

### 2.1 Ajout des fonctions manquantes au module
Ajoutez ces fonctions au module `DevOpsOrchestrator.psm1` :

```powershell
#region Fonctions de déploiement et validation

function Deploy-Application {
    <#
    .SYNOPSIS
        Déploie l'application
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [OrchestrationConfig]$Config,
        
        [Parameter(Mandatory)]
        [object]$Environment,
        
        [switch]$DryRun
    )
    
    Write-OrchestratorLog "Déploiement de l'application..." -Level "INFO" -Component "APP"
    
    if ($DryRun) {
        Write-OrchestratorLog "DRY RUN: Simulation du déploiement d'application" -Level "WARNING" -Component "APP"
        return @{ Status = "Simulated"; Url = "https://$($Config.WebAppName).azurewebsites.net" }
    }
    
    try {
        # Exécution des étapes pré-déploiement
        foreach ($step in $Config.DeploymentSettings.preDeploymentSteps) {
            if ($step.enabled) {
                Execute-DeploymentStep -Step $step -Config $Config -Environment $Environment -Phase "Pre"
            }
        }
        
        # Déploiement principal (simulation avec un package de test)
        Write-OrchestratorLog "Création d'un package de test..." -Level "INFO" -Component "APP"
        $testPackagePath = Create-TestApplicationPackage -Config $Config
        
        try {
            # Déploiement via Azure CLI
            Write-OrchestratorLog "Déploiement du package..." -Level "INFO" -Component "APP"
            $deployResult = az webapp deployment source config-zip --resource-group $Config.ResourceGroupName --name $Config.WebAppName --src $testPackagePath | ConvertFrom-Json
            
            # Attente de la disponibilité
            $appUrl = "https://$($Config.WebAppName).azurewebsites.net"
            Wait-ApplicationAvailability -Url $appUrl -TimeoutMinutes 5
            
            # Exécution des étapes post-déploiement
            foreach ($step in $Config.DeploymentSettings.postDeploymentSteps) {
                if ($step.enabled) {
                    Execute-DeploymentStep -Step $step -Config $Config -Environment $Environment -Phase "Post"
                }
            }
            
            return @{
                Status = "Success"
                Url = $appUrl
                DeploymentId = $deployResult.id
            }
        }
        finally {
            # Nettoyage du package temporaire
            if (Test-Path $testPackagePath) {
                Remove-Item $testPackagePath -Force
            }
        }
    }
    catch {
        Write-OrchestratorLog "Erreur lors du déploiement d'application: $($_.Exception.Message)" -Level "ERROR" -Component "APP"
        
        # Rollback si configuré
        if ($Config.DeploymentSettings.rollbackOnFailure) {
            Write-OrchestratorLog "Déclenchement du rollback..." -Level "WARNING" -Component "APP"
            Start-ApplicationRollback -Config $Config -Environment $Environment
        }
        
        throw
    }
}

function Create-TestApplicationPackage {
    <#
    .SYNOPSIS
        Crée un package d'application de test
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [OrchestrationConfig]$Config
    )
    
    $tempDir = [System.IO.Path]::GetTempPath() + [Guid]::NewGuid().ToString()
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    try {
        # Création d'une application web simple
        $indexHtml = @"
<!DOCTYPE html>
<html>
<head>
    <title>Application Orchestrée - $($Config.ProjectName)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
        .container { max-width: 800px; margin: 0 auto; text-align: center; }
        .card { background: rgba(255,255,255,0.1); padding: 30px; border-radius: 10px; margin: 20px 0; }
        .status { color: #4CAF50; font-weight: bold; }
        .info { background: rgba(255,255,255,0.05); padding: 15px; border-radius: 5px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Application Déployée avec Succès</h1>
        <div class="card">
            <h2>Projet: $($Config.ProjectName)</h2>
            <p class="status">✅ Statut: Opérationnel</p>
            <div class="info">
                <strong>Déployé le:</strong> $(Get-Date -Format 'dd/MM/yyyy à HH:mm:ss')<br>
                <strong>Méthode:</strong> Orchestrateur d'automatisation<br>
                <strong>Environnement:</strong> Azure App Service<br>
                <strong>Région:</strong> $($Config.Location)
            </div>
        </div>
        
        <div class="card">
            <h3>🔧 Informations Techniques</h3>
            <div class="info">
                <strong>Groupe de ressources:</strong> $($Config.ResourceGroupName)<br>
                <strong>Application web:</strong> $($Config.WebAppName)<br>
                <strong>Plan App Service:</strong> $($Config.AppServicePlanName)
            </div>
        </div>
        
        <div class="card">
            <h3>📊 Points de contrôle</h3>
            <p><a href="/health" style="color: #4CAF50;">🏥 Health Check</a></p>
            <p><a href="/api/status" style="color: #2196F3;">📡 API Status</a></p>
        </div>
    </div>
    
    <script>
        // Mise à jour automatique du timestamp
        setInterval(function() {
            document.title = 'Application Orchestrée - Actif depuis ' + new Date().toLocaleTimeString();
        }, 1000);
    </script>
</body>
</html>
"@
        
        # Création du fichier web.config pour IIS
        $webConfig = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <defaultDocument>
      <files>
        <clear />
        <add value="index.html" />
      </files>
    </defaultDocument>
    <staticContent>
      <mimeMap fileExtension=".json" mimeType="application/json" />
    </staticContent>
  </system.webServer>
</configuration>
"@
        
        # Création d'un endpoint de health check
        $healthJson = @"
{
    "status": "healthy",
    "timestamp": "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')",
    "version": "1.0.0",
    "environment": "orchestrated",
    "checks": {
        "database": "ok",
        "external_api": "ok",
        "disk_space": "ok",
        "memory": "ok"
    }
}
"@
        
        # Sauvegarde des fichiers
        $indexHtml | Out-File -FilePath "$tempDir\index.html" -Encoding UTF8
        $webConfig | Out-File -FilePath "$tempDir\web.config" -Encoding UTF8
        $healthJson | Out-File -FilePath "$tempDir\health.json" -Encoding UTF8
        
        # Création du package ZIP
        $zipPath = [System.IO.Path]::GetTempFileName() + ".zip"
        Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
        
        Write-OrchestratorLog "Package d'application créé: $zipPath" -Level "SUCCESS" -Component "APP"
        return $zipPath
    }
    finally {
        # Nettoyage du répertoire temporaire
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force
        }
    }
}

function Wait-ApplicationAvailability {
    <#
    .SYNOPSIS
        Attend que l'application soit disponible
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Url,
        
        [int]$TimeoutMinutes = 5,
        [int]$PollingIntervalSeconds = 15
    )
    
    $startTime = Get-Date
    $timeoutTime = $startTime.AddMinutes($TimeoutMinutes)
    
    Write-OrchestratorLog "Vérification de la disponibilité de l'application: $Url" -Level "INFO" -Component "APP"
    
    do {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 30
            if ($response.StatusCode -eq 200) {
                $duration = (Get-Date) - $startTime
                Write-OrchestratorLog "✓ Application disponible après $($duration.ToString('mm\:ss'))" -Level "SUCCESS" -Component "APP"
                return $true
            }
        }
        catch {
            Write-OrchestratorLog "Application non encore disponible, nouvelle tentative dans $PollingIntervalSeconds secondes..." -Level "INFO" -Component "APP"
        }
        
        if ((Get-Date) -gt $timeoutTime) {
            Write-OrchestratorLog "Timeout atteint ($TimeoutMinutes minutes)" -Level "WARNING" -Component "APP"
            return $false
        }
        
        Start-Sleep -Seconds $PollingIntervalSeconds
    } while ($true)
}

function Execute-DeploymentStep {
    <#
    .SYNOPSIS
        Exécute une étape de déploiement
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Step,
        
        [Parameter(Mandatory)]
        [OrchestrationConfig]$Config,
        
        [Parameter(Mandatory)]
        [object]$Environment,
        
        [Parameter(Mandatory)]
        [ValidateSet("Pre", "Post")]
        [string]$Phase
    )
    
    Write-OrchestratorLog "Exécution de l'étape $Phase-déploiement: $($Step.type)" -Level "INFO" -Component "STEP"
    
    switch ($Step.type) {
        "backup" {
            Write-OrchestratorLog "Création d'une sauvegarde..." -Level "INFO" -Component "STEP"
            # Implémentation de la sauvegarde
        }
        
        "notification" {
            Write-OrchestratorLog "Envoi de notification: $($Step.message)" -Level "INFO" -Component "STEP"
            Send-DeploymentNotification -Message $Step.message -Config $Config -Phase $Phase
        }
        
        "healthCheck" {
            Write-OrchestratorLog "Vérification de santé de l'application..." -Level "INFO" -Component "STEP"
            $healthUrl = "https://$($Config.WebAppName).azurewebsites.net$($Config.DeploymentSettings.healthCheckUrl)"
            $isHealthy = Test-ApplicationHealth -Url $healthUrl -TimeoutSeconds $Config.DeploymentSettings.healthCheckTimeout
            
            if (-not $isHealthy) {
                throw "Échec de la vérification de santé de l'application"
            }
        }
        
        default {
            Write-OrchestratorLog "Type d'étape non reconnu: $($Step.type)" -Level "WARNING" -Component "STEP"
        }
    }
}

function Configure-Monitoring {
    <#
    .SYNOPSIS
        Configure le monitoring de l'application
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [OrchestrationConfig]$Config,
        
        [Parameter(Mandatory)]
        [object]$Environment,
        
        [switch]$DryRun
    )
    
    Write-OrchestratorLog "Configuration du monitoring..." -Level "INFO" -Component "MONITOR"
    
    if ($DryRun) {
        Write-OrchestratorLog "DRY RUN: Simulation de la configuration du monitoring" -Level "WARNING" -Component "MONITOR"
        return @{ Status = "Simulated" }
    }
    
    try {
        $monitoringResults = @{}
        
        # Configuration d'Application Insights (si activé)
        if ($Config.monitoring.applicationInsights.enabled) {
            Write-OrchestratorLog "Configuration d'Application Insights..." -Level "INFO" -Component "MONITOR"
            
            # Création de la ressource Application Insights
            $appInsightsResult = az monitor app-insights component create --app "$($Config.WebAppName)-insights" --location $Config.Location --resource-group $Config.ResourceGroupName --application-type web | ConvertFrom-Json
            
            # Configuration de l'application web pour utiliser Application Insights
            $appSettings = @{
                "APPINSIGHTS_INSTRUMENTATIONKEY" = $appInsightsResult.instrumentationKey
                "APPLICATIONINSIGHTS_CONNECTION_STRING" = $appInsightsResult.connectionString
            }
            
            Set-AzWebApp -ResourceGroupName $Config.ResourceGroupName -Name $Config.WebAppName -AppSettings $appSettings
            
            $monitoringResults.ApplicationInsights = $appInsightsResult
        }
        
        # Configuration des alertes
        if ($Environment.monitoring.enabled -and $Environment.monitoring.alertRules) {
            Write-OrchestratorLog "Configuration des règles d'alerte..." -Level "INFO" -Component "MONITOR"
            
            foreach ($alertRule in $Environment.monitoring.alertRules) {
                $alertResult = az monitor metrics alert create --name $alertRule.name --resource-group $Config.ResourceGroupName --scopes "/subscriptions/$($Config.AzureSubscriptionId)/resourceGroups/$($Config.ResourceGroupName)/providers/Microsoft.Web/sites/$($Config.WebAppName)" --condition "avg $($alertRule.metric) $($alertRule.operator) $($alertRule.threshold)" --description "Alerte automatique créée par l'orchestrateur" | ConvertFrom-Json
                
                $monitoringResults.AlertRules += @($alertResult)
            }
        }
        
        Write-OrchestratorLog "Monitoring configuré avec succès" -Level "SUCCESS" -Component "MONITOR"
        return $monitoringResults
    }
    catch {
        Write-OrchestratorLog "Erreur lors de la configuration du monitoring: $($_.Exception.Message)" -Level "ERROR" -Component "MONITOR"
        throw
    }
}

function Validate-Deployment {
    <#
    .SYNOPSIS
        Valide le déploiement complet
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [OrchestrationConfig]$Config,
        
        [Parameter(Mandatory)]
        [object]$Environment,
        
        [switch]$DryRun
    )
    
    Write-OrchestratorLog "Validation du déploiement..." -Level "INFO" -Component "VALIDATE"
    
    if ($DryRun) {
        Write-OrchestratorLog "DRY RUN: Simulation de la validation" -Level "WARNING" -Component "VALIDATE"
        return @{ Status = "Simulated"; AllTestsPassed = $true }
    }
    
    $validationResults = @{
        Tests = @()
        AllTestsPassed = $true
        Summary = ""
    }
    
    # Tests de validation
    $validationTests = @(
        @{
            Name = "Application Web Accessible"
            Test = { 
                $response = Invoke-WebRequest -Uri "https://$($Config.WebAppName).azurewebsites.net" -UseBasicParsing
                return $response.StatusCode -eq 200
            }
        },
        @{
            Name = "Health Check Endpoint"
            Test = {
                $response = Invoke-WebRequest -Uri "https://$($Config.WebAppName).azurewebsites.net/health.json" -UseBasicParsing
                $healthData = $response.Content | ConvertFrom-Json
                return $healthData.status -eq "healthy"
            }
        },
        @{
            Name = "Ressources Azure Créées"
            Test = {
                $rg = Get-AzResourceGroup -Name $Config.ResourceGroupName -ErrorAction SilentlyContinue
                $webapp = Get-AzWebApp -ResourceGroupName $Config.ResourceGroupName -Name $Config.WebAppName -ErrorAction SilentlyContinue
                return ($rg -and $webapp)
            }
        },
        @{
            Name = "Projet Azure DevOps Accessible"
            Test = {
                $project = az devops project show --project $Config.ProjectName 2>$null | ConvertFrom-Json
                return $project -and $project.state -eq "wellFormed"
            }
        }
    )
    
    foreach ($test in $validationTests) {
        $testResult = @{
            Name = $test.Name
            StartTime = Get-Date
        }
        
        try {
            Write-OrchestratorLog "Test: $($test.Name)..." -Level "INFO" -Component "VALIDATE"
            $result = & $test.Test
            
            $testResult.Passed = $result
            $testResult.Error = $null
            
            if ($result) {
                Write-OrchestratorLog "✓ $($test.Name)" -Level "SUCCESS" -Component "VALIDATE"
            }
            else {
                Write-OrchestratorLog "✗ $($test.Name)" -Level "ERROR" -Component "VALIDATE"
                $validationResults.AllTestsPassed = $false
            }
        }
        catch {
            $testResult.Passed = $false
            $testResult.Error = $_.Exception.Message
            $validationResults.AllTestsPassed = $false
            
            Write-OrchestratorLog "✗ $($test.Name): $($_.Exception.Message)" -Level "ERROR" -Component "VALIDATE"
        }
        
        $testResult.EndTime = Get-Date
        $testResult.Duration = $testResult.EndTime - $testResult.StartTime
        $validationResults.Tests += $testResult
    }
    
    # Génération du résumé
    $passedTests = ($validationResults.Tests | Where-Object { $_.Passed }).Count
    $totalTests = $validationResults.Tests.Count
    $validationResults.Summary = "$passedTests/$totalTests tests réussis"
    
    if ($validationResults.AllTestsPassed) {
        Write-OrchestratorLog "✓ Tous les tests de validation sont passés ($($validationResults.Summary))" -Level "SUCCESS" -Component "VALIDATE"
    }
    else {
        Write-OrchestratorLog "✗ Certains tests de validation ont échoué ($($validationResults.Summary))" -Level "ERROR" -Component "VALIDATE"
    }
    
    return $validationResults
}

#endregion

#region Notifications et rapports

function Generate-DeploymentSummary {
    <#
    .SYNOPSIS
        Génère un résumé du déploiement
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Results,
        
        [Parameter(Mandatory)]
        [OrchestrationConfig]$Config,
        
        [Parameter(Mandatory)]
        [object]$Environment
    )
    
    $summary = @{
        ExecutionId = $script:ExecutionContext.ExecutionId
        ProjectName = $Config.ProjectName
        Environment = $Environment.name
        StartTime = $script:ExecutionContext.StartTime
        EndTime = Get-Date
        Duration = (Get-Date) - $script:ExecutionContext.StartTime
        Status = "Success"
        Results = $Results
        Steps = $script:ExecutionContext.Steps
        Urls = @{
            Application = "https://$($Config.WebAppName).azurewebsites.net"
            AzurePortal = "https://portal.azure.com/#@/resource/subscriptions/$($Config.AzureSubscriptionId)/resourceGroups/$($Config.ResourceGroupName)"
            AzureDevOps = "$($Config.OrganizationUrl)/$($Config.ProjectName)"
        }
    }
    
    # Détermination du statut global
    $failedSteps = $summary.Steps | Where-Object { $_.Status -eq "Failed" }
    if ($failedSteps.Count -gt 0) {
        $summary.Status = "PartialSuccess"
        if ($failedSteps | Where-Object { $_.Name -in @("Infrastructure", "AzureDevOpsProject") }) {
            $summary.Status = "Failed"
        }
    }
    
    return $summary
}

function Send-DeploymentNotifications {
    <#
    .SYNOPSIS
        Envoie les notifications de déploiement
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Summary,
        
        [Parameter(Mandatory)]
        [OrchestrationConfig]$Config
    )
    
    Write-OrchestratorLog "Envoi des notifications de déploiement..." -Level "INFO" -Component "NOTIFY"
    
    $statusEmoji = switch ($Summary.Status) {
        "Success" { "✅" }
        "PartialSuccess" { "⚠️" }
        "Failed" { "❌" }
    }
    
    $message = @"
$statusEmoji Déploiement $($Summary.Status)

📋 Projet: $($Summary.ProjectName)
🌍 Environnement: $($Summary.Environment)
⏱️ Durée: $($Summary.Duration.ToString('hh\:mm\:ss'))
🆔 ID d'exécution: $($Summary.ExecutionId)

🔗 Liens:
• Application: $($Summary.Urls.Application)
• Azure Portal: $($Summary.Urls.AzurePortal)
• Azure DevOps: $($Summary.Urls.AzureDevOps)

📊 Étapes:
$($Summary.Steps | ForEach-Object { "• $($_.Name): $($_.Status) ($($_.Duration.ToString('mm\:ss')))" } | Join-String -Separator "`n")
"@
    
    # Notification par email
    if ($Config.NotificationSettings.email.enabled) {
        try {
            Send-EmailNotification -Message $message -Config $Config -Subject "Déploiement $($Summary.Status) - $($Summary.ProjectName)"
            Write-OrchestratorLog "✓ Notification email envoyée" -Level "SUCCESS" -Component "NOTIFY"
        }
        catch {
            Write-OrchestratorLog "✗ Erreur envoi email: $($_.Exception.Message)" -Level "ERROR" -Component "NOTIFY"
        }
    }
    
    # Notification Teams
    if ($Config.NotificationSettings.teams.enabled) {
        try {
            Send-TeamsNotification -Message $message -Config $Config -Summary $Summary
            Write-OrchestratorLog "✓ Notification Teams envoyée" -Level "SUCCESS" -Component "NOTIFY"
        }
        catch {
            Write-OrchestratorLog "✗ Erreur envoi Teams: $($_.Exception.Message)" -Level "ERROR" -Component "NOTIFY"
        }
    }
}

function Send-TeamsNotification {
    <#
    .SYNOPSIS
        Envoie une notification Microsoft Teams
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter(Mandatory)]
        [OrchestrationConfig]$Config,
        
        [Parameter(Mandatory)]
        [object]$Summary
    )
    
    $color = switch ($Summary.Status) {
        "Success" { "00FF00" }
        "PartialSuccess" { "FFA500" }
        "Failed" { "FF0000" }
    }
    
    $teamsPayload = @{
        "@type" = "MessageCard"
        "@context" = "http://schema.org/extensions"
        "themeColor" = $color
        "summary" = "Déploiement $($Summary.Status) - $($Summary.ProjectName)"
        "sections" = @(
            @{
                "activityTitle" = "🚀 Déploiement Orchestré"
                "activitySubtitle" = "$($Summary.ProjectName) - $($Summary.Environment)"
                "facts" = @(
                    @{ "name" = "Statut"; "value" = $Summary.Status },
                    @{ "name" = "Durée"; "value" = $Summary.Duration.ToString('hh\:mm\:ss') },
                    @{ "name" = "Environnement"; "value" = $Summary.Environment },
                    @{ "name" = "ID d'exécution"; "value" = $Summary.ExecutionId }
                )
                "markdown" = $true
            }
        )
        "potentialAction" = @(
            @{
                "@type" = "OpenUri"
                "name" = "Voir l'application"
                "targets" = @(
                    @{ "os" = "default"; "uri" = $Summary.Urls.Application }
                )
            },
            @{
                "@type" = "OpenUri"
                "name" = "Azure Portal"
                "targets" = @(
                    @{ "os" = "default"; "uri" = $Summary.Urls.AzurePortal }
                )
            }
        )
    }
    
    $json = $teamsPayload | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Uri $Config.NotificationSettings.teams.webhookUrl -Method POST -Body $json -ContentType "application/json"
}

#endregion
```

## Étape 3 : Script principal d'orchestration (25 minutes)

### 3.1 Script de lancement principal
Créez un script `Start-OrchestrationDemo.ps1` :

```powershell
<#
.SYNOPSIS
    Script de démonstration de l'orchestrateur d'automatisation Azure DevOps
.DESCRIPTION
    Ce script démontre l'utilisation complète de l'orchestrateur pour automatiser
    le déploiement d'un projet Azure DevOps avec infrastructure Azure
.PARAMETER ConfigFile
    Fichier de configuration JSON
.PARAMETER Environment
    Environnement cible (development, production)
.PARAMETER DryRun
    Exécution à blanc sans modifications réelles
.PARAMETER SkipInfrastructure
    Ignorer la création de l'infrastructure Azure
.PARAMETER Interactive
    Mode interactif avec confirmations utilisateur
.EXAMPLE
    .\Start-OrchestrationDemo.ps1 -ConfigFile "orchestration-config.json" -Environment "development" -DryRun
.EXAMPLE
    .\Start-OrchestrationDemo.ps1 -ConfigFile "orchestration-config.json" -Environment "production" -Interactive
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({Test-Path $_})]
    [string]$ConfigFile,
    
    [Parameter(Mandatory)]
    [ValidateSet("development", "production")]
    [string]$Environment,
    
    [switch]$DryRun,
    [switch]$SkipInfrastructure,
    [switch]$Interactive,
    [switch]$GenerateReport
)

# Configuration des préférences
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Import du module d'orchestration
$modulePath = Join-Path $PSScriptRoot "DevOpsOrchestrator.psm1"
if (-not (Test-Path $modulePath)) {
    Write-Error "Module DevOpsOrchestrator.psm1 non trouvé dans $PSScriptRoot"
    exit 1
}

Import-Module $modulePath -Force

# Variables globales
$script:DemoStartTime = Get-Date
$script:DemoResults = @{}

function Show-DemoHeader {
    Clear-Host
    Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🚀 ORCHESTRATEUR D'AUTOMATISATION AZURE DEVOPS            ║
║                                                                              ║
║  Démonstration complète d'automatisation avec intégration:                  ║
║  • Azure CLI                                                                 ║
║  • PowerShell                                                                ║
║  • API REST Azure DevOps                                                     ║
║  • Infrastructure Azure                                                      ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

    Write-Host "`n📋 Configuration de la démonstration:" -ForegroundColor Yellow
    Write-Host "   Fichier de config: $ConfigFile" -ForegroundColor White
    Write-Host "   Environnement: $Environment" -ForegroundColor White
    Write-Host "   Mode DryRun: $(if ($DryRun) { 'Activé' } else { 'Désactivé' })" -ForegroundColor White
    Write-Host "   Infrastructure: $(if ($SkipInfrastructure) { 'Ignorée' } else { 'Incluse' })" -ForegroundColor White
    Write-Host "   Mode interactif: $(if ($Interactive) { 'Activé' } else { 'Désactivé' })" -ForegroundColor White
    Write-Host ""
}

function Test-DemoPrerequisites {
    Write-Host "🔍 Vérification des prérequis..." -ForegroundColor Yellow
    
    $prerequisites = @(
        @{
            Name = "Azure CLI"
            Test = { az --version }
            Required = $true
        },
        @{
            Name = "Azure DevOps Extension"
            Test = { az extension list --query "[?name=='azure-devops'].version" }
            Required = $true
        },
        @{
            Name = "PowerShell Az Module"
            Test = { Get-Module -ListAvailable Az.Accounts }
            Required = $true
        },
        @{
            Name = "Fichier de configuration"
            Test = { Test-Path $ConfigFile }
            Required = $true
        }
    )
    
    $allPassed = $true
    
    foreach ($prereq in $prerequisites) {
        try {
            $null = & $prereq.Test
            Write-Host "   ✅ $($prereq.Name)" -ForegroundColor Green
        }
        catch {
            if ($prereq.Required) {
                Write-Host "   ❌ $($prereq.Name) - REQUIS" -ForegroundColor Red
                $allPassed = $false
            }
            else {
                Write-Host "   ⚠️ $($prereq.Name) - Optionnel" -ForegroundColor Yellow
            }
        }
    }
    
    if (-not $allPassed) {
        Write-Host "`n❌ Certains prérequis ne sont pas satisfaits. Veuillez les installer avant de continuer." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "   ✅ Tous les prérequis sont satisfaits" -ForegroundColor Green
    return $true
}

function Show-ConfigurationSummary {
    param([object]$Config)
    
    Write-Host "`n📊 Résumé de la configuration:" -ForegroundColor Yellow
    Write-Host "   Projet: $($Config.ProjectName)" -ForegroundColor White
    Write-Host "   Organisation: $($Config.OrganizationUrl)" -ForegroundColor White
    Write-Host "   Subscription Azure: $($Config.AzureSubscriptionId)" -ForegroundColor White
    Write-Host "   Groupe de ressources: $($Config.ResourceGroupName)" -ForegroundColor White
    Write-Host "   Région: $($Config.Location)" -ForegroundColor White
    Write-Host "   Application web: $($Config.WebAppName)" -ForegroundColor White
    
    $targetEnv = $Config.Environments | Where-Object { $_.name -eq $Environment }
    if ($targetEnv) {
        Write-Host "`n🎯 Environnement cible ($Environment):" -ForegroundColor Yellow
        Write-Host "   SKU App Service: $($targetEnv.appServiceSku)" -ForegroundColor White
        Write-Host "   Monitoring: $(if ($targetEnv.monitoring.enabled) { 'Activé' } else { 'Désactivé' })" -ForegroundColor White
        Write-Host "   Slots de déploiement: $(if ($targetEnv.deploymentSlots) { 'Activés' } else { 'Désactivés' })" -ForegroundColor White
    }
}

function Confirm-DemoExecution {
    if (-not $Interactive) {
        return $true
    }
    
    Write-Host "`n⚠️ Attention: Cette démonstration va créer des ressources Azure et Azure DevOps." -ForegroundColor Yellow
    
    if (-not $DryRun) {
        Write-Host "   Des coûts Azure peuvent être engagés." -ForegroundColor Red
    }
    else {
        Write-Host "   Mode DryRun: Aucune ressource ne sera créée." -ForegroundColor Green
    }
    
    $confirmation = Read-Host "`nVoulez-vous continuer ? (O/N)"
    return $confirmation -match '^[OoYy]'
}

function Execute-DemoSteps {
    param([object]$Config)
    
    Write-Host "`n🚀 Démarrage de l'orchestration..." -ForegroundColor Cyan
    
    try {
        # Lancement du déploiement orchestré
        $deploymentResult = Start-CompleteDeployment -ConfigPath $ConfigFile -TargetEnvironment $Environment -SkipInfrastructure:$SkipInfrastructure -DryRun:$DryRun
        
        $script:DemoResults = $deploymentResult
        
        Write-Host "`n🎉 Orchestration terminée avec succès!" -ForegroundColor Green
        return $deploymentResult
    }
    catch {
        Write-Host "`n💥 Erreur lors de l'orchestration:" -ForegroundColor Red
        Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
        
        if ($Interactive) {
            $retry = Read-Host "`nVoulez-vous réessayer ? (O/N)"
            if ($retry -match '^[OoYy]') {
                return Execute-DemoSteps -Config $Config
            }
        }
        
        throw
    }
}

function Show-DemoResults {
    param([object]$Results)
    
    $duration = (Get-Date) - $script:DemoStartTime
    
    Write-Host "`n" + "="*80 -ForegroundColor Cyan
    Write-Host "🏁 RÉSULTATS DE LA DÉMONSTRATION" -ForegroundColor Cyan
    Write-Host "="*80 -ForegroundColor Cyan
    
    Write-Host "`n⏱️ Durée totale: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor White
    Write-Host "🎯 Statut: $($Results.Status)" -ForegroundColor $(if ($Results.Status -eq "Success") { "Green" } else { "Yellow" })
    Write-Host "🆔 ID d'exécution: $($Results.ExecutionId)" -ForegroundColor White
    
    if ($Results.Urls) {
        Write-Host "`n🔗 Liens utiles:" -ForegroundColor Yellow
        Write-Host "   Application: $($Results.Urls.Application)" -ForegroundColor Blue
        Write-Host "   Azure Portal: $($Results.Urls.AzurePortal)" -ForegroundColor Blue
        Write-Host "   Azure DevOps: $($Results.Urls.AzureDevOps)" -ForegroundColor Blue
    }
    
    if ($Results.Steps) {
        Write-Host "`n📋 Détail des étapes:" -ForegroundColor Yellow
        foreach ($step in $Results.Steps) {
            $statusIcon = switch ($step.Status) {
                "Success" { "✅" }
                "Failed" { "❌" }
                "Warning" { "⚠️" }
                default { "🔄" }
            }
            
            $stepDuration = if ($step.Duration) { $step.Duration.ToString('mm\:ss') } else { "N/A" }
            Write-Host "   $statusIcon $($step.Name) ($stepDuration)" -ForegroundColor White
            
            if ($step.Error) {
                Write-Host "      Erreur: $($step.Error)" -ForegroundColor Red
            }
        }
    }
    
    # Recommandations post-déploiement
    Write-Host "`n💡 Prochaines étapes recommandées:" -ForegroundColor Yellow
    Write-Host "   1. Tester l'application déployée" -ForegroundColor White
    Write-Host "   2. Configurer les pipelines CI/CD" -ForegroundColor White
    Write-Host "   3. Mettre en place la surveillance" -ForegroundColor White
    Write-Host "   4. Documenter l'architecture" -ForegroundColor White
    
    if (-not $DryRun) {
        Write-Host "`n⚠️ N'oubliez pas de nettoyer les ressources de test pour éviter les coûts inutiles!" -ForegroundColor Yellow
    }
}

function Generate-DemoReport {
    param([object]$Results, [object]$Config)
    
    if (-not $GenerateReport) {
        return
    }
    
    Write-Host "`n📄 Génération du rapport de démonstration..." -ForegroundColor Yellow
    
    $reportPath = "demo-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
    
    $reportHtml = @"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rapport de Démonstration - Orchestrateur Azure DevOps</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        .status-success { color: #28a745; }
        .status-warning { color: #ffc107; }
        .status-failed { color: #dc3545; }
        .step-card { margin-bottom: 15px; }
    </style>
</head>
<body>
    <div class="container mt-4">
        <h1 class="text-center mb-4">🚀 Rapport de Démonstration</h1>
        <h2 class="text-center text-muted mb-5">Orchestrateur d'Automatisation Azure DevOps</h2>
        
        <div class="row">
            <div class="col-md-6">
                <div class="card">
                    <div class="card-header bg-primary text-white">
                        <h5>Informations Générales</h5>
                    </div>
                    <div class="card-body">
                        <p><strong>Projet:</strong> $($Config.ProjectName)</p>
                        <p><strong>Environnement:</strong> $Environment</p>
                        <p><strong>Durée:</strong> $($Results.Duration.ToString('hh\:mm\:ss'))</p>
                        <p><strong>Statut:</strong> <span class="status-$(($Results.Status).ToLower())">$($Results.Status)</span></p>
                        <p><strong>Mode:</strong> $(if ($DryRun) { 'DryRun (Simulation)' } else { 'Production' })</p>
                    </div>
                </div>
            </div>
            
            <div class="col-md-6">
                <div class="card">
                    <div class="card-header bg-success text-white">
                        <h5>Liens Utiles</h5>
                    </div>
                    <div class="card-body">
                        $(if ($Results.Urls.Application) { "<p><a href='$($Results.Urls.Application)' target='_blank'>🌐 Application</a></p>" })
                        $(if ($Results.Urls.AzurePortal) { "<p><a href='$($Results.Urls.AzurePortal)' target='_blank'>☁️ Azure Portal</a></p>" })
                        $(if ($Results.Urls.AzureDevOps) { "<p><a href='$($Results.Urls.AzureDevOps)' target='_blank'>🔧 Azure DevOps</a></p>" })
                    </div>
                </div>
            </div>
        </div>
        
        <div class="row mt-4">
            <div class="col-12">
                <div class="card">
                    <div class="card-header bg-info text-white">
                        <h5>Étapes d'Exécution</h5>
                    </div>
                    <div class="card-body">
                        $(foreach ($step in $Results.Steps) {
                            $statusClass = switch ($step.Status) {
                                "Success" { "success" }
                                "Failed" { "danger" }
                                "Warning" { "warning" }
                                default { "secondary" }
                            }
                            
                            $statusIcon = switch ($step.Status) {
                                "Success" { "✅" }
                                "Failed" { "❌" }
                                "Warning" { "⚠️" }
                                default { "🔄" }
                            }
                            
                            $stepDuration = if ($step.Duration) { $step.Duration.ToString('mm\:ss') } else { "N/A" }
                            
                            "<div class='card step-card border-$statusClass'>"
                            "<div class='card-body'>"
                            "<h6 class='card-title'>$statusIcon $($step.Name)</h6>"
                            "<p class='card-text'>"
                            "<small class='text-muted'>Durée: $stepDuration</small><br>"
                            "$(if ($step.Description) { $step.Description })"
                            "$(if ($step.Error) { "<br><span class='text-danger'>Erreur: $($step.Error)</span>" })"
                            "</p>"
                            "</div>"
                            "</div>"
                        })
                    </div>
                </div>
            </div>
        </div>
        
        <div class="row mt-4">
            <div class="col-12 text-center">
                <p class="text-muted">Rapport généré le $(Get-Date -Format 'dd/MM/yyyy à HH:mm:ss')</p>
            </div>
        </div>
    </div>
</body>
</html>
"@
    
    $reportHtml | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "   ✅ Rapport généré: $reportPath" -ForegroundColor Green
    
    $openReport = Read-Host "Voulez-vous ouvrir le rapport ? (O/N)"
    if ($openReport -match '^[OoYy]') {
        Start-Process $reportPath
    }
}

# Exécution principale de la démonstration
try {
    Show-DemoHeader
    
    # Vérification des prérequis
    Test-DemoPrerequisites
    
    # Validation de la configuration
    Write-Host "`n🔧 Validation de la configuration..." -ForegroundColor Yellow
    $config = Initialize-Orchestrator -ConfigPath $ConfigFile -ValidateOnly
    
    Show-ConfigurationSummary -Config $config
    
    # Confirmation d'exécution
    if (-not (Confirm-DemoExecution)) {
        Write-Host "`n❌ Démonstration annulée par l'utilisateur." -ForegroundColor Yellow
        exit 0
    }
    
    # Exécution de la démonstration
    $results = Execute-DemoSteps -Config $config
    
    # Affichage des résultats
    Show-DemoResults -Results $results
    
    # Génération du rapport
    Generate-DemoReport -Results $results -Config $config
    
    Write-Host "`n🎉 Démonstration terminée avec succès!" -ForegroundColor Green
}
catch {
    Write-Host "`n💥 Erreur lors de la démonstration:" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nConsultez les logs pour plus de détails." -ForegroundColor Yellow
    exit 1
}
```

## Questions de réflexion

1. **Architecture** : Comment pourriez-vous améliorer l'architecture de l'orchestrateur pour le rendre plus modulaire ?

2. **Résilience** : Quels mécanismes de récupération d'erreur pourriez-vous ajouter ?

3. **Performance** : Comment optimiser les performances pour de gros déploiements ?

4. **Sécurité** : Quelles améliorations de sécurité pourriez-vous implémenter ?

5. **Monitoring** : Comment améliorer le monitoring et l'observabilité ?

## Défis supplémentaires

### Défi 1 : Multi-environnement
Étendez l'orchestrateur pour gérer des déploiements simultanés sur plusieurs environnements.

### Défi 2 : Rollback automatique
Implémentez un système de rollback automatique en cas d'échec de validation.

### Défi 3 : Intégration continue
Intégrez l'orchestrateur dans un pipeline CI/CD pour des déploiements automatiques.

## Ressources complémentaires

- [Azure DevOps REST API](https://docs.microsoft.com/en-us/rest/api/azure/devops/)
- [Azure CLI Reference](https://docs.microsoft.com/en-us/cli/azure/)
- [PowerShell Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/strongly-encouraged-development-guidelines)
- [Infrastructure as Code](https://docs.microsoft.com/en-us/azure/devops/learn/what-is-infrastructure-as-code)

