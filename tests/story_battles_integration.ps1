[CmdletBinding()]
param([string]$GameFolder = "$PSScriptRoot/../Pokemon Z V2.19")
& "$PSScriptRoot/novice_aids_integration.ps1" -GameFolder $GameFolder -TestFile "$PSScriptRoot/story_battles_test.rb"
