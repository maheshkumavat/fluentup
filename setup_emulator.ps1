# FluentUp Android Emulator Setup Script (D: Drive Configuration)
$SdkRoot = "D:\Android\Sdk"
$AndroidHome = "D:\Android"
$AvdHome = "D:\Android\.android\avd"
$AvdPath = "$AvdHome\Pixel_7_API34.avd"
$CmdlineToolsDir = "$SdkRoot\cmdline-tools\latest"
$TempDir = "D:\Android\Temp"

# Set environment variables for Android SDK and AVDs on D: drive (Process & User level)
$env:ANDROID_HOME = $SdkRoot
$env:ANDROID_SDK_ROOT = $SdkRoot
$env:ANDROID_SDK_HOME = $AndroidHome
$env:ANDROID_USER_HOME = $AndroidHome
$env:ANDROID_AVD_HOME = $AvdHome
$env:ANDROID_EMULATOR_HOME = "D:\Android\.android"

[Environment]::SetEnvironmentVariable("ANDROID_HOME", $SdkRoot, "User")
[Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $SdkRoot, "User")
[Environment]::SetEnvironmentVariable("ANDROID_SDK_HOME", $AndroidHome, "User")
[Environment]::SetEnvironmentVariable("ANDROID_USER_HOME", $AndroidHome, "User")
[Environment]::SetEnvironmentVariable("ANDROID_AVD_HOME", $AvdHome, "User")
[Environment]::SetEnvironmentVariable("ANDROID_EMULATOR_HOME", "D:\Android\.android", "User")

New-Item -ItemType Directory -Path $SdkRoot -Force | Out-Null
New-Item -ItemType Directory -Path $AvdHome -Force | Out-Null
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

Write-Host ""
Write-Host "=== FluentUp Android Emulator Setup (D: Drive) ===" -ForegroundColor Cyan
Write-Host "SDK Location: $SdkRoot" -ForegroundColor Gray
Write-Host "AVD Location: $AvdPath" -ForegroundColor Gray
Write-Host ""

$avdmanager = "$CmdlineToolsDir\bin\avdmanager.bat"
$avdName = "Pixel_7_API34"

if (-not (Test-Path $AvdPath)) {
    Write-Host "Downloading build-tools & system-images on D: drive..." -ForegroundColor Yellow
    "y`ny`ny`ny`ny`ny`ny" | cmd /c "$sdkmanager" --licenses --sdk_root="$SdkRoot" 2>&1 | Out-Null
    cmd /c "$sdkmanager" --sdk_root="$SdkRoot" "platform-tools" "build-tools;34.0.0" "platforms;android-34" "emulator" "system-images;android-34;google_apis;x86_64" 2>&1 | Out-Null
    Write-Host "Creating Pixel 7 (API 34) emulator on D: drive..." -ForegroundColor Yellow
    "no" | cmd /c "$avdmanager" create avd --force --name "$avdName" --package "system-images;android-34;google_apis;x86_64" --device "pixel_7" --path "$AvdPath" 2>&1
    Write-Host "Created successfully on D: drive!" -ForegroundColor Green
} else {
    Write-Host "Pixel 7 emulator already configured on D: drive." -ForegroundColor Green
}

Write-Host ""
Write-Host "Starting Pixel 7 emulator from D: drive..." -ForegroundColor Cyan
Start-Process -FilePath "$SdkRoot\emulator\emulator.exe" -ArgumentList "-avd $avdName"

Write-Host ""
Write-Host "Emulator is booting (~30-60 sec). Once you see the Android home screen:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  flutter run" -ForegroundColor Green
Write-Host ""
