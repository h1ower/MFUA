# ============================================
# MFUA Git Repository Sync Script (PowerShell)
# ============================================

# ------------------- НАСТРОЙКИ -------------------
$SOURCE_REPO = "D:\MFUA\repos\mfua-staging\core-engine"
$TARGET_REPO = "E:\MFUA\deploy\mfua-production\live-site"
$DO_PUSH = $true
$CHECK_PRIVATE = $true
# ============================================

$RED = "Red"
$GREEN = "Green"
$YELLOW = "Yellow"
$BLUE = "Cyan"

function Log-Info { Write-Host "[INFO] $args" -ForegroundColor $BLUE }
function Log-Success { Write-Host "[SUCCESS] $args" -ForegroundColor $GREEN }
function Log-Error { Write-Host "[ERROR] $args" -ForegroundColor $RED }
function Log-Warning { Write-Host "[WARNING] $args" -ForegroundColor $YELLOW }

function Test-RepoPath {
    param($Path, $Name)
    if (-not (Test-Path $Path)) {
        Log-Error "$Name не существует: $Path"
        return $false
    }
    if (-not (Test-Path "$Path\.git")) {
        Log-Error "$Name не является Git-репозиторием: $Path"
        return $false
    }
    Log-Success "$Name найден: $Path"
    return $true
}

function Test-PrivateRepo {
    param($Path)
    Push-Location $Path
    $url = git config --get remote.origin.url 2>$null
    Pop-Location
    if ($url -like "*private*" -or $url -like "*mfua-internal*") {
        Log-Warning "Приватный репозиторий: $url"
        $answer = Read-Host "Продолжить? (y/n)"
        return ($answer -eq "y" -or $answer -eq "Y")
    }
    return $true
}

function Invoke-GitPull {
    param($Path)
    Push-Location $Path
    Log-Info "Выполняется git pull в $(Split-Path $Path -Leaf)..."
    git fetch origin 2>&1 | Out-Null
    $localHash = git rev-parse HEAD 2>$null
    $branch = git branch --show-current 2>$null
    $remoteHash = git rev-parse "origin/$branch" 2>$null
    if ($localHash -ne $remoteHash) {
        git pull 2>&1
        if ($LASTEXITCODE -eq 0) { Log-Success "Pull выполнен" }
        else { Log-Error "Ошибка pull"; Pop-Location; return $false }
    } else {
        Log-Info "Нет изменений"
    }
    Pop-Location
    return $true
}

function Copy-RepoContent {
    param($Source, $Target)
    Log-Info "Копирование из $Source в $Target (исключая .git)..."
    Get-ChildItem -Path $Target -Exclude ".git" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $Source -Exclude ".git" | ForEach-Object {
        $dest = Join-Path $Target $_.Name
        if ($_.PSIsContainer) { Copy-Item -Path $_.FullName -Destination $dest -Recurse -Force }
        else { Copy-Item -Path $_.FullName -Destination $dest -Force }
    }
    Get-ChildItem -Path $Source -Force | Where-Object { $_.Name -like ".*" -and $_.Name -ne ".git" } | ForEach-Object {
        $dest = Join-Path $Target $_.Name
        if ($_.PSIsContainer) { Copy-Item -Path $_.FullName -Destination $dest -Recurse -Force }
        else { Copy-Item -Path $_.FullName -Destination $dest -Force }
    }
    Log-Success "Копирование завершено"
}

function Invoke-GitPush {
    param($Path)
    Push-Location $Path
    Log-Info "Выполняется git push в $(Split-Path $Path -Leaf)..."
    $branch = git branch --show-current 2>$null
    git push origin $branch 2>&1
    if ($LASTEXITCODE -eq 0) { Log-Success "Push выполнен" }
    else { Log-Error "Ошибка push" }
    Pop-Location
}

# Основной блок
Write-Host "========================================="
Write-Host "   MFUA Git Sync Script (PowerShell)"
Write-Host "========================================="

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Log-Error "Git не установлен"; exit 1
}

if (-not (Test-RepoPath -Path $SOURCE_REPO -Name "Исходный MFUA")) { exit 1 }
if (-not (Test-RepoPath -Path $TARGET_REPO -Name "Целевой MFUA")) { exit 1 }

if ($CHECK_PRIVATE -and -not (Test-PrivateRepo -Path $SOURCE_REPO)) { exit 1 }

Write-Host ""
if (-not (Invoke-GitPull -Path $SOURCE_REPO)) { exit 1 }

Write-Host ""
Copy-RepoContent -Source $SOURCE_REPO -Target $TARGET_REPO

if ($DO_PUSH) {
    Write-Host ""
    Invoke-GitPush -Path $TARGET_REPO
}

Write-Host ""
Log-Success "Синхронизация MFUA завершена!"