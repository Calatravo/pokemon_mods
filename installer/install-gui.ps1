[CmdletBinding()]
param(
    [string]$GamePath
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $projectRoot "install.ps1"

if (-not $GamePath) {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select the Pokemon Z folder that directly contains Game.exe. / Selecciona la carpeta de Pokemon Z que contiene Game.exe."
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        exit 0
    }
    $GamePath = $dialog.SelectedPath
}

try {
    $gameExe = Join-Path $GamePath "Game.exe"
    if (-not (Test-Path -LiteralPath $gameExe -PathType Leaf)) {
        throw "Game.exe was not found in the selected folder. / No se encontró Game.exe en la carpeta seleccionada."
    }

    $runningGame = Get-Process -Name "Game" -ErrorAction SilentlyContinue | Where-Object {
        try { $_.Path -and ((Split-Path -Parent $_.Path) -eq (Resolve-Path -LiteralPath $GamePath).Path) }
        catch { $false }
    }
    if ($runningGame) {
        throw "Close Pokemon Z before installing the mod. / Cierra Pokemon Z antes de instalar el mod."
    }

    $output = & $installer -GamePath $GamePath -Language auto 2>&1 | Out-String
    [System.Windows.Forms.MessageBox]::Show(
        "Pokemon Z Mods was installed successfully.`n`nPokemon Z Mods se instaló correctamente.`n`n$GamePath",
        "Pokemon Z Mods",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
    exit 0
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        $_.Exception.Message,
        "Pokemon Z Mods - Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}
