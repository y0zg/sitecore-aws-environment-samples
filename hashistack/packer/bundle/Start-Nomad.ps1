$NomadBinaryPath = 'c:\services\nomad\nomad.exe'
$ConfigPath = 'c:\services\nomad\config\default.hcl'
$DataPath = 'c:\services\nomad\data'
$StdOutLogPath = 'c:\services\nomad\stdout.log'
$StdErrLogPath = 'c:\services\nomad\stderr.log'

$EC2MetadataUrl = 'http://169.254.169.254/latest/meta-data'
$EC2DynamicDataUrl = 'http://169.254.169.254/latest/dynamic'

function Get-MetadataValue
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Key
    )

    Invoke-RestMethod -Method Get -Uri "$EC2MetadataUrl/$Key"
}

function Get-DynamicDataValue
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Key
    )

    Invoke-RestMethod -Method Get -Uri "$EC2DynamicDataUrl/$Key"
}

function Initialize-Configuration
{
    $InstanceId = Get-MetadataValue 'instance-id'
    $InstanceIp = Get-MetadataValue 'local-ipv4'
    $InstanceAz = Get-MetadataValue 'placement/availability-zone'
    $InstanceRegion = ConvertTo-Json(Get-DynamicDataValue 'instance-identity/document').region

    Write-Verbose $InstanceId
    Write-Verbose $InstanceIp
    Write-Verbose $InstanceAz
    Write-Verbose $InstanceRegion

    $Config = @"
client {
    enabled = true
}

datacenter = "$InstanceAz"
name       = "$InstanceId"
region     = $InstanceRegion
bind_addr  = "0.0.0.0"

advertise {
    http = "$InstanceIp"
    rpc  = "$InstanceIp"
    serf = "$InstanceIp"
}

consul {
    address = "127.0.0.1:8500"
}
"@

    $ConfigDirectory = Split-Path $ConfigPath
    New-Item -ItemType Directory -Path $ConfigDirectory -Force | Out-Null
    Set-Content -Path $ConfigPath -Value $Config
}

function Register-Service {
    nssm.exe install nomad "$NomadBinaryPath" "agent -config $ConfigPath -data-dir $DataPath"
    nssm.exe set nomad AppStdout $StdOutLogPath
    nssm.exe set nomad AppStderr $StdErrLogPath
    nssm.exe start nomad
}

Initialize-Configuration
Register-Service

