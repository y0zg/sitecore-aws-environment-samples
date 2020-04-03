# EKS

This Terraform module provisions an [EKS cluster](https://docs.aws.amazon.com/eks/latest/userguide/clusters.html) with

- 2x Linux worker nodes
- [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) enabled

It also provisions a [Network Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/network-load-balancers.html) with

- Public listener on port `80/tcp` for HTTP traffic
- Public listener on port `443/tcp` for HTTPS traffic

Each listener forwards traffic to two distinct target groups.
All worker nodes are automatically registered as targets inside the both target groups.

For ingress, it deploys the `nginx-ingress-controller` using the Helm chart [stable/nginx-ingress](https://github.com/helm/charts/tree/master/stable/nginx-ingress).
See the [Ingress](#ingress) section for more details.

DNS records in Route53 are managed using [ExternalDNS](https://github.com/kubernetes-sigs/external-dns) using the Helm chart [stable/external-dns](https://github.com/helm/charts/tree/master/stable/external-dns).
See the [DNS](#dns) section for more details.

**Note** If you want Windows workers added to the cluster, setting `windows_workers_count = 1` will add `1` Windows worker node.

## Getting Started

Spin it all up using the following command:

```bash
terraform apply
```

Once completed, go through the output and see if there's anything of interest.
There should be a URL :link: pointing towards a sample app, complete with automatic creation of DNS record :book: and HTTPS certificate :lock:

## Prerequisites

These must be installed and available in your `$PATH`

- Helm 3+
- Terraform 0.12
- kubectl
- aws-iam-authenticator

## Ingress

Worker nodes which have the `nginx-ingress-controller` running on them will become _healthy_ in the target group,
and will start receiving traffic from the NLB.

The nginx controller will, based on `Ingress` objects we deploy, adjust their configurations and ensure traffic is routed to the correct services inside the cluster.
There's a "catch-all" service deployed alongside with `nginx-ingress-controller`, so we'll be able to see if traffic at least makes it into the cluster.

Try visiting the load balancer hostname in your browser. Retrieve it like this:

```bash
# bash/sh/zsh
lb_host=$(terraform output lb_fqdn)
curl $lb_host
```

```powershell
# PowerShell
$lb_host = $(terraform output lb_fqdn)
Invoke-WebRequest -UseBasicParsing -Uri $lb_host
```

If everything is working as intended, you'll see the following response:

```
default backend - 404
```

## DNS

**Note** To avoid mistakes, this Terraform module creates a new DNS zone in Route53 in which ExternalDNS operates.

ExternalDNS is granted access to modify this DNS zone using [IAM Roles for Service Accounts]().
The IAM role, policy, and ExternalDNS itself is defined in [external-dns.tf](external-dns.tf).



