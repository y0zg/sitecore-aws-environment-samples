$env:NOMAD_VERSION = '0.9.5'
$env:CONSUL_VERSION = '1.6.1'

$DownloadPath = 'c:\bootstrap'
$NomadPath = 'c:\services\nomad'
$ConsulPath = 'c:\services\consul'

New-Item -Type Directory -Path $DownloadPath -Force
New-Item -Type Directory -Path $NomadPath -Force
New-Item -Type Directory -Path $ConsulPath -Force

Write-Verbose 'Downloading Nomad and Consul'

Invoke-WebRequest `
    -Uri "https://releases.hashicorp.com/nomad/$env:NOMAD_VERSION/nomad_$($env:NOMAD_VERSION)_windows_amd64.zip" `
    -OutFile "$DownloadPath\nomad.zip"

Invoke-WebRequest `
    -Uri "https://releases.hashicorp.com/consul/$env:CONSUL_VERSION/consul_$($env:CONSUL_VERSION)_windows_amd64.zip" `
    -OutFile "$DownloadPath\consul.zip"

Write-Verbose 'Unpacking Nomad and Consul'

Expand-Archive -Path "$DownloadPath\nomad.zip" -DestinationPath $NomadPath
Expand-Archive -Path "$DownloadPath\consul.zip" -DestinationPath $ConsulPath

Write-Verbose 'Cleaning up'

Remove-Item -Recurse $DownloadPath
