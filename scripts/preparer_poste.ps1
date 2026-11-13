<#
  EEIP · Préparation du poste Windows
  ---------------------------------------------------------------------
  À lancer UNE fois, dans un Terminal ouvert en administrateur :
    powershell -ExecutionPolicy Bypass -File C:\EEIP\scripts\preparer_poste.ps1 -Instance MSSQLSERVER

  -Instance : MSSQLSERVER pour l'instance par défaut, sinon le nom de
              votre instance nommée (ce qui suit la barre oblique inverse
              dans SSMS, par exemple MSSQLSERVER2022).

  Prérequis : Python 3.12 ou plus récent installé « pour tous les
  utilisateurs » dans C:\Program Files (l'Agent SQL Server doit pouvoir
  l'exécuter), SQL Server 2022 et SSMS installés.
#>
param([string]$Instance = "MSSQLSERVER")

$ErrorActionPreference = "Stop"
$Racine = "C:\EEIP"

function Etape($texte) { Write-Host "`n== $texte" -ForegroundColor Cyan }
function Ok($texte)    { Write-Host "   OK  $texte" -ForegroundColor Green }

Etape "1. Dossiers de la plateforme"
foreach ($d in "sql", "ingestion", "config", "logs", "scripts") {
    New-Item -ItemType Directory -Force -Path (Join-Path $Racine $d) | Out-Null
}
Ok "C:\EEIP\{sql, ingestion, config, logs, scripts}"

Etape "2. Python installé pour tous les utilisateurs"
$python = Get-ChildItem "C:\Program Files\Python3*\python.exe" -ErrorAction SilentlyContinue |
          Sort-Object FullName -Descending | Select-Object -First 1
if (-not $python) {
    throw "Python introuvable dans C:\Program Files. Installez-le depuis python.org en cochant « Install for all users »."
}
Ok $python.FullName

Etape "3. Environnement virtuel et bibliothèques"
if (-not (Test-Path "$Racine\.venv\Scripts\python.exe")) { & $python.FullName -m venv "$Racine\.venv" }
& "$Racine\.venv\Scripts\python.exe" -m pip install --quiet --upgrade pip
& "$Racine\.venv\Scripts\python.exe" -m pip install --quiet -r "$Racine\ingestion\requirements.txt"
Ok "requests, pyodbc, tzdata"

Etape "4. Pilote ODBC 18"
if (Get-OdbcDriver -Name "ODBC Driver 18 for SQL Server" -ErrorAction SilentlyContinue) {
    Ok "ODBC Driver 18 for SQL Server"
} else {
    Write-Host "   À FAIRE : installez « ODBC Driver 18 for SQL Server » (Microsoft Learn), puis relancez ce script." -ForegroundColor Yellow
}

Etape "5. Agent SQL Server : démarrage automatique"
$service = if ($Instance -eq "MSSQLSERVER") { "SQLSERVERAGENT" } else { "SQLAgent`$$Instance" }
Set-Service -Name $service -StartupType Automatic
Start-Service -Name $service
Ok "$service : $((Get-Service $service).Status)"

Etape "6. Droits du compte de l'Agent sur C:\EEIP"
$compte = "NT SERVICE\$service"
icacls $Racine /grant "${compte}:(OI)(CI)M" /T /Q | Out-Null
Ok "$compte : modification sur C:\EEIP"

Write-Host "`nPoste prêt. Étape suivante : copier config\eeip.exemple.ini en C:\EEIP\config\eeip.ini et le compléter." -ForegroundColor Green
