# PowerShell GitHub Script Launcher avec GUI
# Sauvez ce fichier en tant que launcher.ps1 et exécutez-le

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Configuration du dépôt GitHub - MODIFIEZ CES VALEURS si nécessaire
$githubUser = "IsT3RiK"  # Votre nom d'utilisateur GitHub
$githubRepo = "Scripts"  # Nom de votre dépôt
$githubBranch = "main"   # Branche par défaut de votre dépôt

function Test-GitHubRepository {
    $testUrl = "https://api.github.com/repos/$githubUser/$githubRepo"
    try {
        Invoke-RestMethod -Uri $testUrl -Headers @{
            "User-Agent" = "PowerShell-Script-Launcher"
        } -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Get-GitHubFilesRecursive {
    param (
        [string]$path = ""
    )
    
    $apiUrl = if ([string]::IsNullOrEmpty($path)) {
        "https://api.github.com/repos/$githubUser/$githubRepo/contents?ref=$githubBranch"
    } else {
        "https://api.github.com/repos/$githubUser/$githubRepo/contents/$path`?ref=$githubBranch"
    }
    
    Write-Host "Recherche des fichiers dans: $apiUrl" -ForegroundColor Cyan
    
    try {
        $items = Invoke-RestMethod -Uri $apiUrl -Headers @{
            "User-Agent" = "PowerShell-Script-Launcher"
        } -ErrorAction Stop
        
        Write-Host "Trouvé $($items.Count) éléments" -ForegroundColor Green
    } catch {
        Write-Host "Erreur API GitHub: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
    
    $result = @()
    
    foreach ($item in $items) {
        if ($item.type -eq "file" -and $item.name -like "*.ps1" -and $item.name -ne "launcher.ps1") {
            $result += [PSCustomObject]@{
                Name = $item.name
                Path = $item.path
                DownloadUrl = $item.download_url
            }
        } elseif ($item.type -eq "dir") {
            $result += Get-GitHubFilesRecursive -path $item.path
        }
    }
    
    return $result
}

# Vérifier si le dépôt existe
if (-not (Test-GitHubRepository)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Le dépôt GitHub '$githubUser/$githubRepo' est introuvable ou inaccessible.`n`n" +
        "Veuillez vérifier :`n" +
        "1. Que le dépôt existe sur GitHub`n" +
        "2. Que le dépôt est public`n" +
        "3. Que les noms d'utilisateur et de dépôt sont corrects dans le script",
        "Dépôt non trouvé",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    return
}

# Création de la fenêtre
$form = New-Object System.Windows.Forms.Form
$form.Text = "GitHub Script Launcher"
$form.Size = New-Object System.Drawing.Size(500, 400)
$form.StartPosition = "CenterScreen"

# Label d'instruction
$instructionLabel = New-Object System.Windows.Forms.Label
$instructionLabel.Text = "Sélectionnez un script à exécuter:"
$instructionLabel.Location = New-Object System.Drawing.Point(10, 10)
$instructionLabel.Size = New-Object System.Drawing.Size(480, 20)
$form.Controls.Add($instructionLabel)

# Label de statut initial
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Chargement des scripts depuis GitHub..."
$statusLabel.Location = New-Object System.Drawing.Point(10, 340)
$statusLabel.Size = New-Object System.Drawing.Size(460, 20)
$form.Controls.Add($statusLabel)

# ListBox pour les scripts
$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Location = New-Object System.Drawing.Point(10, 40)
$listBox.Size = New-Object System.Drawing.Size(460, 280)
$listBox.Anchor = "Top,Left,Right"
$form.Controls.Add($listBox)

# Bouton Exécuter
$runButton = New-Object System.Windows.Forms.Button
$runButton.Text = "Exécuter le script sélectionné"
$runButton.Location = New-Object System.Drawing.Point(10, 300)
$runButton.Size = New-Object System.Drawing.Size(220, 30)
$runButton.Enabled = $false
$form.Controls.Add($runButton)

# Bouton Fermer
$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "Fermer"
$closeButton.Location = New-Object System.Drawing.Point(370, 300)
$closeButton.Size = New-Object System.Drawing.Size(100, 30)
$form.Controls.Add($closeButton)

# Variable globale pour stocker les scripts
$global:scripts = @()

# Fonction pour charger les scripts
function Load-Scripts {
    $statusLabel.Text = "Chargement des scripts depuis GitHub..."
    $listBox.Items.Clear()
    $runButton.Enabled = $false
    $form.Refresh()
    
    $global:scripts = Get-GitHubFilesRecursive
    
    if ($global:scripts -and $global:scripts.Count -gt 0) {
        foreach ($script in $global:scripts) {
            $displayName = if ($script.Path) { $script.Path } else { $script.Name }
            $listBox.Items.Add($displayName)
        }
        $statusLabel.Text = "$($global:scripts.Count) scripts trouvés. Sélectionnez un script pour l'exécuter."
    } else {
        $statusLabel.Text = "Aucun script trouvé. Ajoutez des scripts .ps1 à votre dépôt GitHub."
    }
}

# Activer le bouton si un script est sélectionné
$listBox.Add_SelectedIndexChanged({
    if ($listBox.SelectedIndex -ge 0) {
        $runButton.Enabled = $true
    } else {
        $runButton.Enabled = $false
    }
})

# Action bouton Exécuter
$runButton.Add_Click({
    $idx = $listBox.SelectedIndex
    if ($idx -ge 0 -and $idx -lt $global:scripts.Count) {
        $selected = $global:scripts[$idx]
        $statusLabel.Text = "Téléchargement et exécution de $($selected.Path)..."
        $form.Refresh()
        
        try {
            $scriptContent = Invoke-RestMethod -Uri $selected.DownloadUrl -Headers @{
                "User-Agent" = "PowerShell-Script-Launcher"
            }
            
            # Créer un fichier temporaire pour le script
            $tempFile = [System.IO.Path]::GetTempFileName() + ".ps1"
            Set-Content -Path $tempFile -Value $scriptContent
            
            # Exécuter le script
            & $tempFile
            
            # Nettoyer
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            
            $statusLabel.Text = "Script exécuté avec succès : $($selected.Name)"
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Erreur lors de l'exécution du script.`n$($_.Exception.Message)", 
                "Erreur", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            $statusLabel.Text = "Erreur lors de l'exécution du script."
        }
    }
})

# Action bouton Fermer
$closeButton.Add_Click({ $form.Close() })

# Charger les scripts au démarrage
Load-Scripts

# Afficher la fenêtre
[void]$form.ShowDialog()
