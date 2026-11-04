param([switch]$Rebuild, [switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$logRoot = Join-Path $projectRoot '.runlogs'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null

function Test-LocalPort([int]$Port) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $task = $client.ConnectAsync('127.0.0.1', $Port)
        return ($task.Wait(400) -and $client.Connected)
    } catch { return $false } finally { $client.Dispose() }
}

function Start-LocalService([string]$Label, [int]$Port, [string]$Executable, [string[]]$Arguments, [string]$Directory) {
    if (Test-LocalPort $Port) {
        Write-Host "$Label already running on port $Port"
        return
    }
    $stdout = Join-Path $logRoot "$Port.out.log"
    $stderr = Join-Path $logRoot "$Port.err.log"
    $process = Start-Process -FilePath $Executable -ArgumentList $Arguments -WorkingDirectory $Directory -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    $deadline = (Get-Date).AddSeconds(60)
    while ((Get-Date) -lt $deadline) {
        if (Test-LocalPort $Port) { Write-Host "$Label ready on port $Port"; return }
        if ($process.HasExited) { throw "$Label stopped. Check $stderr. For backend, make sure MySQL is running." }
        Start-Sleep -Milliseconds 500
    }
    throw "$Label startup timed out. Check $stderr"
}

try {
    $python = Join-Path $projectRoot 'ai_service\.venv\Scripts\python.exe'
    if (!(Test-Path -LiteralPath $python)) { throw "Python environment missing: $python" }
    $node = (Get-Command node.exe -ErrorAction Stop).Source
    $webRoot = Join-Path $projectRoot 'flutter_app'
    $compiled = Join-Path $webRoot 'build\web\main.dart.js'
    if ($Rebuild -or !(Test-Path -LiteralPath $compiled)) {
        $flutter = Get-Command flutter -ErrorAction SilentlyContinue
        $sdk = if ($flutter) { Split-Path (Split-Path $flutter.Source -Parent) -Parent } else { 'C:\flutter' }
        $dart = Join-Path $sdk 'bin\cache\dart-sdk\bin\dart.exe'
        if (!(Test-Path -LiteralPath $dart)) { throw 'Flutter SDK not found. Add Flutter to PATH.' }
        Push-Location $webRoot
        try {
            & $dart "--packages=$sdk/packages/flutter_tools/.dart_tool/package_config.json" "$sdk/bin/cache/flutter_tools.snapshot" build web --release --no-web-resources-cdn --no-wasm-dry-run --dart-define=AI_BASE_URL=http://127.0.0.1:18002 --dart-define=API_BASE_URL=http://127.0.0.1:5000
            if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed.' }
        } finally { Pop-Location }
    }
    Start-LocalService 'Backend' 5000 $node @('server.js') (Join-Path $projectRoot 'backend')
    Start-LocalService 'AI' 18002 $python @('-m','uvicorn','app:app','--host','127.0.0.1','--port','18002') (Join-Path $projectRoot 'ai_service')
    Start-LocalService 'Web' 8766 $python @('tool/serve_preview.py') $webRoot
    Write-Host ''
    Write-Host 'Nail Virtual: http://127.0.0.1:8766/' -ForegroundColor Green
    Write-Host "Logs: $logRoot"
    if (!$NoBrowser) { Start-Process 'http://127.0.0.1:8766/' }
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
