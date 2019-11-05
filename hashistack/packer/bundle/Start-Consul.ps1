[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $ClusterTagKey,

    [Parameter(Mandatory = $true)]
    [string]
    $ClusterTagValue
)


$ConfigPath = 'c:\services\consul\config\default.json'
$BinaryPath = 'c:\services\consul\consul.exe'
$DataPath = 'c:\services\consul\data'

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
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ClusterTagKey,

        [Parameter(Mandatory = $true)]
        [string]
        $ClusterTagValue
    )

    $InstanceId = Get-MetadataValue 'instance-id'
    $InstanceIp = Get-MetadataValue 'local-ipv4'
    $InstanceRegion = "$((ConvertTo-Json(Get-DynamicDataValue 'instance-identity/document').region) -replace '\"', '')"

    Write-Verbose $InstanceId
    Write-Verbose $InstanceIp
    Write-Verbose $InstanceRegion

    $Config = @"
{
    "advertise_addr": "$InstanceIp",
    "bind_addr": "$InstanceIp",
    "client_addr": "0.0.0.0",
    "datacenter": "$InstanceRegion",
    "node_name": "$InstanceId",
    "retry_join": [
        "provider=aws region=$InstanceRegion tag_key=$ClusterTagKey tag_value=$ClusterTagValue"
    ],
    "server": false,
    "autopilot": {
        "cleanup_dead_servers": true,
        "last_contact_threshold": "200ms",
        "max_trailing_logs": 250,
        "server_stabilization_time": "10s",
        "redundancy_zone_tag": "az",
        "disable_upgrade_migration": false,
        "upgrade_version_tag": ""
    }
}
"@

    $ConfigDirectory = Split-Path $ConfigPath
    New-Item -ItemType Directory -Path $ConfigDirectory -Force | Out-Null
    Set-Content -Path $ConfigPath -Value $Config
}

function Register-Service
{
    New-Service `
        -Name 'Consul' `
        -BinaryPathName "$BinaryPath agent -config-dir $ConfigPath -data-dir $DataPath" `
        -StartupType Automatic
}

Initialize-Configuration -ClusterTagKey $ClusterTagKey -ClusterTagValue $ClusterTagValue
Register-Service | Start-Service

