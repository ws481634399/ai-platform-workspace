# 一键启动开发环境：基础设施(Docker) → 后端微服务 → 网关 → 前端
# 用法（在仓库根目录执行）:
#   .\scripts\start-all.ps1              # 全部 8 个微服务 + 网关 + 2 个前端
#   .\scripts\start-all.ps1 -Core        # 最小可用集: identity/product/gateway + 前端
#   .\scripts\start-all.ps1 -NoFrontend  # 不启动前端
#   .\scripts\start-all.ps1 -Build       # 启动前先执行 mvn clean package -DskipTests
# 已在运行的组件自动跳过，可重复执行。
param(
    [switch]$Core,
    [switch]$NoFrontend,
    [switch]$Build
)

$Root     = Split-Path $PSScriptRoot -Parent
$Backend  = Join-Path $Root 'implementation\ai-platform-backend'
$Frontend = Join-Path $Root 'implementation\ai-platform-frontend'
$LogDir   = Join-Path $Root 'logs'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

# ---- 环境变量（子进程继承；已设置的系统环境变量优先生效）----
if (-not $env:MYSQL_PASSWORD) { $env:MYSQL_PASSWORD = '123456' }
$beUri = ($Backend -replace '\\', '/')
$env:JWT_PUBLIC_KEY_LOCATION  = "file:///$beUri/local-keys/jwt-public.pem"
$env:JWT_PRIVATE_KEY_LOCATION = "file:///$beUri/local-keys/jwt-private.pem"

# ---- 服务清单：名称 / 端口 / jar 相对路径 ----
$targets = @(
    @{ Name = 'mall-identity';  Port = 8101; Jar = 'mall-services\mall-identity\target\mall-identity-1.0.0-SNAPSHOT.jar' },
    @{ Name = 'mall-member';    Port = 8102; Jar = 'mall-services\mall-member\target\mall-member-1.0.0-SNAPSHOT.jar' },
    @{ Name = 'mall-product';   Port = 8103; Jar = 'mall-services\mall-product\target\mall-product-1.0.0-SNAPSHOT.jar' },
    @{ Name = 'mall-cart';      Port = 8104; Jar = 'mall-services\mall-cart\target\mall-cart-1.0.0-SNAPSHOT.jar' },
    @{ Name = 'mall-order';     Port = 8105; Jar = 'mall-services\mall-order\target\mall-order-1.0.0-SNAPSHOT.jar' },
    @{ Name = 'mall-inventory'; Port = 8106; Jar = 'mall-services\mall-inventory\target\mall-inventory-1.0.0-SNAPSHOT.jar' },
    @{ Name = 'mall-search';    Port = 8107; Jar = 'mall-services\mall-search\target\mall-search-1.0.0-SNAPSHOT.jar' },
    @{ Name = 'mall-system';    Port = 8108; Jar = 'mall-services\mall-system\target\mall-system-1.0.0-SNAPSHOT.jar' },
    @{ Name = 'mall-gateway';   Port = 8080; Jar = 'mall-gateway\target\mall-gateway-1.0.0-SNAPSHOT.jar' }
)
if ($Core) {
    $targets = $targets | Where-Object { $_.Name -in @('mall-identity', 'mall-product', 'mall-gateway') }
}

function Test-Port([int]$Port) {
    $c = New-Object System.Net.Sockets.TcpClient
    try { return $c.ConnectAsync('127.0.0.1', $Port).Wait(300) -and $c.Connected }
    catch { return $false }
    finally { $c.Dispose() }
}

function Wait-Port([int]$Port, [int]$Seconds = 60) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-Port $Port) { return $true }
        Start-Sleep -Milliseconds 800
    }
    return $false
}

# ================ [1/4] 基础设施 ================
Write-Host '==> [1/4] 基础设施 (Docker: MySQL 3306 / Redis 6379)'
$Infra = Join-Path $Root 'implementation\ai-platform-infrastructure\deploy\docker-compose.infra.yml'
if ((Test-Port 3306) -and (Test-Port 6379)) {
    Write-Host '    已在运行，跳过'
} else {
    docker compose -f $Infra up -d 2>&1 | ForEach-Object { Write-Host "    $_" }
}
foreach ($p in 3306, 6379) {
    if (Wait-Port $p 60) { Write-Host "    端口 $p 就绪" }
    else { Write-Warning "    端口 $p 未就绪，后端服务可能启动失败" }
}

# ================ [2/4] 构建（可选） ================
if ($Build) {
    Write-Host '==> [2/4] Maven 构建 (clean package -DskipTests)'
    Push-Location $Backend
    try { mvn clean package -DskipTests }
    finally { Pop-Location }
} else {
    Write-Host '==> [2/4] 跳过构建（jar 缺失时请加 -Build 参数）'
}

# ================ [3/4] 后端微服务 ================
Write-Host '==> [3/4] 后端微服务'
$started = @()
foreach ($t in $targets) {
    $jar = Join-Path $Backend $t.Jar
    if (-not (Test-Path $jar)) { Write-Host "    $($t.Name): JAR 缺失，跳过（先加 -Build 构建）"; continue }
    if (Test-Port $t.Port)    { Write-Host "    $($t.Name): 已在运行 (:$( $t.Port ))，跳过"; continue }
    $out = Join-Path $LogDir "$($t.Name).log"
    $err = Join-Path $LogDir "$($t.Name).err.log"
    Start-Process java -ArgumentList @('-jar', "`"$jar`"") -WorkingDirectory $Backend `
        -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err -PassThru | Out-Null
    $started += $t
    Write-Host "    $($t.Name): 启动中 (:$( $t.Port ))  日志 logs\$($t.Name).log"
}

# 统一等待所有新启动端口就绪
if ($started.Count -gt 0) {
    Write-Host '    等待服务就绪（最长 120 秒）...'
    $deadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $deadline) {
        $pending = @($started | Where-Object { -not (Test-Port $_.Port) })
        if ($pending.Count -eq 0) { break }
        Start-Sleep -Milliseconds 1500
    }
}

# ================ [4/4] 前端 (Vite) ================
$frontends = @()
if (-not $NoFrontend) {
    Write-Host '==> [4/4] 前端 (Vite)'
    $frontends = @(
        @{ Name = 'mall-admin'; Port = 5173 },
        @{ Name = 'mall-web';   Port = 5174 }
    )
    foreach ($f in $frontends) {
        if (Test-Port $f.Port) { Write-Host "    $($f.Name): 已在运行 (:$( $f.Port ))，跳过"; continue }
        $dir = Join-Path $Frontend $f.Name
        $out = Join-Path $LogDir "$($f.Name).log"
        $err = Join-Path $LogDir "$($f.Name).err.log"
        try {
            Start-Process pnpm.cmd -ArgumentList @('exec', 'vite', '--port', "$($f.Port)", '--strictPort') `
                -WorkingDirectory $dir -WindowStyle Hidden `
                -RedirectStandardOutput $out -RedirectStandardError $err -PassThru | Out-Null
            Write-Host "    $($f.Name): 启动中 (:$( $f.Port ))  日志 logs\$($f.Name).log"
        } catch {
            Write-Warning "    $($f.Name): 启动失败（$($_.Exception.Message)），请手动在该目录执行 pnpm dev"
        }
    }
    Start-Sleep -Seconds 5
}

# ================ 汇总 ================
Write-Host ''
Write-Host '================ 启动结果 ================'
foreach ($t in $targets) {
    $ok = Test-Port $t.Port
    $status = if ($ok) { '运行中' } else { "未就绪（查 logs\$($t.Name).log）" }
    $color  = if ($ok) { 'Green' } else { 'Red' }
    Write-Host ("  {0,-14} :{1,-6} {2}" -f $t.Name, $t.Port, $status) -ForegroundColor $color
}
foreach ($f in $frontends) {
    $ok = Test-Port $f.Port
    $status = if ($ok) { '运行中' } else { '未就绪' }
    $color  = if ($ok) { 'Green' } else { 'Red' }
    Write-Host ("  {0,-14} :{1,-6} {2}" -f $f.Name, $f.Port, $status) -ForegroundColor $color
}
Write-Host ''
Write-Host "管理后台: http://localhost:5173   商城端: http://localhost:5174"
Write-Host "运行日志: $LogDir"
