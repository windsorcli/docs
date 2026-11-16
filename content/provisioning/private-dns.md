---
title: Private DNS
description: The dns.private.driver values (cloud, coredns, pdns, pdns-remote, none), when to choose pdns over coredns, how to switch, and what pdns does not protect.
---

A cluster needs a private zone, such as `example.local`, so that `grafana.example.local` resolves to the internal gateway. Something must serve that zone, and something must write a record into it each time a `Gateway` or `HTTPRoute` appears. The `dns.private.driver` key in `values.yaml` selects the server. The `dns.private_domain` key names the zone.

```yaml
dns:
  private_domain: example.local
  private:
    driver: pdns
```

In every driver except `none`, [external-dns](https://kubernetes-sigs.github.io/external-dns/) in the `system-dns` namespace watches `Gateway` and `HTTPRoute` hostnames and writes them as records. The drivers differ in the server that holds those records and in the path external-dns uses to write them.

## Choose a driver

| Driver | Server | How external-dns writes records | Default on |
| --- | --- | --- | --- |
| `cloud` | The private zone of the cloud provider, attached to the VPC or virtual network | The provider API | aws, azure, gcp |
| `coredns` | CoreDNS in the cluster, with an etcd backend | Directly into etcd | Other platforms, when `dns.private_domain` is set |
| `pdns` | PowerDNS Authoritative in the cluster, with a CloudNativePG database | The PowerDNS REST API | None (opt-in) |
| `pdns-remote` | A PowerDNS server that you already run | The REST API of that server | None (opt-in) |
| `none` | No private zone server | Not applicable | hetzner |

`dns.private.enabled: true` is a deprecated alias for `coredns`.

Choose `cloud` on aws, azure, and gcp. The provider runs the zone, and the cluster has nothing extra to operate. `pdns` is an opt-in alternative on those platforms; `cloud` stays the default there.

Choose `coredns` or `pdns` where no provider zone exists: [vSphere](../virtual/vsphere.md), [Hyper-V](../virtual/hyperv.md), [Proxmox](../virtual/proxmox.md), bare metal, and [workstation](../workstation/overview.md) contexts. Both serve the private zone on the address of the internal gateway, so resolvers query the same address under either driver.

Choose `pdns` instead of `coredns` when something other than external-dns must write records. CoreDNS has no write API, so external-dns writes straight into etcd. Any other tool would need etcd client certificates and a route to the etcd client port. PowerDNS accepts writes through one REST API and one key. The `pdns` driver also drops the etcd StatefulSet, its certificates, and its network policy.

Keep `coredns` when the context must not run a database. The `pdns` driver adds a PostgreSQL cluster to the context.

## What the pdns driver runs

The `pdns` driver installs these parts in `system-dns`:

- PowerDNS Authoritative, which answers queries on port 53.
- A CloudNativePG `Cluster` named `pdns-db`, which holds the zones and records. The driver turns on `database.postgres.enabled`, and Windsor rejects a context that sets it to `false`.
- A `pdns-zone-init` Job, which creates the private zone through the API. It also creates the public zone, where PowerDNS serves one. external-dns does not create zones, so the first record write fails without this Job.
- An external-dns instance for each zone, which writes records through the PowerDNS REST API.

Flux holds the PowerDNS tier until the `Cluster` reports `Ready`. A `Cluster` counts as applied before its database accepts connections, so the blueprint checks the `Ready` condition itself.

Under `topology: ha`, PowerDNS runs two replicas and the database runs three instances with required anti-affinity. external-dns stays at one replica. While its pod is down, PowerDNS keeps answering and no record changes.

Port 53 is exposed as it is under `coredns`: a `LoadBalancer` Service at `gateway.internal.ip` when the gateway driver is Cilium, or a route on the internal gateway when it is Envoy.

## The API key

external-dns and the zone-init Job authenticate to the PowerDNS API with one key. Windsor writes it into the `pdns-api` `Secret` in `system-dns`. Set the key in `values.yaml` as a [secret reference](../secrets/overview.md), for a SOPS or 1Password secret:

```yaml
dns:
  private:
    driver: pdns
    pdns:
      api_key: ${secret("sops", "pdns.api_key")}
```

When `dns.private.pdns.api_key` is unset, the `pdns` driver generates a random key with a Terraform stack and writes that key into the same `Secret`. Terraform state then holds the key. Set `dns.private.pdns.api_key` when you need to know the key or keep it in your own secret store.

The PowerDNS pods read the key and the database credentials from `Secret` objects, never from a ConfigMap.

## Records that a person adds by hand

The records that external-dns writes come from `Gateway` and `HTTPRoute` sources. When the database is empty, external-dns writes them again from those sources.

A record that a person adds by hand, through the PowerDNS API, has no source. It lives only in the database. If the database volume is lost, that record is lost. The `pdns` driver adds no database backup yet. Keep the definition of each hand-made record outside the cluster, so that you can add it again.

## Switch from coredns to pdns

To switch a running context, change the driver and apply:

```yaml
dns:
  private:
    driver: pdns
```

```bash
windsor apply
```

Flux prunes CoreDNS and etcd, and then creates PowerDNS and the database. Three things follow:

- external-dns writes again each record that it wrote before. The `Gateway` and `HTTPRoute` sources hold those records, and the new instance starts with an empty TXT ownership registry.
- Records that a person added to etcd by hand are lost. Windsor does not read the etcd volume. Add them again through the PowerDNS API.
- The port 53 address does not change. No resolver needs an edit.

Private zone answers stop between the moment Flux prunes CoreDNS and the first external-dns sync into PowerDNS. The length of this gap is not measured. The CI test for the `pdns` driver proves that a record from a `Gateway` route resolves in the cluster, and it reports no switch timing. Plan the switch for a time when a short loss of private names is acceptable.

Switching from `pdns` back to `coredns` works the same way and loses records in the same way.

## Network access

The PowerDNS API and its metrics endpoint listen on the `pdns-api` `ClusterIP` Service, on port 8081. No gateway route, load balancer, or node port exposes them.

`NetworkPolicy` objects limit who can connect:

- The API accepts connections from the external-dns pods and the zone-init Job only.
- The database accepts connections from PowerDNS, the migration Job, its own instances, and the database operator.
- Port 53 accepts connections from any source, because resolvers need it.

A `NetworkPolicy` has an effect only when the CNI enforces it. Cilium enforces it. On a CNI that does not, the objects have no effect, and any pod in the cluster can reach the API with the key.

## Use an existing PowerDNS server

The `pdns-remote` driver points external-dns at a PowerDNS server that you already run. It installs no server, no database, and no zone-init Job. The zones MUST already exist on the server. Set `dns.private.pdns.url` and `dns.private.pdns.api_key`. Set `dns.private.pdns.server_id` when the server ID is not `localhost`.

## Limits

- The driver has no database backup.
- The cert-manager DNS-01 solver for the private zone is not part of the driver. Core tracks it in [core#3318](https://github.com/windsorcli/core/issues/3318).
- Cloud contexts use the in-cluster database. The driver does not use the managed database option.

## Where to next

- [Secrets](../secrets/overview.md): write the `secret()` reference for the API key
- [Workstation](../workstation/overview.md): the DNS server that local contexts use
- [Upgrade](upgrade.md): move a context to a newer blueprint version
- [The dns add-on in core](https://github.com/windsorcli/core/tree/main/kustomize/dns): components and substitutions
