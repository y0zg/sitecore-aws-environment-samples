# Nomad and Consul for Deployment Orchestration in AWS

This RFC describes how Nomad and Consul can be used to host Sitecore 9 CD and CM servers in Amazon Web Services (AWS) cloud.

## Context

Sitecore 9 is currently hosted on on-premise Windows Server 2016 VMs.
The provisioning of these VMs is scripted using PowerShell/Chocolatey, and deployment of the VMs themselves is semi-automatic.

The OS'es are provisioned with the exact dependencies required to run Sitecore 9 CD and CM, including

- .NET Framework
- Java
- IIS

## Proposal



