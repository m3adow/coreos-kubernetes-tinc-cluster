**This is a WIP (work in progress), so don't expect a fully working configuration!**

### What is this?

This is a template for [cloud-config-creator](https://github.com/m3adow/cloud-config-creator) intended for a three node CoreOS cluster
connected over the Internet.

### Features

* etcd-cluster with TLS-encrypted communication
* Fully encrypted node2node communication, either via TLS (etcd) or via [tinc-vpn](http://tinc-vpn.org/) (flannel et al)
* Three node Kubernetes cluster (WIP)
* Includes "simple DNS etcd failover" (sdef) for a cluster Failover via Cloudflare DNS

### Todo

* K8s Worker setup
* Include K8s master node as worker
* check systemd dependencies to keep "on boot failures" small
* Enhance README
* TLS instructions?
