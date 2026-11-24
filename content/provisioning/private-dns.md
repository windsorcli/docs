---
title: Private DNS
description: The dns.private.driver values (cloud, coredns, pdns, pdns-remote, none), when to choose pdns over coredns, how to switch, and what pdns does not protect.
---

For `grafana.example.local` to resolve to the internal gateway, a DNS server must hold the `example.local` zone, and each new `Gateway` or `HTTPRoute` hostname must become a record in it. In `values.yaml`, `dns.private_domain` names the zone and `dns.private.driver` selects the server.

```yaml
dns:
  private_domain: example.local
  private:
    driver: pdns
```

With every driver except `none`, external-dns in the `system-dns` namespace reads the hostnames from `Gateway` and `HTTPRoute` resources and writes the records. The drivers differ in the server that stores the records and in how external-dns reaches it.

## Choose a driver

| Driver | Server | How external-dns writes records | Default on |
| --- | --- | --- | --- |
| `cloud` | The private zone of the cloud provider | The provider API | aws, azure, gcp |
| `coredns` | CoreDNS in the cluster, with an etcd backend | Directly into etcd | Other platforms, when `dns.private_domain` is set |
| `pdns` | PowerDNS Authoritative in the cluster, with a CloudNativePG database | The PowerDNS REST API | Nowhere (opt-in) |
| `pdns-remote` | A PowerDNS server that you already run | The REST API of that server | Nowhere (opt-in) |
| `none` | No private zone server | Not applicable | hetzner |

`dns.private.enabled: true` is a deprecated alias for `coredns`.

On aws, azure, and gcp, `cloud` is the default, and `pdns` is an opt-in alternative. On [vSphere](../virtual/vsphere.md), [Hyper-V](../virtual/hyperv.md), [Proxmox](../virtual/proxmox.md), bare metal, and [workstation](../workstation/overview.md) contexts, no provider zone exists, so the choice is between `coredns` and `pdns`. Both answer on the address of the internal gateway. A resolver that works with one works with the other.

Use `pdns` when a tool other than external-dns must write records. CoreDNS has no write API, so external-dns writes straight into etcd, and any second writer needs etcd client certificates and a route to the etcd client port. PowerDNS takes writes through a REST API with one key. `pdns` also removes the etcd StatefulSet, its certificates, and its network policy.

Use `coredns` when the context must not run a database. `pdns` adds a PostgreSQL cluster, even on cloud platforms, where it does not use the managed database option.

## What the pdns driver runs

In `system-dns`, the driver installs:

- PowerDNS Authoritative, which answers on port 53.
- A CloudNativePG `Cluster` named `pdns-db`, which stores the zones and records. The driver sets `database.postgres.enabled` to `true`, and Windsor rejects a context that sets it to `false`.
- A `pdns-zone-init` Job, which creates the private zone through the API, and the public zone where PowerDNS serves one. external-dns does not create zones, so without this Job the first record write fails.
- One external-dns instance for each zone, which writes through the PowerDNS REST API.

A CloudNativePG `Cluster` counts as applied before its database accepts connections. The blueprint therefore holds the PowerDNS tier until the `Cluster` reports `Ready`.

With `topology: ha`, PowerDNS runs two replicas and the database runs three instances with required anti-affinity. external-dns stays at one replica. While its pod is down, PowerDNS keeps answering, and records stop changing.

Port 53 is exposed as it is with `coredns`: a `LoadBalancer` Service at `gateway.internal.ip` under Cilium, or a route on the internal gateway under Envoy.

## The API key

external-dns and the zone-init Job authenticate to the PowerDNS API with one key, which Windsor writes into the `pdns-api` `Secret` in `system-dns`. To supply the key, set `dns.private.pdns.api_key` to a [secret reference](../secrets/overview.md) for a SOPS or 1Password secret:

```yaml
dns:
  private:
    driver: pdns
    pdns:
      api_key: ${secret("sops", "pdns.api_key")}
```

If the field is unset, a Terraform stack generates a random key and writes it into the same `Secret`, and Terraform state holds it. Set the field when you must know the key or keep it in your own secret store. The PowerDNS pods read the key and the database credentials from `Secret` objects, never from a ConfigMap.

## Records added by hand

external-dns can write its records again from the `Gateway` and `HTTPRoute` resources, so an empty database refills itself. A record that someone adds through the PowerDNS API has no such source. It exists only in the database, and it is lost if the database volume is lost. The driver has no database backup, so keep a copy of each hand-made record outside the cluster.

## Switch from coredns to pdns

Change the driver in `values.yaml`:

```yaml
dns:
  private:
    driver: pdns
```

Then apply it:

```bash
windsor apply
```

Flux prunes CoreDNS and etcd, then creates PowerDNS and its database. external-dns writes again every record that it wrote before, because the `Gateway` and `HTTPRoute` resources still hold them and the new instance starts with an empty TXT ownership registry. Records that someone added to etcd by hand are lost, because Windsor does not read the etcd volume. Add them again through the PowerDNS API. The port 53 address does not change, so no resolver needs an edit.

Names in the private zone stop resolving from the moment Flux prunes CoreDNS until external-dns finishes its first sync into PowerDNS. The length of that gap is not measured. The CI test for `pdns` checks that a record from a `Gateway` route resolves in the cluster, and it records no switch timing.

A switch from `pdns` back to `coredns` loses records the same way.

## Network access

The PowerDNS API and its metrics endpoint listen on the `pdns-api` `ClusterIP` Service, port 8081. No gateway route, load balancer, or node port exposes them.

`NetworkPolicy` objects restrict who connects:

- The API accepts the external-dns pods and the zone-init Job only.
- The database accepts PowerDNS, the migration Job, its own instances, and the database operator.
- Port 53 accepts any source, because resolvers must reach it.

A `NetworkPolicy` has an effect only when the CNI enforces it, and Cilium does. On a CNI that does not, the objects do nothing, and any pod in the cluster that has the key can call the API.

## Use an existing PowerDNS server

With `pdns-remote`, external-dns writes to a PowerDNS server that you already run. Windsor installs no server, database, or zone-init Job, so the zones MUST already exist on that server. Set `dns.private.pdns.url` and `dns.private.pdns.api_key`. Set `dns.private.pdns.server_id` if the server ID is not `localhost`.

## What the driver does not cover

The cert-manager DNS-01 solver for the private zone is not part of the driver. [core#3318](https://github.com/windsorcli/core/issues/3318) tracks it.

For the components and substitutions behind the driver, see the [dns add-on](https://github.com/windsorcli/core/tree/main/kustomize/dns) in core.
