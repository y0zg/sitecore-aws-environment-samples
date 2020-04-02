# EKS

This Terraform module provisions an EKS cluster with

- 2x Linux worker nodes
- [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) enabled

If you want Windows workers added to the cluster, setting `windows_workers_count = 1` will add `1` Windows worker node.

```bash
terraform apply
```

## Ingress

The following command installs [nginx-ingress-controller](https://kubernetes.github.io/ingress-nginx/) into the newly created cluster:

```bash
aws eks update-kubeconfig --name [name of newly created cluster]
helm install nginx-ingress -values ingress-values.yaml stable/nginx-ingress
```

When completed, this chart also ensures one [Network Load Balancer (NLB)]( https://docs.aws.amazon.com/elasticloadbalancing/latest/network/introduction.html) is deployed.
It registers *all* worker nodes in its target group, and listens on `80/tcp` and `443/tcp`.

Worker nodes which have the `nginx-ingress-controller` running on them will become _healthy_ in the target group,
and will start receiving traffic from the NLB.

The nginx controller will, based on `Ingress` objects we deploy, adjust their configurations and ensure traffic is routed to the correct services inside the cluster.
There's a "catch-all" service deployed alongside with `nginx-ingress-controller`, so we'll be able to see if traffic at least makes it into the cluster.

Once the NLB is provisioned, you should be able to make HTTP requests towards it and reach the default service using the command below.
Open it using `http://[EXTERNAL_IP]` in your browser and you should see

```
default backend - 404
```

```bash
# Get the external IP/DNS for the NLB
kubectl get services --namespace ingress-nginx nginx-ingress-controller --output jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

