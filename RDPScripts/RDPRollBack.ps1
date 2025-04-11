# Afficher les options de version
Write-Host "Veuillez selectionner la version :"
Write-Host "1. 2024 - 10.0.22621"
Write-Host "2. 2025 - 10.0.26100"

# Demande � l'utilisateur de s�lectionner la version
$versionSelection = Read-Host "Entrez le num�ro correspondant � la version souhait�e"

# D�finir le chemin des nouveaux fichiers en fonction de la version s�lectionn�e
switch ($versionSelection) {
    "1" {
        $version = "2024 - 10.0.22621"
        $newFilesSystem32 = Get-ChildItem -Path "RDPData/RDP/10.0.22621/System32"
        $newFilesSysWOW64 = Get-ChildItem -Path "RDPData/RDP/10.0.22621/SysWOW64"
    }
    "2" {
        $version = "2025 - 10.0.26100"
        $newFilesSystem32 = Get-ChildItem -Path "RDPData/RDP/10.0.26100/System32"
        $newFilesSysWOW64 = Get-ChildItem -Path "RDPData/RDP/10.0.26100/SysWOW64"
    }
    default {
        Write-Host "Selection non valide."
        exit
    }
}

# Arr�ter les processus RDP
Write-Host "Arr�t des processus mstsc..."
Get-Process -Name mstsc -ErrorAction SilentlyContinue | Stop-Process -Force

function Replace-File {
    param (
        [string]$filePath,
        [string]$newFilePath
    )

    # V�rifier si le fichier source existe
    if (-not (Test-Path $newFilePath)) {
        throw "Fichier source manquant : $newFilePath"
    }

    # Prendre possession du fichier
    takeown /f $filePath

    # Accorder les permissions
    icacls $filePath /grant "*S-1-5-32-544:F" /q

    # Supprimer le fichier
    Remove-Item -Path $filePath -Force

    # Copier le nouveau fichier
    Copy-Item -Path $newFilePath -Destination $filePath -Force
    Write-Host "$filePath remplac� avec succ�s."
}

function Replace-FilesInDirectory {
    param (
        [string]$targetDirectory,
        [array]$newFiles
    )

    foreach ($file in $newFiles) {
        $targetPath = Join-Path -Path $targetDirectory -ChildPath $file.Name
        Replace-File -filePath $targetPath -newFilePath $file.FullName
    }
}

# Remplacer les fichiers dans System32
try {
    Replace-FilesInDirectory -targetDirectory "C:\Windows\System32" -newFiles $newFilesSystem32
    Replace-FilesInDirectory -targetDirectory "C:\Windows\SysWOW64" -newFiles $newFilesSysWOW64
    Write-Host "Op�ration termin�e. Red�marrage n�cessaire."
    #Restart-Computer -Confirm
}
catch {
    Write-Host "Erreur : $_" -ForegroundColor Red
    exit 1
}