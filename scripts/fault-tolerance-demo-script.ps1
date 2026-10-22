# Calls a random endpoint every 2 seconds for 3 hours.
# Success endpoints always go to backendA; failure endpoints go to the backend you pick at startup.
# Run from PowerShell:  .\scripts\fault-tolerance-demo-script.ps1
# Stop early with Ctrl+C.

$gatewayUrl = "http://localhost:9080"
$successBackend = "backendA"
$duration = [TimeSpan]::FromHours(3)
$pause    = 2

# Endpoints expected to return 2xx
$success_endpoints = @(
    "success"
    "ignore"
    "monoSuccess"
    "fluxSuccess"
    "fallback"
)

# Endpoints that fail, time out or throw on purpose
$failure_endpoints = @(
    "failure"
    "futureFailure"
    "futureTimeout"
    "successException"
    "monoFailure"
    "fluxFailure"
)

# Ask which backend should receive the failure requests
$backends = @("backendA", "backendB", "backendC")
$failureBackend = $null
while (-not $failureBackend) {
    Write-Host "Which backend should receive the failure requests?"
    for ($i = 0; $i -lt $backends.Count; $i++) {
        Write-Host ("  {0}) {1}" -f ($i + 1), $backends[$i])
    }
    $choice = (Read-Host "Enter 1-$($backends.Count) or a backend name").Trim()
    if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $backends.Count) {
        $failureBackend = $backends[[int]$choice - 1]
    } else {
        $failureBackend = $backends | Where-Object { $_ -ieq $choice } | Select-Object -First 1
        if (-not $failureBackend) { Write-Host "'$choice' is not a valid option.`n" -ForegroundColor Yellow }
    }
}

# Build the pick list: each entry is a full path like "backendA/success"
$pickList  = @($success_endpoints | ForEach-Object { "$successBackend/$_" })
$pickList += @($failure_endpoints | ForEach-Object { "$failureBackend/$_" })

$stats = [ordered]@{}
foreach ($path in $pickList) { $stats[$path] = @{ Ok = 0; Error = 0 } }

$end = (Get-Date) + $duration
Write-Host "`nSuccess requests -> $gatewayUrl/$successBackend"
Write-Host "Failure requests -> $gatewayUrl/$failureBackend"
Write-Host "Calling a random endpoint every $pause s until $($end.ToString('HH:mm:ss'))`n"

while ((Get-Date) -lt $end) {
    $path = Get-Random -InputObject $pickList
    $url  = "$gatewayUrl/$path"
    $time = (Get-Date).ToString('HH:mm:ss')
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10
        $stats[$path].Ok++
        Write-Host "$time  $($response.StatusCode)  /$path  $($response.Content)"
    } catch {
        $stats[$path].Error++
        # Failure endpoints return 4xx/5xx on purpose, so show the status code
        $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { "ERR" }
        Write-Host "$time  $status  /$path  $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Seconds $pause
}

Write-Host "`nDone."
foreach ($path in $stats.Keys) {
    Write-Host ("{0,-28} ok: {1,6}   error: {2,6}" -f "/$path", $stats[$path].Ok, $stats[$path].Error)
}
