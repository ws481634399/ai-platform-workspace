[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Action,

    [string]$Service,

    [switch]$Follow
)

$ErrorActionPreference = 'Stop'
$deployDirectory = Split-Path -Parent $PSScriptRoot
$composeFile = Join-Path $deployDirectory 'docker-compose.infra.yml'
$envFile = Join-Path $deployDirectory '.env'
$serviceNames = @('mysql', 'redis', 'nacos', 'minio')

function Write-DockerCommand {
    param([string[]]$Arguments)
    Write-Host ('> docker ' + ($Arguments -join ' '))
}

function Invoke-Docker {
    param([string[]]$Arguments)
    Write-DockerCommand -Arguments $Arguments
    & docker @Arguments | Out-Host
    $dockerExitCode = $LASTEXITCODE
    return [int]$dockerExitCode
}

function Get-ComposeArguments {
    return @('compose', '--env-file', $envFile, '-f', $composeFile)
}

function Test-InfrastructureHealth {
    param([string[]]$Names)

    $timeoutSeconds = if ($env:INFRA_HEALTH_TIMEOUT_SECONDS) {
        [int]$env:INFRA_HEALTH_TIMEOUT_SECONDS
    } else {
        180
    }
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)
    $unhealthyNames = @()
    $shownCommands = @{}

    do {
        $unhealthyNames = @()
        foreach ($name in $Names) {
            $baseArguments = Get-ComposeArguments
            if (-not $shownCommands.ContainsKey($name)) {
                Write-DockerCommand -Arguments ($baseArguments + @('ps', '-q', $name))
            }
            $containerId = (& docker @baseArguments ps -q $name 2>$null | Select-Object -First 1)
            if (-not $containerId) {
                $unhealthyNames += $name
                continue
            }

            if (-not $shownCommands.ContainsKey($name)) {
                Write-DockerCommand -Arguments @('inspect', '--format', '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}', $containerId)
                $shownCommands[$name] = $true
            }
            $status = (& docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' $containerId 2>$null)
            if ($status -ne 'healthy') {
                $unhealthyNames += $name
            }
        }

        if ($unhealthyNames.Count -eq 0) {
            Write-Host ('Healthy services: ' + ($Names -join ', '))
            return 0
        }

        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)

    Write-Error ('Health timeout. Unhealthy services: ' + ($unhealthyNames -join ', ')) -ErrorAction Continue
    $baseArguments = Get-ComposeArguments
    [void](Invoke-Docker -Arguments ($baseArguments + @('ps')))
    foreach ($name in $unhealthyNames) {
        [void](Invoke-Docker -Arguments ($baseArguments + @('logs', '--tail', '50', $name)))
    }
    return 1
}

$validActions = @('start', 'stop', 'restart', 'status', 'health', 'logs')
if ($Action -notin $validActions) {
    [Console]::Error.WriteLine("Invalid action '$Action'. Expected: $($validActions -join ', ').")
    exit 2
}

$validServices = @('mysql', 'redis', 'nacos', 'minio')
if ($Service -and $Service -notin $validServices) {
    [Console]::Error.WriteLine("Invalid service '$Service'. Expected: $($validServices -join ', ').")
    exit 2
}

if ($Service -and $Action -in @('start', 'stop')) {
    [Console]::Error.WriteLine("Action '$Action' does not accept -Service.")
    exit 2
}

if ($Follow -and $Action -ne 'logs') {
    [Console]::Error.WriteLine("-Follow is only valid with action 'logs'.")
    exit 2
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine('Docker CLI was not found. Install Docker Desktop or Docker Engine first.')
    exit 1
}

if (-not (Test-Path -LiteralPath $envFile)) {
    [Console]::Error.WriteLine("Missing $envFile. Copy .env.example to .env and adjust local values.")
    exit 2
}

$composeArguments = Get-ComposeArguments
$selectedServices = if ($Service) { @($Service) } else { $serviceNames }
$exitCode = 0

switch ($Action) {
    'start' {
        $exitCode = Invoke-Docker -Arguments ($composeArguments + @('up', '-d'))
        if ($exitCode -eq 0) {
            $exitCode = Invoke-Docker -Arguments ($composeArguments + @('ps'))
        }
    }
    'stop' {
        $exitCode = Invoke-Docker -Arguments ($composeArguments + @('down'))
    }
    'restart' {
        $arguments = $composeArguments + @('restart')
        if ($Service) { $arguments += $Service }
        $exitCode = Invoke-Docker -Arguments $arguments
    }
    'status' {
        $arguments = $composeArguments + @('ps')
        if ($Service) { $arguments += $Service }
        $exitCode = Invoke-Docker -Arguments $arguments
    }
    'health' {
        $exitCode = Test-InfrastructureHealth -Names $selectedServices
    }
    'logs' {
        $arguments = $composeArguments + @('logs')
        if ($Follow) { $arguments += '--follow' }
        if ($Service) { $arguments += $Service }
        $exitCode = Invoke-Docker -Arguments $arguments
    }
}

exit $exitCode
