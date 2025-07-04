# Exercice 3 : Automatisation avec l'API REST Azure DevOps

## Objectifs
- Maîtriser l'utilisation de l'API REST Azure DevOps
- Créer des scripts d'intégration personnalisés
- Automatiser des tâches complexes non couvertes par les outils standard
- Implémenter des workflows personnalisés avec l'API REST

## Prérequis
- Connaissance de base des API REST et du format JSON
- PowerShell 7.0 ou supérieur (ou Python 3.8+)
- Personal Access Token (PAT) Azure DevOps avec les permissions appropriées
- Accès à une organisation Azure DevOps
- Outil de test d'API (Postman, curl, ou équivalent)

## Durée estimée
75 minutes

## Contexte
Votre équipe a besoin d'automatiser des processus métier spécifiques qui ne sont pas entièrement couverts par Azure CLI ou PowerShell. Vous devez créer des intégrations personnalisées utilisant directement l'API REST Azure DevOps pour :
- Synchroniser les work items avec un système externe
- Générer des rapports personnalisés
- Automatiser la gestion des releases avec des règles métier complexes

## Étape 1 : Configuration et authentification (15 minutes)

### 1.1 Création d'un module d'authentification
Créez un fichier `AzureDevOpsAPI.psm1` pour gérer l'authentification et les appels API :

```powershell
<#
.SYNOPSIS
    Module PowerShell pour l'API REST Azure DevOps
.DESCRIPTION
    Ce module fournit des fonctions pour interagir avec l'API REST Azure DevOps
.AUTHOR
    Votre nom
.VERSION
    1.0.0
#>

# Variables globales du module
$script:ApiVersion = "7.0"
$script:BaseHeaders = @{}
$script:OrganizationUrl = ""

#region Authentification et configuration

function Set-AzureDevOpsConnection {
    <#
    .SYNOPSIS
        Configure la connexion à l'API Azure DevOps
    .PARAMETER OrganizationUrl
        URL de l'organisation Azure DevOps (ex: https://dev.azure.com/monorg)
    .PARAMETER PersonalAccessToken
        Personal Access Token pour l'authentification
    .PARAMETER ApiVersion
        Version de l'API à utiliser (par défaut: 7.0)
    .EXAMPLE
        Set-AzureDevOpsConnection -OrganizationUrl "https://dev.azure.com/monorg" -PersonalAccessToken $pat
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OrganizationUrl,
        
        [Parameter(Mandatory)]
        [SecureString]$PersonalAccessToken,
        
        [string]$ApiVersion = "7.0"
    )
    
    try {
        # Convertir le PAT en base64 pour l'authentification Basic
        $patPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PersonalAccessToken)
        )
        
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$patPlainText"))
        
        # Configuration des variables globales
        $script:OrganizationUrl = $OrganizationUrl.TrimEnd('/')
        $script:ApiVersion = $ApiVersion
        $script:BaseHeaders = @{
            'Authorization' = "Basic $base64AuthInfo"
            'Content-Type' = 'application/json'
            'Accept' = 'application/json'
        }
        
        # Test de la connexion
        $testUrl = "$script:OrganizationUrl/_apis/projects?api-version=$script:ApiVersion"
        $response = Invoke-RestMethod -Uri $testUrl -Headers $script:BaseHeaders -Method Get
        
        Write-Host "✓ Connexion établie avec succès à $OrganizationUrl" -ForegroundColor Green
        Write-Host "✓ Nombre de projets accessibles: $($response.count)" -ForegroundColor Green
        
        return $true
    }
    catch {
        Write-Error "Erreur lors de la configuration de la connexion: $($_.Exception.Message)"
        return $false
    }
}

function Test-AzureDevOpsConnection {
    <#
    .SYNOPSIS
        Teste la connexion à l'API Azure DevOps
    #>
    try {
        if (-not $script:OrganizationUrl -or -not $script:BaseHeaders) {
            Write-Warning "Connexion non configurée. Utilisez Set-AzureDevOpsConnection d'abord."
            return $false
        }
        
        $testUrl = "$script:OrganizationUrl/_apis/connectionData?api-version=$script:ApiVersion"
        $response = Invoke-RestMethod -Uri $testUrl -Headers $script:BaseHeaders -Method Get
        
        Write-Host "✓ Connexion active - Utilisateur: $($response.authenticatedUser.displayName)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Erreur de connexion: $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region Fonctions utilitaires pour les appels API

function Invoke-AzureDevOpsAPI {
    <#
    .SYNOPSIS
        Fonction générique pour les appels à l'API Azure DevOps
    .PARAMETER Endpoint
        Endpoint de l'API (ex: "_apis/projects")
    .PARAMETER Method
        Méthode HTTP (GET, POST, PUT, DELETE, PATCH)
    .PARAMETER Body
        Corps de la requête (pour POST, PUT, PATCH)
    .PARAMETER Project
        Nom du projet (optionnel)
    .PARAMETER ApiVersion
        Version de l'API (utilise la version globale par défaut)
    .PARAMETER AdditionalHeaders
        En-têtes supplémentaires
    .EXAMPLE
        Invoke-AzureDevOpsAPI -Endpoint "_apis/projects" -Method GET
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Endpoint,
        
        [ValidateSet("GET", "POST", "PUT", "DELETE", "PATCH")]
        [string]$Method = "GET",
        
        [object]$Body,
        
        [string]$Project,
        
        [string]$ApiVersion,
        
        [hashtable]$AdditionalHeaders = @{}
    )
    
    try {
        # Construction de l'URL
        $apiVersion = $ApiVersion ?? $script:ApiVersion
        $baseUrl = $script:OrganizationUrl
        
        if ($Project) {
            $url = "$baseUrl/$Project/$Endpoint"
        }
        else {
            $url = "$baseUrl/$Endpoint"
        }
        
        # Ajouter la version de l'API
        $separator = if ($url.Contains('?')) { '&' } else { '?' }
        $url += "$separator" + "api-version=$apiVersion"
        
        # Préparer les en-têtes
        $headers = $script:BaseHeaders.Clone()
        foreach ($header in $AdditionalHeaders.GetEnumerator()) {
            $headers[$header.Key] = $header.Value
        }
        
        # Préparer les paramètres de la requête
        $requestParams = @{
            Uri = $url
            Method = $Method
            Headers = $headers
        }
        
        # Ajouter le corps si nécessaire
        if ($Body -and $Method -in @("POST", "PUT", "PATCH")) {
            if ($Body -is [string]) {
                $requestParams.Body = $Body
            }
            else {
                $requestParams.Body = $Body | ConvertTo-Json -Depth 10
            }
        }
        
        # Logging de la requête
        Write-Verbose "[$Method] $url"
        if ($Body) {
            Write-Verbose "Body: $($requestParams.Body)"
        }
        
        # Exécution de la requête
        $response = Invoke-RestMethod @requestParams
        
        return $response
    }
    catch {
        $errorDetails = $_.Exception.Message
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode
            $statusDescription = $_.Exception.Response.StatusDescription
            $errorDetails += " (HTTP $statusCode - $statusDescription)"
        }
        
        Write-Error "Erreur lors de l'appel API: $errorDetails"
        throw
    }
}

function Get-AzureDevOpsProjects {
    <#
    .SYNOPSIS
        Récupère la liste des projets
    .PARAMETER IncludeCapabilities
        Inclure les capacités des projets
    .PARAMETER StateFilter
        Filtrer par état (WellFormed, CreatePending, Deleting, New, All)
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludeCapabilities,
        
        [ValidateSet("WellFormed", "CreatePending", "Deleting", "New", "All")]
        [string]$StateFilter = "WellFormed"
    )
    
    $endpoint = "_apis/projects"
    $queryParams = @()
    
    if ($IncludeCapabilities) {
        $queryParams += "includeCapabilities=true"
    }
    
    if ($StateFilter -ne "All") {
        $queryParams += "stateFilter=$StateFilter"
    }
    
    if ($queryParams.Count -gt 0) {
        $endpoint += "?" + ($queryParams -join "&")
    }
    
    $response = Invoke-AzureDevOpsAPI -Endpoint $endpoint -Method GET
    return $response.value
}

#endregion

# Export des fonctions publiques
Export-ModuleMember -Function @(
    'Set-AzureDevOpsConnection',
    'Test-AzureDevOpsConnection',
    'Invoke-AzureDevOpsAPI',
    'Get-AzureDevOpsProjects'
)
```

### 1.2 Test de l'authentification
Créez un script de test `Test-APIConnection.ps1` :

```powershell
# Import du module
Import-Module .\AzureDevOpsAPI.psm1 -Force

# Configuration de la connexion
$organizationUrl = Read-Host "Entrez l'URL de votre organisation Azure DevOps"
$pat = Read-Host "Entrez votre Personal Access Token" -AsSecureString

# Test de connexion
if (Set-AzureDevOpsConnection -OrganizationUrl $organizationUrl -PersonalAccessToken $pat) {
    Write-Host "`n=== Test de récupération des projets ===" -ForegroundColor Cyan
    
    $projects = Get-AzureDevOpsProjects
    
    Write-Host "Projets trouvés: $($projects.Count)" -ForegroundColor Green
    foreach ($project in $projects) {
        Write-Host "  - $($project.name) (ID: $($project.id))" -ForegroundColor White
    }
}
```

## Étape 2 : Gestion des Work Items (20 minutes)

### 2.1 Fonctions pour les Work Items
Ajoutez ces fonctions au module `AzureDevOpsAPI.psm1` :

```powershell
#region Gestion des Work Items

function Get-WorkItems {
    <#
    .SYNOPSIS
        Récupère les work items selon des critères
    .PARAMETER Project
        Nom du projet
    .PARAMETER WorkItemType
        Type de work item (Bug, Task, User Story, etc.)
    .PARAMETER State
        État du work item
    .PARAMETER AssignedTo
        Assigné à (nom d'utilisateur ou email)
    .PARAMETER MaxResults
        Nombre maximum de résultats
    .EXAMPLE
        Get-WorkItems -Project "MonProjet" -WorkItemType "Bug" -State "Active"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Project,
        
        [string]$WorkItemType,
        [string]$State,
        [string]$AssignedTo,
        [int]$MaxResults = 100
    )
    
    # Construction de la requête WIQL (Work Item Query Language)
    $wiqlQuery = "SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo], [System.CreatedDate] FROM WorkItems WHERE [System.TeamProject] = '$Project'"
    
    if ($WorkItemType) {
        $wiqlQuery += " AND [System.WorkItemType] = '$WorkItemType'"
    }
    
    if ($State) {
        $wiqlQuery += " AND [System.State] = '$State'"
    }
    
    if ($AssignedTo) {
        $wiqlQuery += " AND [System.AssignedTo] = '$AssignedTo'"
    }
    
    $wiqlQuery += " ORDER BY [System.CreatedDate] DESC"
    
    # Corps de la requête WIQL
    $wiqlBody = @{
        query = $wiqlQuery
    } | ConvertTo-Json
    
    try {
        # Exécution de la requête WIQL
        $queryResult = Invoke-AzureDevOpsAPI -Endpoint "_apis/wit/wiql" -Method POST -Body $wiqlBody -Project $Project
        
        if ($queryResult.workItems.Count -eq 0) {
            Write-Host "Aucun work item trouvé avec les critères spécifiés" -ForegroundColor Yellow
            return @()
        }
        
        # Récupération des détails des work items
        $workItemIds = $queryResult.workItems | Select-Object -First $MaxResults | ForEach-Object { $_.id }
        $idsString = $workItemIds -join ","
        
        $workItemsDetails = Invoke-AzureDevOpsAPI -Endpoint "_apis/wit/workitems?ids=$idsString&`$expand=all" -Method GET -Project $Project
        
        return $workItemsDetails.value
    }
    catch {
        Write-Error "Erreur lors de la récupération des work items: $($_.Exception.Message)"
        throw
    }
}

function New-WorkItem {
    <#
    .SYNOPSIS
        Crée un nouveau work item
    .PARAMETER Project
        Nom du projet
    .PARAMETER WorkItemType
        Type de work item
    .PARAMETER Title
        Titre du work item
    .PARAMETER Description
        Description du work item
    .PARAMETER AssignedTo
        Personne assignée
    .PARAMETER Priority
        Priorité (1-4)
    .PARAMETER Tags
        Tags séparés par des points-virgules
    .EXAMPLE
        New-WorkItem -Project "MonProjet" -WorkItemType "Bug" -Title "Erreur de connexion" -Description "L'application ne se connecte pas à la base de données"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Project,
        
        [Parameter(Mandatory)]
        [string]$WorkItemType,
        
        [Parameter(Mandatory)]
        [string]$Title,
        
        [string]$Description,
        [string]$AssignedTo,
        [ValidateRange(1, 4)]
        [int]$Priority,
        [string]$Tags
    )
    
    # Construction du corps de la requête avec les opérations JSON Patch
    $patchOperations = @()
    
    # Titre (obligatoire)
    $patchOperations += @{
        op = "add"
        path = "/fields/System.Title"
        value = $Title
    }
    
    # Description
    if ($Description) {
        $patchOperations += @{
            op = "add"
            path = "/fields/System.Description"
            value = $Description
        }
    }
    
    # Assigné à
    if ($AssignedTo) {
        $patchOperations += @{
            op = "add"
            path = "/fields/System.AssignedTo"
            value = $AssignedTo
        }
    }
    
    # Priorité
    if ($Priority) {
        $patchOperations += @{
            op = "add"
            path = "/fields/Microsoft.VSTS.Common.Priority"
            value = $Priority
        }
    }
    
    # Tags
    if ($Tags) {
        $patchOperations += @{
            op = "add"
            path = "/fields/System.Tags"
            value = $Tags
        }
    }
    
    $body = $patchOperations | ConvertTo-Json -Depth 3
    
    try {
        $additionalHeaders = @{
            'Content-Type' = 'application/json-patch+json'
        }
        
        $workItem = Invoke-AzureDevOpsAPI -Endpoint "_apis/wit/workitems/`$$WorkItemType" -Method POST -Body $body -Project $Project -AdditionalHeaders $additionalHeaders
        
        Write-Host "✓ Work item créé avec succès (ID: $($workItem.id))" -ForegroundColor Green
        return $workItem
    }
    catch {
        Write-Error "Erreur lors de la création du work item: $($_.Exception.Message)"
        throw
    }
}

function Update-WorkItem {
    <#
    .SYNOPSIS
        Met à jour un work item existant
    .PARAMETER Project
        Nom du projet
    .PARAMETER WorkItemId
        ID du work item à mettre à jour
    .PARAMETER Fields
        Hashtable des champs à mettre à jour
    .EXAMPLE
        Update-WorkItem -Project "MonProjet" -WorkItemId 123 -Fields @{"System.State" = "Resolved"; "System.AssignedTo" = "user@domain.com"}
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Project,
        
        [Parameter(Mandatory)]
        [int]$WorkItemId,
        
        [Parameter(Mandatory)]
        [hashtable]$Fields
    )
    
    # Construction des opérations de mise à jour
    $patchOperations = @()
    
    foreach ($field in $Fields.GetEnumerator()) {
        $patchOperations += @{
            op = "replace"
            path = "/fields/$($field.Key)"
            value = $field.Value
        }
    }
    
    $body = $patchOperations | ConvertTo-Json -Depth 3
    
    try {
        $additionalHeaders = @{
            'Content-Type' = 'application/json-patch+json'
        }
        
        $workItem = Invoke-AzureDevOpsAPI -Endpoint "_apis/wit/workitems/$WorkItemId" -Method PATCH -Body $body -Project $Project -AdditionalHeaders $additionalHeaders
        
        Write-Host "✓ Work item $WorkItemId mis à jour avec succès" -ForegroundColor Green
        return $workItem
    }
    catch {
        Write-Error "Erreur lors de la mise à jour du work item: $($_.Exception.Message)"
        throw
    }
}

function Add-WorkItemComment {
    <#
    .SYNOPSIS
        Ajoute un commentaire à un work item
    .PARAMETER Project
        Nom du projet
    .PARAMETER WorkItemId
        ID du work item
    .PARAMETER Comment
        Texte du commentaire
    .EXAMPLE
        Add-WorkItemComment -Project "MonProjet" -WorkItemId 123 -Comment "Problème résolu après redémarrage du service"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Project,
        
        [Parameter(Mandatory)]
        [int]$WorkItemId,
        
        [Parameter(Mandatory)]
        [string]$Comment
    )
    
    $body = @{
        text = $Comment
    } | ConvertTo-Json
    
    try {
        $comment = Invoke-AzureDevOpsAPI -Endpoint "_apis/wit/workItems/$WorkItemId/comments" -Method POST -Body $body -Project $Project
        
        Write-Host "✓ Commentaire ajouté au work item $WorkItemId" -ForegroundColor Green
        return $comment
    }
    catch {
        Write-Error "Erreur lors de l'ajout du commentaire: $($_.Exception.Message)"
        throw
    }
}

#endregion
```

### 2.2 Script de démonstration des Work Items
Créez un script `Demo-WorkItems.ps1` :

```powershell
# Import du module
Import-Module .\AzureDevOpsAPI.psm1 -Force

# Configuration (à adapter selon votre environnement)
$projectName = "MonProjet"

Write-Host "=== Démonstration de la gestion des Work Items ===" -ForegroundColor Cyan

try {
    # 1. Récupération des bugs actifs
    Write-Host "`n1. Récupération des bugs actifs..." -ForegroundColor Yellow
    $activeBugs = Get-WorkItems -Project $projectName -WorkItemType "Bug" -State "Active" -MaxResults 10
    
    Write-Host "Bugs actifs trouvés: $($activeBugs.Count)" -ForegroundColor Green
    foreach ($bug in $activeBugs) {
        Write-Host "  - [$($bug.id)] $($bug.fields.'System.Title')" -ForegroundColor White
    }
    
    # 2. Création d'un nouveau bug
    Write-Host "`n2. Création d'un nouveau bug de test..." -ForegroundColor Yellow
    $newBug = New-WorkItem -Project $projectName -WorkItemType "Bug" -Title "Bug de test créé via API" -Description "Ce bug a été créé automatiquement pour tester l'API REST" -Priority 2 -Tags "test;api;automatisation"
    
    # 3. Mise à jour du bug créé
    Write-Host "`n3. Mise à jour du bug créé..." -ForegroundColor Yellow
    $updateFields = @{
        "System.State" = "Active"
        "Microsoft.VSTS.Common.Severity" = "3 - Medium"
        "System.Description" = "Description mise à jour via l'API REST Azure DevOps"
    }
    
    Update-WorkItem -Project $projectName -WorkItemId $newBug.id -Fields $updateFields
    
    # 4. Ajout d'un commentaire
    Write-Host "`n4. Ajout d'un commentaire..." -ForegroundColor Yellow
    Add-WorkItemComment -Project $projectName -WorkItemId $newBug.id -Comment "Commentaire ajouté automatiquement via l'API REST. Timestamp: $(Get-Date)"
    
    # 5. Récupération des détails du work item créé
    Write-Host "`n5. Vérification du work item créé..." -ForegroundColor Yellow
    $createdWorkItem = Invoke-AzureDevOpsAPI -Endpoint "_apis/wit/workitems/$($newBug.id)?`$expand=all" -Method GET -Project $projectName
    
    Write-Host "Work item créé et mis à jour:" -ForegroundColor Green
    Write-Host "  ID: $($createdWorkItem.id)" -ForegroundColor White
    Write-Host "  Titre: $($createdWorkItem.fields.'System.Title')" -ForegroundColor White
    Write-Host "  État: $($createdWorkItem.fields.'System.State')" -ForegroundColor White
    Write-Host "  Priorité: $($createdWorkItem.fields.'Microsoft.VSTS.Common.Priority')" -ForegroundColor White
    Write-Host "  URL: $($createdWorkItem._links.html.href)" -ForegroundColor White
    
    Write-Host "`n✓ Démonstration terminée avec succès!" -ForegroundColor Green
}
catch {
    Write-Error "Erreur lors de la démonstration: $($_.Exception.Message)"
}
```

## Étape 3 : Gestion des Builds et Releases (20 minutes)

### 3.1 Fonctions pour les Builds
Ajoutez ces fonctions au module :

```powershell
#region Gestion des Builds

function Get-BuildDefinitions {
    <#
    .SYNOPSIS
        Récupère les définitions de build
    .PARAMETER Project
        Nom du projet
    .PARAMETER Name
        Nom de la définition (filtre)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Project,
        
        [string]$Name
    )
    
    $endpoint = "_apis/build/definitions"
    
    if ($Name) {
        $endpoint += "?name=$Name"
    }
    
    $response = Invoke-AzureDevOpsAPI -Endpoint $endpoint -Method GET -Project $Project
    return $response.value
}

function Get-Builds {
    <#
    .SYNOPSIS
        Récupère les builds
    .PARAMETER Project
        Nom du projet
    .PARAMETER DefinitionId
        ID de la définition de build
    .PARAMETER Status
        Statut du build (completed, inProgress, notStarted)
    .PARAMETER Result
        Résultat du build (succeeded, failed, canceled, partiallySucceeded)
    .PARAMETER MaxResults
        Nombre maximum de résultats
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Project,
        
        [int]$DefinitionId,
        [string]$Status,
        [string]$Result,
        [int]$MaxResults = 50
    )
    
    $queryParams = @()
    
    if ($DefinitionId) {
        $queryParams += "definitions=$DefinitionId"
    }
    
    if ($Status) {
        $queryParams += "statusFilter=$Status"
    }
    
    if ($Result) {
        $queryParams += "resultFilter=$Result"
    }
    
    $queryParams += "`$top=$MaxResults"
    
    $endpoint = "_apis/build/builds"
    if ($queryParams.Count -gt 0) {
        $endpoint += "?" + ($queryParams -join "&")
    }
    
    $response = Invoke-AzureDevOpsAPI -Endpoint $endpoint -Method GET -Project $Project
    return $response.value
}

function Start-Build {
    <#
    .SYNOPSIS
        Démarre un nouveau build
    .PARAMETER Project
        Nom du projet
    .PARAMETER DefinitionId
        ID de la définition de build
    .PARAMETER SourceBranch
        Branche source (ex: refs/heads/main)
    .PARAMETER Parameters
        Paramètres du build (hashtable)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Project,
        
        [Parameter(Mandatory)]
        [int]$DefinitionId,
        
        [string]$SourceBranch = "refs/heads/main",
        
        [hashtable]$Parameters = @{}
    )
    
    $buildRequest = @{
        definition = @{
            id = $DefinitionId
        }
        sourceBranch = $SourceBranch
    }
    
    if ($Parameters.Count -gt 0) {
        $buildRequest.parameters = ($Parameters | ConvertTo-Json -Compress)
    }
    
    $body = $buildRequest | ConvertTo-Json -Depth 3
    
    try {
        $build = Invoke-AzureDevOpsAPI -Endpoint "_apis/build/builds" -Method POST -Body $body -Project $Project
        
        Write-Host "✓ Build démarré avec succès (ID: $($build.id))" -ForegroundColor Green
        Write-Host "  URL: $($build._links.web.href)" -ForegroundColor White
        
        return $build
    }
    catch {
        Write-Error "Erreur lors du démarrage du build: $($_.Exception.Message)"
        throw
    }
}

function Wait-BuildCompletion {
    <#
    .SYNOPSIS
        Attend la fin d'un build
    .PARAMETER Project
        Nom du projet
    .PARAMETER BuildId
        ID du build
    .PARAMETER TimeoutMinutes
        Timeout en minutes
    .PARAMETER PollingIntervalSeconds
        Intervalle de polling en secondes
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Project,
        
        [Parameter(Mandatory)]
        [int]$BuildId,
        
        [int]$TimeoutMinutes = 30,
        [int]$PollingIntervalSeconds = 30
    )
    
    $startTime = Get-Date
    $timeoutTime = $startTime.AddMinutes($TimeoutMinutes)
    
    Write-Host "Attente de la fin du build $BuildId..." -ForegroundColor Yellow
    
    do {
        try {
            $build = Invoke-AzureDevOpsAPI -Endpoint "_apis/build/builds/$BuildId" -Method GET -Project $Project
            
            $status = $build.status
            $result = $build.result
            
            Write-Host "  Statut: $status $(if ($result) { "- Résultat: $result" })" -ForegroundColor Cyan
            
            if ($status -eq "completed") {
                $duration = (Get-Date) - $startTime
                Write-Host "✓ Build terminé en $($duration.ToString('mm\:ss'))" -ForegroundColor Green
                Write-Host "  Résultat final: $result" -ForegroundColor $(if ($result -eq "succeeded") { "Green" } else { "Red" })
                return $build
            }
            
            if ((Get-Date) -gt $timeoutTime) {
                Write-Warning "Timeout atteint ($TimeoutMinutes minutes)"
                return $build
            }
            
            Start-Sleep -Seconds $PollingIntervalSeconds
        }
        catch {
            Write-Error "Erreur lors de la vérification du build: $($_.Exception.Message)"
            throw
        }
    } while ($true)
}

#endregion

#region Gestion des Releases

function Get-ReleaseDefinitions {
    <#
    .SYNOPSIS
        Récupère les définitions de release
    .PARAMETER Project
        Nom du projet
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Project
    )
    
    # Note: L'API des releases utilise un sous-domaine différent
    $releaseUrl = $script:OrganizationUrl -replace "dev\.azure\.com", "vsrm.dev.azure.com"
    $endpoint = "_apis/release/definitions"
    
    try {
        $url = "$releaseUrl/$Project/$endpoint" + "?api-version=$script:ApiVersion"
        $response = Invoke-RestMethod -Uri $url -Headers $script:BaseHeaders -Method GET
        
        return $response.value
    }
    catch {
        Write-Error "Erreur lors de la récupération des définitions de release: $($_.Exception.Message)"
        throw
    }
}

function Get-Releases {
    <#
    .SYNOPSIS
        Récupère les releases
    .PARAMETER Project
        Nom du projet
    .PARAMETER DefinitionId
        ID de la définition de release
    .PARAMETER MaxResults
        Nombre maximum de résultats
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Project,
        
        [int]$DefinitionId,
        [int]$MaxResults = 50
    )
    
    $releaseUrl = $script:OrganizationUrl -replace "dev\.azure\.com", "vsrm.dev.azure.com"
    $queryParams = @("`$top=$MaxResults")
    
    if ($DefinitionId) {
        $queryParams += "definitionId=$DefinitionId"
    }
    
    $endpoint = "_apis/release/releases?" + ($queryParams -join "&")
    
    try {
        $url = "$releaseUrl/$Project/$endpoint" + "&api-version=$script:ApiVersion"
        $response = Invoke-RestMethod -Uri $url -Headers $script:BaseHeaders -Method GET
        
        return $response.value
    }
    catch {
        Write-Error "Erreur lors de la récupération des releases: $($_.Exception.Message)"
        throw
    }
}

function New-Release {
    <#
    .SYNOPSIS
        Crée une nouvelle release
    .PARAMETER Project
        Nom du projet
    .PARAMETER DefinitionId
        ID de la définition de release
    .PARAMETER Description
        Description de la release
    .PARAMETER Artifacts
        Artefacts à utiliser
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Project,
        
        [Parameter(Mandatory)]
        [int]$DefinitionId,
        
        [string]$Description = "Release créée automatiquement via API",
        
        [array]$Artifacts = @()
    )
    
    $releaseRequest = @{
        definitionId = $DefinitionId
        description = $Description
        isDraft = $false
    }
    
    if ($Artifacts.Count -gt 0) {
        $releaseRequest.artifacts = $Artifacts
    }
    
    $body = $releaseRequest | ConvertTo-Json -Depth 5
    $releaseUrl = $script:OrganizationUrl -replace "dev\.azure\.com", "vsrm.dev.azure.com"
    
    try {
        $url = "$releaseUrl/$Project/_apis/release/releases" + "?api-version=$script:ApiVersion"
        $release = Invoke-RestMethod -Uri $url -Headers $script:BaseHeaders -Method POST -Body $body
        
        Write-Host "✓ Release créée avec succès (ID: $($release.id))" -ForegroundColor Green
        return $release
    }
    catch {
        Write-Error "Erreur lors de la création de la release: $($_.Exception.Message)"
        throw
    }
}

#endregion
```

### 3.2 Script de démonstration des Builds
Créez un script `Demo-Builds.ps1` :

```powershell
# Import du module
Import-Module .\AzureDevOpsAPI.psm1 -Force

$projectName = "MonProjet"

Write-Host "=== Démonstration de la gestion des Builds ===" -ForegroundColor Cyan

try {
    # 1. Récupération des définitions de build
    Write-Host "`n1. Récupération des définitions de build..." -ForegroundColor Yellow
    $buildDefinitions = Get-BuildDefinitions -Project $projectName
    
    Write-Host "Définitions de build trouvées: $($buildDefinitions.Count)" -ForegroundColor Green
    foreach ($def in $buildDefinitions | Select-Object -First 5) {
        Write-Host "  - [$($def.id)] $($def.name)" -ForegroundColor White
    }
    
    if ($buildDefinitions.Count -gt 0) {
        $selectedDefinition = $buildDefinitions[0]
        
        # 2. Récupération des builds récents
        Write-Host "`n2. Récupération des builds récents pour '$($selectedDefinition.name)'..." -ForegroundColor Yellow
        $recentBuilds = Get-Builds -Project $projectName -DefinitionId $selectedDefinition.id -MaxResults 10
        
        Write-Host "Builds récents: $($recentBuilds.Count)" -ForegroundColor Green
        foreach ($build in $recentBuilds | Select-Object -First 5) {
            $statusColor = switch ($build.result) {
                "succeeded" { "Green" }
                "failed" { "Red" }
                "canceled" { "Yellow" }
                default { "White" }
            }
            Write-Host "  - [$($build.id)] $($build.buildNumber) - $($build.status) - $($build.result)" -ForegroundColor $statusColor
        }
        
        # 3. Démarrage d'un nouveau build (optionnel)
        $startNewBuild = Read-Host "`nVoulez-vous démarrer un nouveau build pour '$($selectedDefinition.name)' ? (O/N)"
        if ($startNewBuild -match '^[OoYy]') {
            Write-Host "`n3. Démarrage d'un nouveau build..." -ForegroundColor Yellow
            
            $newBuild = Start-Build -Project $projectName -DefinitionId $selectedDefinition.id -SourceBranch "refs/heads/main"
            
            # 4. Attente de la fin du build (optionnel)
            $waitForCompletion = Read-Host "Voulez-vous attendre la fin du build ? (O/N)"
            if ($waitForCompletion -match '^[OoYy]') {
                $completedBuild = Wait-BuildCompletion -Project $projectName -BuildId $newBuild.id -TimeoutMinutes 10 -PollingIntervalSeconds 15
                
                Write-Host "`nRésultat final du build:" -ForegroundColor Green
                Write-Host "  ID: $($completedBuild.id)" -ForegroundColor White
                Write-Host "  Numéro: $($completedBuild.buildNumber)" -ForegroundColor White
                Write-Host "  Statut: $($completedBuild.status)" -ForegroundColor White
                Write-Host "  Résultat: $($completedBuild.result)" -ForegroundColor White
                Write-Host "  Durée: $($completedBuild.finishTime - $completedBuild.startTime)" -ForegroundColor White
            }
        }
    }
    
    Write-Host "`n✓ Démonstration des builds terminée!" -ForegroundColor Green
}
catch {
    Write-Error "Erreur lors de la démonstration: $($_.Exception.Message)"
}
```

## Étape 4 : Création d'un rapport personnalisé (20 minutes)

### 4.1 Script de génération de rapport
Créez un script `Generate-ProjectReport.ps1` :

```powershell
<#
.SYNOPSIS
    Génère un rapport complet sur l'état d'un projet Azure DevOps
.DESCRIPTION
    Ce script utilise l'API REST pour collecter des données sur un projet et générer un rapport HTML
.PARAMETER Project
    Nom du projet
.PARAMETER OutputPath
    Chemin de sortie pour le rapport HTML
.PARAMETER IncludeCharts
    Inclure des graphiques dans le rapport
.EXAMPLE
    .\Generate-ProjectReport.ps1 -Project "MonProjet" -OutputPath "rapport.html" -IncludeCharts
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Project,
    
    [string]$OutputPath = "rapport-$(Get-Date -Format 'yyyyMMdd-HHmmss').html",
    
    [switch]$IncludeCharts
)

# Import du module
Import-Module .\AzureDevOpsAPI.psm1 -Force

# Fonction pour générer les statistiques des work items
function Get-WorkItemStatistics {
    param([string]$ProjectName)
    
    Write-Host "Collecte des statistiques des work items..." -ForegroundColor Yellow
    
    # Requête pour tous les work items
    $wiqlQuery = @"
SELECT [System.Id], [System.WorkItemType], [System.State], [System.AssignedTo], [System.CreatedDate], [Microsoft.VSTS.Common.Priority]
FROM WorkItems 
WHERE [System.TeamProject] = '$ProjectName'
ORDER BY [System.CreatedDate] DESC
"@
    
    $wiqlBody = @{ query = $wiqlQuery } | ConvertTo-Json
    $queryResult = Invoke-AzureDevOpsAPI -Endpoint "_apis/wit/wiql" -Method POST -Body $wiqlBody -Project $ProjectName
    
    if ($queryResult.workItems.Count -eq 0) {
        return @{
            Total = 0
            ByType = @{}
            ByState = @{}
            ByPriority = @{}
        }
    }
    
    # Récupération des détails
    $workItemIds = $queryResult.workItems | ForEach-Object { $_.id }
    $idsString = $workItemIds -join ","
    $workItemsDetails = Invoke-AzureDevOpsAPI -Endpoint "_apis/wit/workitems?ids=$idsString&fields=System.WorkItemType,System.State,Microsoft.VSTS.Common.Priority" -Method GET -Project $ProjectName
    
    # Calcul des statistiques
    $stats = @{
        Total = $workItemsDetails.value.Count
        ByType = @{}
        ByState = @{}
        ByPriority = @{}
    }
    
    foreach ($wi in $workItemsDetails.value) {
        $type = $wi.fields.'System.WorkItemType'
        $state = $wi.fields.'System.State'
        $priority = $wi.fields.'Microsoft.VSTS.Common.Priority'
        
        # Par type
        if ($stats.ByType.ContainsKey($type)) {
            $stats.ByType[$type]++
        } else {
            $stats.ByType[$type] = 1
        }
        
        # Par état
        if ($stats.ByState.ContainsKey($state)) {
            $stats.ByState[$state]++
        } else {
            $stats.ByState[$state] = 1
        }
        
        # Par priorité
        if ($priority) {
            if ($stats.ByPriority.ContainsKey($priority)) {
                $stats.ByPriority[$priority]++
            } else {
                $stats.ByPriority[$priority] = 1
            }
        }
    }
    
    return $stats
}

# Fonction pour générer les statistiques des builds
function Get-BuildStatistics {
    param([string]$ProjectName)
    
    Write-Host "Collecte des statistiques des builds..." -ForegroundColor Yellow
    
    try {
        $builds = Get-Builds -Project $ProjectName -MaxResults 100
        
        $stats = @{
            Total = $builds.Count
            ByResult = @{}
            ByDefinition = @{}
            RecentBuilds = $builds | Select-Object -First 10 | ForEach-Object {
                @{
                    Id = $_.id
                    BuildNumber = $_.buildNumber
                    Definition = $_.definition.name
                    Result = $_.result
                    Status = $_.status
                    StartTime = $_.startTime
                    FinishTime = $_.finishTime
                }
            }
        }
        
        foreach ($build in $builds) {
            # Par résultat
            $result = $build.result ?? "En cours"
            if ($stats.ByResult.ContainsKey($result)) {
                $stats.ByResult[$result]++
            } else {
                $stats.ByResult[$result] = 1
            }
            
            # Par définition
            $definition = $build.definition.name
            if ($stats.ByDefinition.ContainsKey($definition)) {
                $stats.ByDefinition[$definition]++
            } else {
                $stats.ByDefinition[$definition] = 1
            }
        }
        
        return $stats
    }
    catch {
        Write-Warning "Impossible de récupérer les statistiques des builds: $($_.Exception.Message)"
        return @{
            Total = 0
            ByResult = @{}
            ByDefinition = @{}
            RecentBuilds = @()
        }
    }
}

# Fonction pour générer le HTML du rapport
function Generate-ReportHTML {
    param(
        [string]$ProjectName,
        [object]$WorkItemStats,
        [object]$BuildStats,
        [bool]$IncludeCharts
    )
    
    $chartScript = if ($IncludeCharts) {
        @"
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script>
// Graphique des work items par type
const wiTypeCtx = document.getElementById('workItemTypeChart').getContext('2d');
new Chart(wiTypeCtx, {
    type: 'doughnut',
    data: {
        labels: [$($WorkItemStats.ByType.Keys | ForEach-Object { "'$_'" } | Join-String -Separator ',')],
        datasets: [{
            data: [$($WorkItemStats.ByType.Values -join ',')],
            backgroundColor: ['#FF6384', '#36A2EB', '#FFCE56', '#4BC0C0', '#9966FF', '#FF9F40']
        }]
    },
    options: {
        responsive: true,
        plugins: {
            title: {
                display: true,
                text: 'Work Items par Type'
            }
        }
    }
});

// Graphique des builds par résultat
const buildResultCtx = document.getElementById('buildResultChart').getContext('2d');
new Chart(buildResultCtx, {
    type: 'bar',
    data: {
        labels: [$($BuildStats.ByResult.Keys | ForEach-Object { "'$_'" } | Join-String -Separator ',')],
        datasets: [{
            label: 'Nombre de builds',
            data: [$($BuildStats.ByResult.Values -join ',')],
            backgroundColor: ['#28a745', '#dc3545', '#ffc107', '#17a2b8']
        }]
    },
    options: {
        responsive: true,
        plugins: {
            title: {
                display: true,
                text: 'Builds par Résultat'
            }
        }
    }
});
</script>
"@
    } else { "" }
    
    $chartsHTML = if ($IncludeCharts) {
        @"
<div class="row">
    <div class="col-md-6">
        <canvas id="workItemTypeChart"></canvas>
    </div>
    <div class="col-md-6">
        <canvas id="buildResultChart"></canvas>
    </div>
</div>
"@
    } else { "" }
    
    return @"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rapport de Projet - $ProjectName</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        .stat-card { margin-bottom: 20px; }
        .chart-container { height: 400px; margin: 20px 0; }
        .table-responsive { margin-top: 20px; }
    </style>
</head>
<body>
    <div class="container-fluid">
        <div class="row">
            <div class="col-12">
                <h1 class="text-center mb-4">Rapport de Projet Azure DevOps</h1>
                <h2 class="text-center text-muted mb-5">$ProjectName</h2>
                <p class="text-center text-muted">Généré le $(Get-Date -Format 'dd/MM/yyyy à HH:mm:ss')</p>
            </div>
        </div>
        
        <!-- Statistiques générales -->
        <div class="row">
            <div class="col-md-6">
                <div class="card stat-card">
                    <div class="card-header bg-primary text-white">
                        <h5>Work Items</h5>
                    </div>
                    <div class="card-body">
                        <h3 class="text-primary">$($WorkItemStats.Total)</h3>
                        <p>Total des work items</p>
                        
                        <h6>Par Type:</h6>
                        <ul class="list-unstyled">
                            $($WorkItemStats.ByType.GetEnumerator() | ForEach-Object { "<li>$($_.Key): <strong>$($_.Value)</strong></li>" } | Join-String -Separator "`n                            ")
                        </ul>
                        
                        <h6>Par État:</h6>
                        <ul class="list-unstyled">
                            $($WorkItemStats.ByState.GetEnumerator() | ForEach-Object { "<li>$($_.Key): <strong>$($_.Value)</strong></li>" } | Join-String -Separator "`n                            ")
                        </ul>
                    </div>
                </div>
            </div>
            
            <div class="col-md-6">
                <div class="card stat-card">
                    <div class="card-header bg-success text-white">
                        <h5>Builds</h5>
                    </div>
                    <div class="card-body">
                        <h3 class="text-success">$($BuildStats.Total)</h3>
                        <p>Total des builds</p>
                        
                        <h6>Par Résultat:</h6>
                        <ul class="list-unstyled">
                            $($BuildStats.ByResult.GetEnumerator() | ForEach-Object { "<li>$($_.Key): <strong>$($_.Value)</strong></li>" } | Join-String -Separator "`n                            ")
                        </ul>
                        
                        <h6>Par Définition:</h6>
                        <ul class="list-unstyled">
                            $($BuildStats.ByDefinition.GetEnumerator() | ForEach-Object { "<li>$($_.Key): <strong>$($_.Value)</strong></li>" } | Join-String -Separator "`n                            ")
                        </ul>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Graphiques -->
        $chartsHTML
        
        <!-- Builds récents -->
        <div class="row">
            <div class="col-12">
                <div class="card">
                    <div class="card-header bg-info text-white">
                        <h5>Builds Récents</h5>
                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-striped">
                                <thead>
                                    <tr>
                                        <th>ID</th>
                                        <th>Numéro</th>
                                        <th>Définition</th>
                                        <th>Résultat</th>
                                        <th>Statut</th>
                                        <th>Début</th>
                                        <th>Fin</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    $($BuildStats.RecentBuilds | ForEach-Object {
                                        $resultClass = switch ($_.Result) {
                                            "succeeded" { "table-success" }
                                            "failed" { "table-danger" }
                                            "canceled" { "table-warning" }
                                            default { "" }
                                        }
                                        "<tr class='$resultClass'><td>$($_.Id)</td><td>$($_.BuildNumber)</td><td>$($_.Definition)</td><td>$($_.Result)</td><td>$($_.Status)</td><td>$($_.StartTime)</td><td>$($_.FinishTime)</td></tr>"
                                    } | Join-String -Separator "`n                                    ")
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    $chartScript
</body>
</html>
"@
}

# Exécution principale
try {
    Write-Host "=== Génération du rapport pour le projet '$Project' ===" -ForegroundColor Cyan
    
    # Vérification de la connexion
    if (-not (Test-AzureDevOpsConnection)) {
        throw "Connexion Azure DevOps requise"
    }
    
    # Collecte des données
    $workItemStats = Get-WorkItemStatistics -ProjectName $Project
    $buildStats = Get-BuildStatistics -ProjectName $Project
    
    # Génération du rapport HTML
    Write-Host "Génération du rapport HTML..." -ForegroundColor Yellow
    $reportHTML = Generate-ReportHTML -ProjectName $Project -WorkItemStats $workItemStats -BuildStats $buildStats -IncludeCharts $IncludeCharts
    
    # Sauvegarde du rapport
    $reportHTML | Out-File -FilePath $OutputPath -Encoding UTF8
    
    Write-Host "✓ Rapport généré avec succès: $OutputPath" -ForegroundColor Green
    Write-Host "  Work Items: $($workItemStats.Total)" -ForegroundColor White
    Write-Host "  Builds: $($buildStats.Total)" -ForegroundColor White
    
    # Ouverture du rapport (optionnel)
    $openReport = Read-Host "Voulez-vous ouvrir le rapport dans le navigateur ? (O/N)"
    if ($openReport -match '^[OoYy]') {
        Start-Process $OutputPath
    }
}
catch {
    Write-Error "Erreur lors de la génération du rapport: $($_.Exception.Message)"
}
```

## Questions de réflexion

1. **Performance** : Comment optimiser les appels API pour de gros volumes de données ?

2. **Sécurité** : Quelles mesures de sécurité supplémentaires pourriez-vous implémenter ?

3. **Extensibilité** : Comment rendre le module facilement extensible pour de nouvelles fonctionnalités ?

4. **Gestion d'erreurs** : Comment améliorer la robustesse face aux erreurs réseau ou API ?

## Défis supplémentaires

### Défi 1 : Synchronisation bidirectionnelle
Créez un script qui synchronise les work items entre deux projets Azure DevOps.

### Défi 2 : Webhook listener
Implémentez un service qui écoute les webhooks Azure DevOps et déclenche des actions automatiques.

### Défi 3 : Migration de données
Développez un outil de migration qui transfère des données d'un système externe vers Azure DevOps.

## Ressources complémentaires

- [Documentation API REST Azure DevOps](https://docs.microsoft.com/en-us/rest/api/azure/devops/)
- [Référence WIQL](https://docs.microsoft.com/en-us/azure/devops/boards/queries/wiql-syntax)
- [Webhooks Azure DevOps](https://docs.microsoft.com/en-us/azure/devops/service-hooks/overview)
- [Exemples d'API REST](https://github.com/Microsoft/azure-devops-dotnet-samples)

