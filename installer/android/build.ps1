[CmdletBinding()]
param(
    [string]$Sdk = "$env:LOCALAPPDATA/Android/Sdk",
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$OutputPath,
    [string]$Keystore,
    [string]$KeyAlias = 'androiddebugkey',
    [switch]$Release
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$version = [IO.File]::ReadAllText((Join-Path $repo 'VERSION')).Trim()
if ($Release -and (-not $Keystore -or $KeyAlias -eq 'androiddebugkey')) { throw 'Release builds require an explicit project keystore and alias.' }
if (-not $OutputPath) { $OutputPath = Join-Path $repo 'dist/android-installer' }
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
if (-not $JavaHome) { $JavaHome = Split-Path (Split-Path (Get-Command javac).Source -Parent) -Parent }
$env:JAVA_HOME = $JavaHome
$buildTools = Join-Path $Sdk 'build-tools/35.0.0'
$androidJar = Join-Path $Sdk 'platforms/android-35/android.jar'
foreach ($required in @($androidJar, "$buildTools/aapt2.exe", "$buildTools/d8.bat", "$JavaHome/bin/javac.exe")) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Missing SDK/JDK dependency: $required" }
}
New-Item -ItemType Directory -Force $OutputPath | Out-Null
$stage = Join-Path $OutputPath ('build-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force "$stage/classes", "$stage/dex", "$stage/assets/mod" | Out-Null
function Run-Checked([string]$program, [string[]]$arguments) {
    & $program @arguments
    if ($LASTEXITCODE -ne 0) { throw "$program failed ($LASTEXITCODE)" }
}
try {
    # Only source-controlled mod files. Never package game assets, logs or saves.
    $modFiles = & git -C $repo ls-files mod/HardcoreNuzlocke
    if ($LASTEXITCODE -ne 0 -or -not $modFiles) { throw 'Cannot enumerate mod sources.' }
    foreach ($relative in $modFiles) {
        $target = Join-Path "$stage/assets/mod" $relative.Substring('mod/HardcoreNuzlocke/'.Length)
        New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
        Copy-Item -LiteralPath (Join-Path $repo $relative) -Destination $target
    }
    Copy-Item "$repo/installer/preload-snippet.rb" "$stage/assets/preload-snippet.rb"
    $sources = @(Get-ChildItem "$PSScriptRoot/src" -Filter '*.java' -Recurse | ForEach-Object FullName)
    Run-Checked "$JavaHome/bin/javac.exe" (@('-encoding','UTF-8','-source','8','-target','8','-classpath',$androidJar,'-d',"$stage/classes") + $sources)
    $classes = @(Get-ChildItem "$stage/classes" -Filter '*.class' -Recurse | ForEach-Object FullName)
    Run-Checked "$buildTools/d8.bat" (@('--lib',$androidJar,'--min-api','26','--output',"$stage/dex") + $classes)
    $manifest = [IO.File]::ReadAllText("$PSScriptRoot/AndroidManifest.xml")
    if ($Release) {
        if ($version -notmatch '^(\d+)\.(\d+)\.(\d+)$') { throw 'Release APK requires a numeric semantic version.' }
        $versionCode = [int]$Matches[1] * 1000000 + [int]$Matches[2] * 1000 + [int]$Matches[3]
        $manifest = $manifest.Replace('android:versionCode="1"', "android:versionCode=`"$versionCode`"").Replace('android:versionName="0.1-test"', "android:versionName=`"$version`"")
    }
    [IO.File]::WriteAllText("$stage/AndroidManifest.xml", $manifest, (New-Object Text.UTF8Encoding($false)))
    Run-Checked "$buildTools/aapt2.exe" @('link','-I',$androidJar,'--manifest',"$stage/AndroidManifest.xml",'-o',"$stage/unsigned.apk")
    # jar normalizes nested Windows paths to ZIP forward slashes for AssetManager.
    Run-Checked "$JavaHome/bin/jar.exe" @('uf',"$stage/unsigned.apk",'-C',$stage,'assets','-C',"$stage/dex",'classes.dex')
    $entries = & "$JavaHome/bin/jar.exe" tf "$stage/unsigned.apk"
    if ($entries -notcontains 'assets/mod/loader.rb' -or $entries -notcontains 'assets/mod/Scripts/hooks.rb') { throw 'APK mod payload is incomplete.' }
    Run-Checked "$buildTools/zipalign.exe" @('-f','4',"$stage/unsigned.apk","$stage/aligned.apk")
    if (-not $Keystore) {
        $keyDirectory = Join-Path $env:LOCALAPPDATA 'PokemonZMods'
        New-Item -ItemType Directory -Force $keyDirectory | Out-Null
        $Keystore = Join-Path $keyDirectory 'android-installer-test.keystore'
        if (-not (Test-Path -LiteralPath $Keystore)) {
            Run-Checked "$JavaHome/bin/keytool.exe" @('-genkeypair','-keystore',$Keystore,'-storepass','android','-keypass','android','-alias',$KeyAlias,'-keyalg','RSA','-keysize','2048','-validity','3650','-dname','CN=Pokemon Z Mods Test Build')
        }
        $env:PZ_APK_STORE_PASSWORD = 'android'
        $env:PZ_APK_KEY_PASSWORD = 'android'
    }
    elseif (-not $env:PZ_APK_STORE_PASSWORD -or -not $env:PZ_APK_KEY_PASSWORD) { throw 'Set PZ_APK_STORE_PASSWORD and PZ_APK_KEY_PASSWORD for release signing.' }
    $apkName = if ($Release) { "Pokemon-Z-Mods-v$version-Android-Installer.apk" } else { 'Pokemon-Z-Mods-Android-Installer-test.apk' }
    $apk = Join-Path $OutputPath $apkName
    Run-Checked "$buildTools/apksigner.bat" @('sign','--ks',$Keystore,'--ks-key-alias',$KeyAlias,'--ks-pass','env:PZ_APK_STORE_PASSWORD','--key-pass','env:PZ_APK_KEY_PASSWORD','--out',$apk,"$stage/aligned.apk")
    Run-Checked "$buildTools/apksigner.bat" @('verify',$apk)
    $apkHash = Get-FileHash -LiteralPath $apk -Algorithm SHA256
    [IO.File]::WriteAllText((Join-Path $OutputPath 'SHA256SUMS.txt'), ($apkHash.Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($apk) + "`n"), (New-Object Text.UTF8Encoding($false)))
    $apkHash
    Write-Output $apk
}
finally {
    # The stage is a fresh child of the explicit output folder.
    $resolvedStage = [IO.Path]::GetFullPath($stage)
    if ($resolvedStage.StartsWith($OutputPath.TrimEnd('\') + '\') -and (Test-Path -LiteralPath $resolvedStage)) { Remove-Item -LiteralPath $resolvedStage -Recurse -Force }
}
