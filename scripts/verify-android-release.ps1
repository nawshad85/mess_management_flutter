param(
    [string]$ApkPath = 'build/app/outputs/flutter-apk/app-direct-release.apk'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ApkPath).Path)
try {
    $entry = $archive.GetEntry('firebase-auth.properties')
    if ($null -eq $entry) { throw 'APK is missing Firebase Auth version metadata.' }
    $reader = [IO.StreamReader]::new($entry.Open())
    try { $sdkProperties = $reader.ReadToEnd() } finally { $reader.Dispose() }
    $versionMatch = [regex]::Match($sdkProperties, '(?m)^version=([^\r\n]+)')
    if (-not $versionMatch.Success) { throw 'Cannot identify the packaged Firebase Auth SDK.' }
    $authVersion = [version]$versionMatch.Groups[1].Value
    if ($authVersion -lt [version]'24.0.1') {
        throw "Firebase Auth $authVersion does not meet the 24.0.1+ release requirement for avoiding known Android startup/persistence regressions."
    }
    foreach ($abi in @('arm64-v8a', 'armeabi-v7a')) {
        foreach ($library in @('libapp.so', 'libflutter.so')) {
            if ($null -eq $archive.GetEntry("lib/$abi/$library")) {
                throw "Release is missing lib/$abi/$library."
            }
        }
    }
    Write-Output "Verified packaged Firebase Auth $authVersion and both ARM Flutter binaries."
} finally {
    $archive.Dispose()
}
