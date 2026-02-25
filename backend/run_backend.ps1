$ErrorActionPreference = "Stop"

$envFile = Join-Path $PSScriptRoot "env"
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line.Length -eq 0 -or $line.StartsWith("#")) {
      return
    }
    Invoke-Expression $line
  }
}

Set-Location $PSScriptRoot
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
