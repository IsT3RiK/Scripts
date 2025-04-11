# PowerShell GitHub Script Launcher
# Usage: irm "https://raw.githubusercontent.com/IsT3RiK/Scripts/main/launcher.ps1" | iex

# Configuration
$githubUser = "IsT3RiK"
$githubRepo = "Scripts"
$githubBranch = "main"
$githubPath = "" # Dossier à la racine du repo, sinon mettre "subfolder"

# Récupère la liste des fichiers .ps1 via l’API GitHub
$apiUrl = "https://api.github.com/repos/$githubUser/$githubRepo/contents/$githubPath?ref=$githubBranch"
try {
  $files = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "ps-launcher" }
} catch {
  Write-Host "Erreur lors de la récupération du contenu GitHub." -ForegroundColor Red
  exit 1
}

$ps1Files = $files | Where-Object { $_.name -like "*.ps1" -and $_.type -eq "file" }
if (-not $ps1Files) {
  Write-Host "Aucun script .ps1 trouvé dans le dépôt." -ForegroundColor Yellow
  exit 0
}

# Affiche la liste et demande à l’utilisateur de choisir
Write-Host "Scripts disponibles sur $githubUser/$githubRepo :"
for ($i = 0; $i -lt $ps1Files.Count; $i++) {
  Write-Host "$($i+1)) $($ps1Files[$i].name)"
}
do {
  $choice = Read-Host "Entrez le numéro du script à exécuter (ou q pour quitter)"
  if ($choice -eq "q") { exit 0 }
  $valid = $choice -as [int]
} while (-not $valid -or $valid -lt 1 -or $valid -gt $ps1Files.Count)

$selected = $ps1Files[$choice-1]
$rawUrl = $selected.download_url

Write-Host "Téléchargement et exécution de $($selected.name)..." -ForegroundColor Cyan
try {
  $scriptContent = Invoke-RestMethod -Uri $rawUrl -Headers @{ "User-Agent" = "ps-launcher" }
  Invoke-Expression $scriptContent
} catch {
  Write-Host "Erreur lors de l’exécution du script." -ForegroundColor Red
  exit 1
}
