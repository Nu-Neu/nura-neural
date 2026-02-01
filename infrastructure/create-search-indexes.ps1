<#
.SYNOPSIS
    Creates Azure AI Search indexes for Nura Neural

.DESCRIPTION
    Creates the nura-content and nura-claims indexes with vector search support.
    Requires Azure CLI and appropriate permissions.

.PARAMETER SearchServiceName
    Name of the Azure AI Search service (default: nura-search)

.PARAMETER ResourceGroup
    Resource group containing the search service (default: irdecode-prod-rg)

.EXAMPLE
    .\create-search-indexes.ps1
#>

param(
    [string]$SearchServiceName = "nura-search",
    [string]$ResourceGroup = "irdecode-prod-rg"
)

$ErrorActionPreference = "Stop"

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         NURA NEURAL - CREATE AZURE AI SEARCH INDEXES         ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Get search service endpoint and key
Write-Host "Fetching search service details..." -ForegroundColor Yellow
$searchEndpoint = "https://$SearchServiceName.search.windows.net"
$apiKey = az search admin-key show --service-name $SearchServiceName --resource-group $ResourceGroup --query primaryKey -o tsv

if (-not $apiKey) {
    Write-Host "❌ Failed to get search API key. Check your Azure login and permissions." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Search endpoint: $searchEndpoint" -ForegroundColor Green

# Common headers
$headers = @{
    "api-key"      = $apiKey
    "Content-Type" = "application/json"
}

# ===========================================
# Index: nura-content
# ===========================================
$contentIndexDefinition = @{
    name   = "nura-content"
    fields = @(
        @{ name = "id"; type = "Edm.String"; key = $true; filterable = $true }
        @{ name = "content_id"; type = "Edm.String"; filterable = $true }
        @{ name = "source_id"; type = "Edm.String"; filterable = $true }
        @{ name = "url"; type = "Edm.String"; filterable = $true }
        @{ name = "title"; type = "Edm.String"; searchable = $true; analyzer = "standard.lucene" }
        @{ name = "title_en"; type = "Edm.String"; searchable = $true; analyzer = "en.microsoft" }
        @{ name = "content_text"; type = "Edm.String"; searchable = $true }
        @{ name = "summary_en"; type = "Edm.String"; searchable = $true; analyzer = "en.microsoft" }
        @{ name = "language"; type = "Edm.String"; filterable = $true; facetable = $true }
        @{ name = "source_name"; type = "Edm.String"; filterable = $true; facetable = $true }
        @{ name = "credibility_tier"; type = "Edm.String"; filterable = $true; facetable = $true }
        @{ name = "stance"; type = "Edm.String"; filterable = $true; facetable = $true }
        @{ name = "propaganda_risk"; type = "Edm.Double"; filterable = $true; sortable = $true }
        @{ name = "factuality_score"; type = "Edm.Double"; filterable = $true; sortable = $true }
        @{ name = "published_at"; type = "Edm.DateTimeOffset"; filterable = $true; sortable = $true }
        @{ name = "ingested_at"; type = "Edm.DateTimeOffset"; filterable = $true; sortable = $true }
        @{ name = "embedding"; type = "Collection(Edm.Single)"; dimensions = 3072; vectorSearchProfile = "default-profile" }
    )
    vectorSearch = @{
        profiles   = @(
            @{ 
                name                 = "default-profile"
                algorithm            = "default-algorithm"
                vectorizer           = "default-vectorizer"
            }
        )
        algorithms = @(
            @{ 
                name           = "default-algorithm"
                kind           = "hnsw"
                hnswParameters = @{
                    m              = 4
                    efConstruction = 400
                    efSearch       = 500
                    metric         = "cosine"
                }
            }
        )
        vectorizers = @(
            @{
                name                 = "default-vectorizer"
                kind                 = "azureOpenAI"
                azureOpenAIParameters = @{
                    resourceUri    = "https://irdecode-prod-openai.openai.azure.com"
                    deploymentId   = "text-embedding-3-large"
                    modelName      = "text-embedding-3-large"
                }
            }
        )
    }
} | ConvertTo-Json -Depth 10

Write-Host "`nCreating index: nura-content..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$searchEndpoint/indexes/nura-content?api-version=2024-07-01" `
        -Method PUT -Headers $headers -Body $contentIndexDefinition
    Write-Host "✅ Index 'nura-content' created successfully" -ForegroundColor Green
}
catch {
    if ($_.Exception.Response.StatusCode -eq 400) {
        Write-Host "⚠️  Index 'nura-content' may already exist or has invalid schema" -ForegroundColor Yellow
    }
    else {
        Write-Host "❌ Failed to create index: $_" -ForegroundColor Red
    }
}

# ===========================================
# Index: nura-claims
# ===========================================
$claimsIndexDefinition = @{
    name   = "nura-claims"
    fields = @(
        @{ name = "id"; type = "Edm.String"; key = $true; filterable = $true }
        @{ name = "claim_id"; type = "Edm.String"; filterable = $true }
        @{ name = "content_id"; type = "Edm.String"; filterable = $true }
        @{ name = "narrative_id"; type = "Edm.String"; filterable = $true }
        @{ name = "claim_text"; type = "Edm.String"; searchable = $true }
        @{ name = "claim_text_en"; type = "Edm.String"; searchable = $true; analyzer = "en.microsoft" }
        @{ name = "claim_type"; type = "Edm.String"; filterable = $true; facetable = $true }
        @{ name = "language"; type = "Edm.String"; filterable = $true; facetable = $true }
        @{ name = "confidence"; type = "Edm.Double"; filterable = $true; sortable = $true }
        @{ name = "source_credibility"; type = "Edm.String"; filterable = $true; facetable = $true }
        @{ name = "extracted_at"; type = "Edm.DateTimeOffset"; filterable = $true; sortable = $true }
        @{ name = "embedding"; type = "Collection(Edm.Single)"; dimensions = 3072; vectorSearchProfile = "default-profile" }
    )
    vectorSearch = @{
        profiles   = @(
            @{ 
                name                 = "default-profile"
                algorithm            = "default-algorithm"
            }
        )
        algorithms = @(
            @{ 
                name           = "default-algorithm"
                kind           = "hnsw"
                hnswParameters = @{
                    m              = 4
                    efConstruction = 400
                    efSearch       = 500
                    metric         = "cosine"
                }
            }
        )
    }
} | ConvertTo-Json -Depth 10

Write-Host "`nCreating index: nura-claims..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$searchEndpoint/indexes/nura-claims?api-version=2024-07-01" `
        -Method PUT -Headers $headers -Body $claimsIndexDefinition
    Write-Host "✅ Index 'nura-claims' created successfully" -ForegroundColor Green
}
catch {
    if ($_.Exception.Response.StatusCode -eq 400) {
        Write-Host "⚠️  Index 'nura-claims' may already exist or has invalid schema" -ForegroundColor Yellow
    }
    else {
        Write-Host "❌ Failed to create index: $_" -ForegroundColor Red
    }
}

# ===========================================
# Verify indexes
# ===========================================
Write-Host "`nVerifying indexes..." -ForegroundColor Yellow
$indexes = Invoke-RestMethod -Uri "$searchEndpoint/indexes?api-version=2024-07-01" -Headers $headers

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                    INDEXES CREATED                           ║" -ForegroundColor Green
Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Green
foreach ($idx in $indexes.value) {
    $fieldCount = $idx.fields.Count
    Write-Host "║   $($idx.name.PadRight(20)) ($fieldCount fields)                       ║" -ForegroundColor Green
}
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "✨ Done! Azure AI Search indexes are ready.`n" -ForegroundColor Green