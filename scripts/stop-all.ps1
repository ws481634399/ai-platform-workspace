# 一键停止后端开发环境：微服务进程 -> （可选）前端 -> （可选）基础设施(Docker)
# 与 start-all.ps1 配套；默认只停 Java 微服务，Docker 基础设施保留运行。
# 用法（在仓库根目录执行）:
#   .\scripts\stop-all.ps1              # 停止全部 9 个后端微服务（不动 IDE 的 Java 语言服务器）
#   .\scripts\stop-all.ps1 -Core        # 只停最小可用集: identity/product/gateway
#   .\scripts\stop-all.ps1 -Frontend    # 顺带停止 mall-admin(5173) / mall-web(5174) Vite 开发服务器
#   .\scripts\stop-all.ps1 -Infra       # 顺带 docker compose down 停止 MySQL/Redis/Nacos/MinIO
#   .\scripts\stop-all.ps1 -All         # 全部停止：微服务 + 前端 + 基础设施
param(
    [switch]$Core,
    [switch]$Frontend,
    [switch]$Infra,
    [switch]$All
)

$Root    = Split-Path $PSScriptRoot -Parent
$Backend = Join-Path $Root 'implementation\ai-platform-backend'

if ($All) { $Frontend = $true; $Infra = $true }

# ---- 服务清单：名称 / 端口 / jar 相对路径（与 start-all.ps1 保持一致）----
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

# ================ [1/3] 后端微服务 ================
Write-Host '==> [1/3] 后端微服务'
$stopped = 0
# 按命令行精确匹配本项目 jar（-jar ...ai-platform-backend...），避免误杀 IDE 的 Java 语言服务器等无关进程
$mallProcs = Get-CimInstance Win32_Process -Filter "name='java.exe' OR name='javaw.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'ai-platform-backend.*\.jar' }

foreach ($t in $targets) {
    # 优先按本服务 jar 文件名匹配进程；再兜底按端口查占用者（覆盖 jar 改名等情况）
    $jarName = Split-Path $t.Jar -Leaf
    $proc = $mallProcs | Where-Object { $_.CommandLine -match [regex]::Escape($jarName) } | Select-Object -First 1
    if (-not $proc) {
        $ownerPid = (Get-NetTCPConnection -State Listen -LocalPort $t.Port -ErrorAction SilentlyContinue |
            Select-Object -First 1).OwningProcess
        if ($ownerPid) { $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$ownerPid" -ErrorAction SilentlyContinue }
    }
    if ($proc) {
        Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
        Write-Host "    $($t.Name): 已停止 (PID $($proc.ProcessId))"
        $stopped++
    } else {
        Write-Host "    $($t.Name): 未运行，跳过"
    }
}
if ($stopped -eq 0) { Write-Host '    没有正在运行的后端微服务' }

# ================ [2/3] 前端 Vite（可选） ================
Write-Host '==> [2/3] 前端 (Vite)'
if ($Frontend) {
    foreach ($port in 5173, 5174) {
        $name = if ($port -eq 5173) { 'mall-admin' } else { 'mall-web' }
        $ownerPid = (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue |
            Select-Object -First 1).OwningProcess
        if ($ownerPid) {
            Stop-Process -Id $ownerPid -Force -ErrorAction SilentlyContinue
            Write-Host "    ${name}: 已停止 (PID $ownerPid, :$port)"
        } else {
            Write-Host "    ${name}: 未运行，跳过"
        }
    }
} else {
    Write-Host '    跳过（加 -Frontend 或 -All 同时停止 mall-admin/mall-web）'
}

# ================ [3/3] 基础设施 Docker（可选） ================
Write-Host '==> [3/3] 基础设施 (Docker)'
if ($Infra) {
    $Infra    = Join-Path $Root 'implementation\ai-platform-infrastructure\deploy\docker-compose.infra.yml'
    $InfraEnv = Join-Path $Root 'implementation\ai-platform-infrastructure\deploy\.env'
    docker compose --env-file $InfraEnv -f $Infra down 2>&1 | ForEach-Object { Write-Host "    $_" }
} else {
    Write-Host '    保留运行（加 -Infra 或 -All 同时停止 MySQL/Redis/Nacos/MinIO 容器）'
}

Write-Host ''
Write-Host '================ 停止完成 ================'
