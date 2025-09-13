param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("SystemInfo", "RestartService", "CreateUser")]
    [string]$Task,
    
    [Parameter(Mandatory = $false)]
    [string]$ComputerName = $env:COMPUTERNAME,
    
    [Parameter(Mandatory = $false)]
    [string]$ServiceName,
    
    [Parameter(Mandatory = $false)]
    [string]$Username,
    
    [Parameter(Mandatory = $false)]
    [string]$Password,
    
    [Parameter(Mandatory = $false)]
    [string]$Description
)

function Get-SystemInfo {
    param (
        [string]$ComputerName
    )
    
    Write-Host "Retrieving system information for $ComputerName..." -ForegroundColor Green
    
    $os = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName
    $cpu = Get-WmiObject -Class Win32_Processor -ComputerName $ComputerName
    $memory = Get-WmiObject -Class Win32_PhysicalMemory -ComputerName $ComputerName
    $disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'" -ComputerName $ComputerName

    # Calculate total memory from all RAM modules
    $totalMemory = ($memory | Measure-Object -Property Capacity -Sum).Sum

    Write-Host "OS Version: $($os.Caption) $($os.Version)"
    Write-Host "CPU: $($cpu.Name)"
    Write-Host "Total Memory: $([math]::Round($totalMemory / 1GB, 2)) GB"
    Write-Host "Free Disk Space: $([math]::Round($disk.FreeSpace / 1GB, 2)) GB"
}

function Restart-RemoteService {
    param (
        [string]$ComputerName,
        [string]$ServiceName
    )
    
    Write-Host "Restarting service '$ServiceName' on $ComputerName..." -ForegroundColor Green
    
    $service = Get-Service -Name $ServiceName -ComputerName $ComputerName -ErrorAction SilentlyContinue
    
    if ($service) {
        if ($service.Status -eq "Running") {
            Restart-Service -InputObject $service -Force
            Write-Host "Service '$ServiceName' restarted successfully." -ForegroundColor Green
        } else {
            Write-Host "Service '$ServiceName' is not running." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Service '$ServiceName' not found." -ForegroundColor Red
    }
}

function Create-LocalUser {
    param (
        [string]$Username,
        [string]$Password,
        [string]$Description
    )
    
    Write-Host "Creating new local user '$Username'..." -ForegroundColor Green
    
    $securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
    New-LocalUser -Name $Username -Password $securePassword -Description $Description -AccountNeverExpires -PasswordNeverExpires
    
    Write-Host "User '$Username' created successfully." -ForegroundColor Green
}

# Main script logic
switch ($Task) {
    "SystemInfo" {
        Get-SystemInfo -ComputerName $ComputerName
    }
    "RestartService" {
        if (-not $ServiceName) {
            Write-Host "Error: ServiceName parameter is required for RestartService task." -ForegroundColor Red
            exit
        }
        Restart-RemoteService -ComputerName $ComputerName -ServiceName $ServiceName
    }
    "CreateUser" {
        if (-not $Username -or -not $Password) {
            Write-Host "Error: Username and Password parameters are required for CreateUser task." -ForegroundColor Red
            exit
        }
        Create-LocalUser -Username $Username -Password $Password -Description $Description
    }
    default {
        Write-Host "Invalid task specified." -ForegroundColor Red
    }
}