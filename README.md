# k8s-agnes-terraform

Terraform for managing my personal kubernetes cluster. The cluster is built with Talos Linux. 

## Details

- Uses the OpenEBS LVM provisioner for large persistent volumes.
- Uses the local path provisioner for application configuration persistant volumes.
- Uses Traefik as a reverse proxy with Cert Manager configured for TLS.
- External facing applications are tunnelled through Cloudflare Zero Trust.
- Monitoring and alerting is through the Prometheus operator and Grafana
- Most applications are created through Truecharts helm charts.
- LoadBalancing is handled through MetalLB in L2 mode and a VIP configured in Talos.
