<powershell>

# Generates a Consul configuration, registers Consul as a service, and starts it.
c:\bundle\Start-Consul.ps1 `
    -ClusterTagKey '${cluster_tag_key}' `
    -ClusterTagValue '${cluster_tag_value}'

c:\bundle\Start-Nomad.ps1

</powershell>
