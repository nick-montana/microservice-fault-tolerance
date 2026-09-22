# Calls a random backendA endpoint every 2 seconds for 3 hours.
# Run from PowerShell:  .\scripts\load-backendA-success.ps1
# Stop early with Ctrl+C.

$baseUrl  = "http://localhost:9080/backendA"
$duration = [TimeSpan]::FromHours(3)
$pause    = 2

# Endpoint -> relative weight. Each loop picks one at random in proportion to its weight.
# Equal weights = each endpoint gets ~25% of calls; raise "success" to send more business events.
$endpoints = [ordered]@{
    "success"          = 1
    "failure"          = 1
    "ignore"           = 1
    "successException" = 1
}

# Expand the weights into a pick list, e.g. success=3 puts "success" in the list 3 times
$pickList = foreach ($name in $endpoints.Keys) { ,$name * $endpoints[$name] }

$stats = @{}
foreach ($name in $endpoints.Keys) { $stats[$name] = @{ Ok = 0; Error = 0 } }

$end = (Get-Date) + $duration
Write-Host "Calling random endpoints under $baseUrl every $pause s until $($end.ToString('HH:mm:ss'))"

while ((Get-Date) -lt $end) {
    $name = Get-Random -InputObject $pickList
    $url  = "$baseUrl/$name"
    $time = (Get-Date).ToString('HH:mm:ss')
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10
        $stats[$name].Ok++
        Write-Host "$time  $($response.StatusCode)  /$name  $($response.Content)"
    } catch {
        $stats[$name].Error++
        # failure / ignore / successException return 4xx/5xx on purpose, so show the status code
        $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { "ERR" }
        Write-Host "$time  $status  /$name  $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Seconds $pause
}

Write-Host "`nDone."
foreach ($name in $endpoints.Keys) {
    Write-Host ("{0,-18} ok: {1,6}   error: {2,6}" -f "/$name", $stats[$name].Ok, $stats[$name].Error)
}
