# PowerShell GitHub Script Launcher avec GUI
# Usage : irm "https://raw.githubusercontent.com/IsT3RiK/Scripts/main/launcher.ps1" | iex

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Configuration du dépôt GitHub
$githubUser = "IsT3RiK"
$githubRepo = "Scripts"
$githubBranch = "main"

function Get-GitHubFilesRecursive {
    param (
        [string]$path = ""
    )
    
    $apiUrl = "https://api.github.com/repos/$githubUser/$githubRepo/contents/$path?ref=$githubBranch"
    
    try {
        $items = Invoke-RestMethod -Uri $apiUrl -Headers @{
            "User-Agent" = "PowerShell-Script-Launcher"
            "Accept" = "application/vnd.github.v3+json"
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Erreur lors de la récupération du contenu GitHub ($path).`n$($_.Exception.Message)", 
            "Erreur", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return @()
    }
    
    $result = @()
    
    foreach ($item in $items) {
        if ($item.type -eq "file" -and $item.name -like "*.ps1") {
            $result += [PSCustomObject]@{
                Name = $item.name
                Path = $item.path
                DownloadUrl = $item.download_url
                DisplayName = $item.path.Replace("/", " > ")
            }
        } elseif ($item.type -eq "dir") {
            $result += Get-GitHubFilesRecursive -path $item.path
        }
    }
    
    return $result
}

# Création de la fonction principale
function Show-ScriptLauncher {
    # Afficher une fenêtre de progression
    $progressForm = New-Object System.Windows.Forms.Form
    $progressForm.Text = "Chargement"
    $progressForm.Size = New-Object System.Drawing.Size(300, 100)
    $progressForm.StartPosition = "CenterScreen"
    $progressForm.FormBorderStyle = "FixedDialog"
    $progressForm.ControlBox = $false
    
    $progressLabel = New-Object System.Windows.Forms.Label
    $progressLabel.Text = "Chargement des scripts depuis GitHub..."
    $progressLabel.Location = New-Object System.Drawing.Point(10, 20)
    $progressLabel.Size = New-Object System.Drawing.Size(280, 20)
    $progressForm.Controls.Add($progressLabel)
    
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(10, 50)
    $progressBar.Size = New-Object System.Drawing.Size(260, 20)
    $progressBar.Style = "Marquee"
    $progressForm.Controls.Add($progressBar)
    
    # Afficher la fenêtre de progression de manière non bloquante
    $progressForm.Show()
    $progressForm.Refresh()
    
    # Charger les scripts
    $scripts = Get-GitHubFilesRecursive
    
    # Fermer la fenêtre de progression
    $progressForm.Close()
    
    if (-not $scripts -or $scripts.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Aucun script .ps1 trouvé dans le dépôt.", 
            "Aucun script", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }
    
    # Création de la fenêtre principale
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "GitHub Script Launcher - $githubUser/$githubRepo"
    $form.Size = New-Object System.Drawing.Size(600, 500)
    $form.StartPosition = "CenterScreen"
    $form.Icon = [System.Drawing.SystemIcons]::Application
    
    # Zone de titre
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Sélectionnez un script à exécuter:"
    $titleLabel.Location = New-Object System.Drawing.Point(10, 10)
    $titleLabel.Size = New-Object System.Drawing.Size(580, 20)
    $titleLabel.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($titleLabel)
    
    # ListBox pour les scripts
    $listBox = New-Object System.Windows.Forms.ListView
    $listBox.Location = New-Object System.Drawing.Point(10, 40)
    $listBox.Size = New-Object System.Drawing.Size(560, 350)
    $listBox.View = [System.Windows.Forms.View]::Details
    $listBox.FullRowSelect = $true
    $listBox.Columns.Add("Nom du script", 400)
    $listBox.Columns.Add("Type", 150)
    
    foreach ($s in $scripts) {
        $item = New-Object System.Windows.Forms.ListViewItem($s.DisplayName)
        $item.SubItems.Add($s.Name.Split('.')[-1].ToUpper())
        $listBox.Items.Add($item)
    }
    
    $form.Controls.Add($listBox)
    
    # Bouton Exécuter
    $runButton = New-Object System.Windows.Forms.Button
    $runButton.Text = "Exécuter le script sélectionné"
    $runButton.Location = New-Object System.Drawing.Point(10, 400)
    $runButton.Size = New-Object System.Drawing.Size(220, 30)
    $runButton.Enabled = $false
    $form.Controls.Add($runButton)
    
    # Bouton Rafraîchir
    $refreshButton = New-Object System.Windows.Forms.Button
    $refreshButton.Text = "Rafraîchir la liste"
    $refreshButton.Location = New-Object System.Drawing.Point(240, 400)
    $refreshButton.Size = New-Object System.Drawing.Size(120, 30)
    $form.Controls.Add($refreshButton)
    
    # Bouton Fermer
    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Text = "Fermer"
    $closeButton.Location = New-Object System.Drawing.Point(470, 400)
    $closeButton.Size = New-Object System.Drawing.Size(100, 30)
    $form.Controls.Add($closeButton)
    
    # Label d'état
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = "Prêt. ${$scripts.Count} scripts disponibles."
    $statusLabel.Location = New-Object System.Drawing.Point(10, 440)
    $statusLabel.Size = New-Object System.Drawing.Size(560, 20)
    $form.Controls.Add($statusLabel)
    
    # Activer le bouton si un script est sélectionné
    $listBox.Add_SelectedIndexChanged({
        if ($listBox.SelectedItems.Count -gt 0) {
            $runButton.Enabled = $true
        } else {
            $runButton.Enabled = $false
        }
    })
    
    # Action bouton Exécuter
    $runButton.Add_Click({
        $idx = $listBox.SelectedIndices[0]
        if ($idx -ge 0) {
            $selected = $scripts[$idx]
            $statusLabel.Text = "Téléchargement et exécution de $($selected.Path)..."
            $form.Refresh()
            
            try {
                $scriptContent = Invoke-RestMethod -Uri $selected.DownloadUrl -Headers @{
                    "User-Agent" = "PowerShell-Script-Launcher"
                }
                
                # Créer un fichier temporaire pour le script
                $tempFile = [System.IO.Path]::GetTempFileName() + ".ps1"
                Set-Content -Path $tempFile -Value $scriptContent
                
                # Exécuter le script dans un nouveau processus PowerShell
                Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempFile`"" -Wait
                
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
    
    # Action bouton Rafraîchir
    $refreshButton.Add_Click({
        $statusLabel.Text = "Actualisation de la liste des scripts..."
        $form.Refresh()
        
        $scripts = Get-GitHubFilesRecursive
        $listBox.Items.Clear()
        
        foreach ($s in $scripts) {
            $item = New-Object System.Windows.Forms.ListViewItem($s.DisplayName)
            $item.SubItems.Add($s.Name.Split('.')[-1].ToUpper())
            $listBox.Items.Add($item)
        }
        
        $statusLabel.Text = "Liste actualisée. ${$scripts.Count} scripts disponibles."
    })
    
    # Action bouton Fermer
    $closeButton.Add_Click({ $form.Close() })
    
    # Afficher la fenêtre
    [void]$form.ShowDialog()
}

# Exécuter le lanceur
Show-ScriptLauncher
