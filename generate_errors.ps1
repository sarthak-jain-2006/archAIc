Write-Host "=========================================="
Write-Host " Starting Chaos Experiment for AI-Ops     "
Write-Host "=========================================="

# 1. Start injecting errors
Write-Host "[1/3] Injecting 50% Error Rate on DB Service (30s duration)..."
curl.exe -s -X POST "http://localhost:8002/inject-failure?type=error&probability=0.5&duration=30" | Out-Null

Write-Host "[2/3] Injecting Latency on Auth Service (30s duration)..."
curl.exe -s -X POST "http://localhost:8001/inject-failure?type=timeout&intensity=2&probability=0.5&duration=30" | Out-Null

# 2. Generate some traffic to ensure Prometheus scrapes the metrics
Write-Host "[3/3] Generating traffic to trigger metrics & alerts..."
Write-Host "Sending requests to Product Service..."
for ($i=1; $i -le 20; $i++) {
    $result = curl.exe -s -o NUL -w " Request $i -> HTTP %{http_code}`n" http://localhost:8003/health
    Write-Host $result
    Start-Sleep -Seconds 1
}

Write-Host ""
Write-Host "=========================================="
Write-Host " Failures injected and traffic generated! "
Write-Host "=========================================="
Write-Host "Check Prometheus/Alertmanager UI or run the following to see the AI in action:"
Write-Host "  kubectl logs -f deployment/anomaly-detector -n archaics"
Write-Host "  kubectl logs -f deployment/ai-operator -n archaics"
