# PowerShell GitHub Script Launcher avec GUI
# Usage : irm "https://raw.githubusercontent.com/IsT3RiK/Scripts/main/launcher.ps1" | iex

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
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
    [System.Windows.Forms.MessageBox]::Show("Erreur lors de la récupération du contenu GitHub ($path).`n$($_.Exception.Message)", "Erreur", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
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

# Création de la fenêtre
$form = New-Object System.Windows.Forms.Form
$form.Text = "GitHub Script Launcher"
$form.Size = New-Object System.Drawing.Size(500,400)
$form.StartPosition = "CenterScreen"

# ListBox pour les scripts
$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Location = New-Object System.Drawing.Point(10,10)
$listBox.Size = New-Object System.Drawing.Size(460,280)
$listBox.Anchor = "Top,Left,Right"
$form.Controls.Add($listBox)

# Bouton Exécuter
$runButton = New-Object System.Windows.Forms.Button
$runButton.Text = "Exécuter le script sélectionné"
$runButton.Location = New-Object System.Drawing.Point(10,300)
$runButton.Size = New-Object System.Drawing.Size(220,30)
$runButton.Enabled = $false
$form.Controls.Add($runButton)

# Bouton Fermer
$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "Fermer"
$closeButton.Location = New-Object System.Drawing.Point(250,300)
$closeButton.Size = New-Object System.Drawing.Size(100,30)
$form.Controls.Add($closeButton)

# Label d'état
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Chargement des scripts depuis GitHub..."
$statusLabel.Location = New-Object System.Drawing.Point(10,340)
$statusLabel.Size = New-Object System.Drawing.Size(460,20)
$form.Controls.Add($statusLabel)

# Charger les scripts en arrière-plan
$scriptList = @()
$job = [System.ComponentModel.BackgroundWorker]::new()
$job.DoWork += {
  $scriptList = Get-GitHubFilesRecursive
}
$job.RunWorkerCompleted += {
  $listBox.Items.Clear()
  if ($scriptList.Count -eq 0) {
    $statusLabel.Text = "Aucun script .ps1 trouvé dans le dépôt."
  } else {
    foreach ($s in $scriptList) {
      $listBox.Items.Add($s.path)
    }
    $statusLabel.Text = "Sélectionnez un script et cliquez sur Exécuter."
  }
}
$job.RunWorkerAsync()

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
  if ($idx -ge 0) {
    $selected = $scriptList[$idx]
    $statusLabel.Text = "Téléchargement et exécution de $($selected.path)..."
    try {
      $scriptContent = Invoke-RestMethod -Uri $selected.download_url -Headers @{ "User-Agent" = "ps-launcher" }
      Invoke-Expression $scriptContent
      $statusLabel.Text = "Script exécuté : $($selected.name)"
    } catch {
      [System.Windows.Forms.MessageBox]::Show("Erreur lors de l’exécution du script.`n$($_.Exception.Message)", "Erreur", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
      $statusLabel.Text = "Erreur lors de l’exécution."
    }
  }
})

# Action bouton Fermer
$closeButton.Add_Click({ $form.Close() })

# Afficher la fenêtre
[void]$form.ShowDialog()
