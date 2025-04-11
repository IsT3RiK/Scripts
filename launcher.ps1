# PowerShell GitHub Script Launcher (Recherche Récursive)
# Usage: irm "https://raw.githubusercontent.com/IsT3RiK/Scripts/main/launcher.ps1" | iex

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$githubUser = "IsT3RiK"
$githubRepo = "Scripts"
$githubBranch = "main"

function Get-GitHubFilesRecursive {
  param (
    [string]$path = ""
  )
  $apiUrl = "https://api.github.com/repos/$githubUser/$githubRepo/contents/$path?ref=$githubBranch"
  try {
    $items = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "ps-launcher" }
  } catch {
    Write-Host "Erreur lors de la récupération du contenu GitHub ($path)." -ForegroundColor Red
    Write-Host "Détail de l’erreur : $($_ | Out-String)" -ForegroundColor Yellow
    return @()
  }
  $result = @()
  foreach ($item in $items) {
    if ($item.type -eq "file" -and $item.name -like "*.ps1") {
      $result += [PSCustomObject]@{
        name = $item.name
        path = $item.path
        download_url = $item.download_url
      }
    } elseif ($item.type -eq "dir") {
      $result += Get-GitHubFilesRecursive -path $item.path
    }
  }
  return $result
}

Write-Host "Recherche des scripts .ps1 dans le dépôt $githubUser/$githubRepo ..."
$scripts = Get-GitHubFilesRecursive

if (-not $scripts -or $scripts.Count -eq 0) {
  Write-Host "Aucun script .ps1 trouvé dans le dépôt." -ForegroundColor Yellow
  exit 0
}

Write-Host "Scripts disponibles :"
for ($i = 0; $i -lt $scripts.Count; $i++) {
  Write-Host "$($i+1)) $($scripts[$i].path)"
}
do {
  $choice = Read-Host "Entrez le numéro du script à exécuter (ou q pour quitter)"
  if ($choice -eq "q") { exit 0 }
  $valid = $choice -as [int]
} while (-not $valid -or $valid -lt 1 -or $valid -gt $scripts.Count)

$selected = $scripts[$choice-1]
$rawUrl = $selected.download_url

Write-Host "Téléchargement et exécution de $($selected.path)..." -ForegroundColor Cyan
try {
  $scriptContent = Invoke-RestMethod -Uri $rawUrl -Headers @{ "User-Agent" = "ps-launcher" }
  Invoke-Expression $scriptContent
} catch {
  Write-Host "Erreur lors de l’exécution du script." -ForegroundColor Red
  Write-Host "Détail de l’erreur : $($_ | Out-String)" -ForegroundColor Yellow
  Write-Host "URL utilisée : $rawUrl" -ForegroundColor Yellow
  exit 1
}
