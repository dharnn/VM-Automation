$ErrorActionPreference = "Stop"

$VBM = Join-Path $env:ProgramFiles "Oracle\VirtualBox\VBoxManage.exe"
if (-not (Test-Path $VBM)) { throw "VBoxManage not found at $VBM" }

# ---------- 1. Measure the host ----------
$os          = Get-CimInstance Win32_OperatingSystem
$logicalCpus = (Get-CimInstance Win32_Processor | Measure-Object NumberOfLogicalProcessors -Sum).Sum
$totalMB     = [math]::Floor($os.TotalVisibleMemorySize / 1024)
$availMB     = [math]::Floor((Get-Counter '\Memory\Available MBytes').CounterSamples[0].CookedValue)
$vmDrive     = Get-PSDrive ($env:USERPROFILE.Substring(0, 1))
$freeDiskGB  = [math]::Floor($vmDrive.Free / 1GB)

# ---------- 2. Work out safe limits ----------
$reserveMB = [math]::Max(4096, [math]::Floor($totalMB * 0.25))       # always leave the host this much
$ramLimit  = [math]::Min($totalMB - $reserveMB, $availMB - 1024)
$maxRam    = [math]::Floor($ramLimit / 256) * 256
$minRam    = 1024
if ($maxRam -lt $minRam) { throw "Only $availMB MB of RAM is available. Close some programs or stop other VMs and try again." }
if ($freeDiskGB -lt 10)  { throw "Only $freeDiskGB GB free on drive $($vmDrive.Name). Free up space first." }

$maxCpu = [math]::Max(1, [math]::Floor($logicalCpus / 2))            # never more than half the host's CPUs

$recRamLow  = [math]::Min(1024, $maxRam)
$recRamHigh = [math]::Min(2048, $maxRam)
$recCpuHigh = [math]::Min(2, $maxCpu)

Write-Host ""
Write-Host "Your PC:  $([math]::Round($totalMB/1024,1)) GB RAM ($([math]::Round($availMB/1024,1)) GB free now), $logicalCpus logical CPUs, $freeDiskGB GB free disk"
Write-Host "Safe limits for ONE VM:"
Write-Host "  RAM : $minRam - $maxRam MB   (recommended $recRamLow - $recRamHigh MB for a light Ubuntu server)"
Write-Host "  CPUs: 1 - $maxCpu            (recommended 1 - $recCpuHigh)"
Write-Host ""

# ---------- 3. Helper: ask for a number until it is valid ----------
function Read-Number($Prompt, $Min, $Max, $Default) {
  while ($true) {
    $raw = Read-Host "$Prompt [$Min-$Max, Enter = $Default]"
    if ([string]::IsNullOrWhiteSpace($raw)) { return $Default }
    $n = 0
    if ([int]::TryParse($raw, [ref]$n) -and $n -ge $Min -and $n -le $Max) { return $n }
    Write-Host "  Enter a whole number from $Min to $Max." -ForegroundColor Yellow
  }
}

# ---------- 4. Ask the questions ----------
$existing = & $VBM list vms | ForEach-Object { if ($_ -match '^"(.+)" \{') { $Matches[1] } }
while ($true) {
  $name = Read-Host "VM name (lowercase letters, numbers, hyphens)"
  if ($name -notmatch '^[a-z][a-z0-9-]{1,28}[a-z0-9]$') {
    Write-Host "  3-30 characters, start with a letter, only a-z, 0-9 and -." -ForegroundColor Yellow; continue
  }
  if ($existing -contains $name) {
    Write-Host "  A VirtualBox VM called '$name' already exists." -ForegroundColor Yellow; continue
  }
  break
}
$cpus = Read-Number "CPUs"   1       $maxCpu $recCpuHigh
$ram  = Read-Number "RAM in MB" $minRam $maxRam $recRamLow

# ---------- 5. Confirm and save ----------
Write-Host ""
Write-Host "About to create: $name, $cpus CPU(s), $ram MB RAM"
if ($ram -gt $recRamHigh) { Write-Host "(above the recommended range, fine for heavy workloads)" }
if ((Read-Host "Continue? (y/n)") -ne "y") { Write-Host "Cancelled."; exit }

@{ name = $name; cpus = $cpus; memory = $ram } | ConvertTo-Json |
  Set-Content -Encoding ascii (Join-Path $PSScriptRoot "vm.json")

Push-Location $PSScriptRoot
try { vagrant up } finally { Pop-Location }