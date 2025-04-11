# Debug minimal pour GitHub API
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "Version PowerShell : $($PSVersionTable.PSVersion)"
$apiUrl = "https://api.github.com/repos/IsT3RiK/Scripts/contents?ref=main"
try {
  $files = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "ps-launcher" }
  Write-Host "Succès ! Fichiers récupérés :"
  $files | ForEach-Object { Write-Host $_.name }
} catch {
  Write-Host "Erreur lors de la récupération du contenu GitHub." -ForegroundColor Red
  Write-Host "Détail de l’erreur : $($_ | Out-String)" -ForegroundColor Yellow
  Write-Host "URL utilisée : $apiUrl" -ForegroundColor Yellow
}
