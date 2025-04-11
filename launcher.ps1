# PowerShell Script Launcher depuis un repo GitHub
# Compatible avec .ps1, .py, .js
# Usage : Exécute ce script dans PowerShell
# Ou en one-liner : irm "https://raw.githubusercontent.com/IsT3RiK/Scripts/main/launcher.ps1" | iex

# CONFIGURATION
$githubOwner = "IsT3RiK"
$githubRepo = "Scripts"
$githubBranch = "main"
$githubApiUrl = "https://api.github.com/repos/$githubOwner/$githubRepo/git/trees/$githubBranch?recursive=1"
$githubRawBase = "https://raw.githubusercontent.com/$githubOwner/$githubRepo/$githubBranch"
$tempDir = "$env:TEMP\script_launcher_temp"
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir | Out-Null

# 1. Récupérer la liste des fichiers du repo
Write-Host "Récupération de la liste des scripts depuis GitHub..."
try {
  $tree = Invoke-RestMethod -Uri $githubApiUrl
} catch {
  Write-Error "Impossible de récupérer la liste des fichiers. Vérifie le repo ou ta connexion."
  exit 1
}

# 2. Filtrer les scripts supportés
$scripts = $tree.tree | Where-Object {
  $_.type -eq "blob" -and ($_.path -like "*.ps1" -or $_.path -like "*.py" -or $_.path -like "*.js")
}

if (-not $scripts) {
  Write-Host "Aucun script .ps1, .py ou .js trouvé dans le repo." -ForegroundColor Yellow
  exit 0
}

# 3. Afficher la liste et demander la sélection
Write-Host "`nScripts disponibles :"
for ($i = 0; $i -lt $scripts.Count; $i++) {
  Write-Host ("[{0}] {1}" -f $i, $scripts[$i].path)
}

Write-Host "`nEntrez le(s) numéro(s) du/des script(s) à exécuter, séparés par des virgules (ex: 0,2,3) :"
$input = Read-Host
$indices = $input -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -match "^\d+$" }

if (-not $indices) {
  Write-Host "Aucune sélection. Fin du script."
  exit 0
}

foreach ($idx in $indices) {
  if ($idx -ge $scripts.Count) {
    Write-Host "Indice $idx invalide, ignoré." -ForegroundColor Yellow
    continue
  }
  $script = $scripts[$idx]
  $ext = [System.IO.Path]::GetExtension($script.path).ToLower()
  $localPath = Join-Path $tempDir ([System.IO.Path]::GetFileName($script.path))
  $rawUrl = "$githubRawBase/$($script.path -replace '\\','/')"

  Write-Host "`nTéléchargement de $($script.path)..."
  try {
    Invoke-WebRequest -Uri $rawUrl -OutFile $localPath
  } catch {
    Write-Host "Erreur lors du téléchargement de $($script.path)" -ForegroundColor Red
    continue
  }

  Write-Host "Exécution de $($script.path)..."
  switch ($ext) {
    ".ps1" {
      try {
        & powershell -ExecutionPolicy Bypass -File $localPath
      } catch {
        Write-Host "Erreur d'exécution PowerShell : $_" -ForegroundColor Red
      }
    }
    ".py" {
      if (Get-Command python -ErrorAction SilentlyContinue) {
        & python $localPath
      } elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
        & python3 $localPath
      } else {
        Write-Host "Python n'est pas installé." -ForegroundColor Yellow
      }
    }
    ".js" {
      if (Get-Command node -ErrorAction SilentlyContinue) {
        & node $localPath
      } else {
        Write-Host "Node.js n'est pas installé." -ForegroundColor Yellow
      }
    }
    default {
      Write-Host "Type de script non supporté : $ext" -ForegroundColor Yellow
    }
  }
}

Write-Host "`nNettoyage..."
Remove-Item $tempDir -Recurse -Force

Write-Host "`nTerminé."
