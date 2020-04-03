# Sitecore Hosting Environment in AWS

This repository contains different ways of hosting Sitecore and other services in AWS.

- [ecs/](ecs/) shows how [AWS ECS](https://aws.amazon.com/ecs/) can be used to host containerized Windows workloads, complete with DNS and TLS certificate management
- [k8s/](k8s/) shows how it's done in [AWS EKS](https://aws.amazon.com/eks/), and also with DNS and TLS certificate management
- [hashistack/](hashistack/) is an incomplete example, but shows the beginning of how a [Nomad](https://nomadproject.io/), [Consul](https://www.consul.io/), and [Vault](https://www.hashicorp.com/products/vault) based setup could look like

All are defined using [Terraform](https://www.hashicorp.com/products/terraform).
