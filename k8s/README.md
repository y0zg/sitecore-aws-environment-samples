# EKS

This Terraform module provisions an [EKS cluster](https://docs.aws.amazon.com/eks/latest/userguide/clusters.html) with

- 2x Linux worker nodes
- [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) enabled

It also provisions a [Network Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/network-load-balancers.html) with

- Public listener on port `80/tcp` for HTTP traffic
- Public listener on port `443/tcp` for HTTPS traffic

Each listener forwards traffic to two distinct target groups.
All worker nodes are automatically registered as targets inside the both target groups.

**Note** If you want Windows workers added to the cluster, setting `windows_workers_count = 1` will add `1` Windows worker node.

Spin it all up using the following command:

```bash
terraform apply
```

## Prerequisites

These must be installed and available in your `$PATH`

- Helm 3+
- Terraform 0.12
- kubectl

## Ingress

The following command installs [nginx-ingress-controller](https://kubernetes.github.io/ingress-nginx/) into the newly created cluster:

```bash
# Updates your kubeconfig with fresh tokens for accessing your new cluster
aws eks update-kubeconfig --name [name of newly created cluster]

# Ensure the 'stable' repository is added to your helm
helm repo add stable https://kubernetes-charts.storage.googleapis.com

# Install the nginx-ingress controller
helm install nginx-ingress --values ingress-values.yaml stable/nginx-ingress
```

Worker nodes which have the `nginx-ingress-controller` running on them will become _healthy_ in the target group,
and will start receiving traffic from the NLB.

The nginx controller will, based on `Ingress` objects we deploy, adjust their configurations and ensure traffic is routed to the correct services inside the cluster.
There's a "catch-all" service deployed alongside with `nginx-ingress-controller`, so we'll be able to see if traffic at least makes it into the cluster.

Once the nginx controller is installed, try visiting the load balancer hostname in your browser.
Retrieve it like this:

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
