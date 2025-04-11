# PowerShell GitHub Script Launcher (TLS Debug)
# Usage: irm "https://raw.githubusercontent.com/IsT3RiK/Scripts/main/launcher.ps1" | iex

# Forcer TLS 1.2 (GitHub API l’exige)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$githubUser = "IsT3RiK"
$githubRepo = "Scripts"
$githubBranch = "main"
$githubPath = "" # Dossier à la racine du repo

if ($githubPath -eq "") {
  $apiUrl = "https://api.github.com/repos/$githubUser/$githubRepo/contents?ref=$githubBranch"
} else {
  $apiUrl = "https://api.github.com/repos/$githubUser/$githubRepo/contents/$githubPath?ref=$githubBranch"
}

try {
  $files = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "ps-launcher" }
} catch {
  Write-Host "Erreur lors de la récupération du contenu GitHub." -ForegroundColor Red
  Write-Host "Détail de l’erreur : $($_ | Out-String)" -ForegroundColor Yellow
  Write-Host "URL utilisée : $apiUrl" -ForegroundColor Yellow
  exit 1
}

$ps1Files = $files | Where-Object { $_.name -like "*.ps1" -and $_.type -eq "file" }
if (-not $ps1Files) {
  Write-Host "Aucun script .ps1 trouvé dans le dépôt." -ForegroundColor Yellow
  exit 0
}

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
  Write-Host "Détail de l’erreur : $($_ | Out-String)" -ForegroundColor Yellow
  Write-Host "URL utilisée : $rawUrl" -ForegroundColor Yellow
  exit 1
}
