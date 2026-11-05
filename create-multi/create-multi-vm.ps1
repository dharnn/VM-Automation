
$ErrorActionPreference = "Stop"

# 1. Check required software

$VBM = Join-Path $env:ProgramFiles "Oracle\VirtualBox\VBoxManage.exe"

if (-not (Test-Path $VBM)) {
    throw "VirtualBox is not installed or VBoxManage.exe was not found."
}

if (-not (Get-Command vagrant -ErrorAction SilentlyContinue)) {
    throw "Vagrant is not installed or is not available in PATH."
}

if (-not (Test-Path (Join-Path $PSScriptRoot "Vagrantfile"))) {
    throw "Vagrantfile is missing from the multi-vm folder."
}

# Protect existing Vagrant environments
$configPath = Join-Path $PSScriptRoot "vm.json"

if ((Test-Path $configPath) -or
    (Test-Path (Join-Path $PSScriptRoot ".vagrant"))) {
    throw "An existing VM configuration was found. Use a fresh folder."
}


# 2. Function to validate numerical input

function Read-Number($Prompt, $Min, $Max, $Default) {

    while ($true) {

        $inputValue = Read-Host "$Prompt [$Min-$Max, Enter=$Default]"

        if ([string]::IsNullOrWhiteSpace($inputValue)) {
            return $Default
        }

        $number = 0

        if ([int]::TryParse($inputValue, [ref]$number) -and
            $number -ge $Min -and
            $number -le $Max) {

            return $number
        }

        Write-Host "Enter a number between $Min and $Max." -ForegroundColor Yellow
    }
}


# 3. Check Windows host resources

$os = Get-CimInstance Win32_OperatingSystem

$logicalCpus = [int](
    (Get-CimInstance Win32_Processor |
    Measure-Object NumberOfLogicalProcessors -Sum).Sum
)

$totalRam = [int][math]::Floor(
    $os.TotalVisibleMemorySize / 1024
)

$availableRam = [int][math]::Floor(
    $os.FreePhysicalMemory / 1024
)

$projectDrive = (Get-Item $PSScriptRoot).PSDrive

$freeDiskGB = [int][math]::Floor(
    $projectDrive.Free / 1GB
)


# 4. Calculate resource allocation limits

$cpuBudget = [int][math]::Max(
    1, [math]::Floor($logicalCpus / 2)
)

$reservedRam = [math]::Max(
    4096, [math]::Floor($totalRam * 0.25)
)

$ramBudget = [int](
    [math]::Floor(
        [math]::Min(
            ($totalRam - $reservedRam),
            ($availableRam - 1024)
        ) / 256
    ) * 256
)

# Planning allowance: 10 GB per VM
$diskPerVm = 10

# Reserve 10 GB of free disk space
$diskReserve = 10

$maxCount = [int][math]::Min(
    $cpuBudget,
    [math]::Min(
        [math]::Floor($ramBudget / 1024),
        [math]::Floor(($freeDiskGB - $diskReserve) / $diskPerVm)
    )
)

if ($maxCount -lt 1) {
    throw "Insufficient CPU, RAM, or disk space for VM deployment."
}

Write-Host ""
Write-Host "HOST RESOURCE INFORMATION" -ForegroundColor Cyan
Write-Host "Logical CPUs: $logicalCpus"
Write-Host "Total RAM: $totalRam MB"
Write-Host "Available RAM: $availableRam MB"
Write-Host "Free project-drive space: $freeDiskGB GB"
Write-Host "Planning limit: $maxCount VM(s)"
Write-Host ""


# 5. Ask how many VMs to create

$vmCount = Read-Number "How many VMs do you want to create?" 1 $maxCount 1


# 6. Find existing VirtualBox VM names

$existingVMs = @(
    & $VBM list vms | ForEach-Object {
        if ($_ -match '^"(.+)"\s+\{') {
            $Matches[1]
        }
    }
)

if ($LASTEXITCODE -ne 0) {
    throw "Unable to retrieve existing VirtualBox machines."
}


# 7. Collect configuration for each VM

$vms = @()

$usedCpu = 0
$usedRam = 0

for ($i = 1; $i -le $vmCount; $i++) {

    Write-Host ""
    Write-Host "CONFIGURING VM $i OF $vmCount" -ForegroundColor Cyan

    # Validate the VM name
    while ($true) {

        $name = (Read-Host "Enter VM name").Trim()

        if ($name -cnotmatch '^[a-z][a-z0-9-]{1,28}[a-z0-9]$') {
            Write-Host "Use 3-30 lowercase letters, numbers, or hyphens." -ForegroundColor Yellow
            continue
        }

        $selectedNames = @($vms | ForEach-Object { $_.name })

        if (($existingVMs -contains $name) -or
            ($selectedNames -contains $name)) {

            Write-Host "VM name already exists. Choose another." -ForegroundColor Yellow
            continue
        }

        break
    }

    # Reserve minimum resources for remaining VMs
    $remaining = $vmCount - $i

    $maxCpu = $cpuBudget - $usedCpu - $remaining

    $maxRam = $ramBudget - $usedRam - ($remaining * 1024)

    # Ask for CPU allocation
    $defaultCpu = [int][math]::Min(2, $maxCpu)

    $cpus = Read-Number "Number of CPUs" 1 $maxCpu $defaultCpu

    # Ask for RAM allocation
    $defaultRam = [int][math]::Min(2048, $maxRam)

    $memory = Read-Number "RAM in MB" 1024 $maxRam $defaultRam

    # Save this VM configuration
    $vms += [pscustomobject]@{
        name   = $name
        cpus   = $cpus
        memory = $memory
    }

    # Update total resource allocation
    $usedCpu += $cpus
    $usedRam += $memory
}


# 8. Display deployment summary

Write-Host ""
Write-Host "DEPLOYMENT SUMMARY" -ForegroundColor Cyan

$vms | Format-Table -AutoSize

Write-Host "Total allocated CPUs: $usedCpu"
Write-Host "Total allocated RAM: $usedRam MB"
Write-Host "Disk planning allowance: $($vmCount * $diskPerVm) GB"

$confirm = Read-Host "Do you want to deploy these VMs? (y/n)"

if ($confirm.Trim().ToLower() -ne "y") {
    Write-Host "Deployment cancelled."
    return
}


# 9. Save VM configurations to JSON

@{
    vms = @($vms)
} |
ConvertTo-Json -Depth 5 |
Set-Content -Path $configPath -Encoding UTF8


# 10. Validate and deploy using Vagrant

Push-Location $PSScriptRoot

try {

    & vagrant validate

    if ($LASTEXITCODE -ne 0) {
        throw "Vagrant configuration validation failed."
    }

    & vagrant up --provider=virtualbox

    if ($LASTEXITCODE -ne 0) {
        throw "VM deployment failed. Check Vagrant output."
    }

    Write-Host ""
    Write-Host "VM deployment completed!" -ForegroundColor Green

    & vagrant status
}
finally {
    Pop-Location
}
