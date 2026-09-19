---
title: Expressions
description: The expression language behind facet when clauses and ${expr} substitutions, and the functions Windsor adds on top of it.
---

Facet `when:` conditions, `${...}` substitutions in schema values, and config blocks all share one expression language: [expr](https://expr-lang.org), a general-purpose expression language for Go. It isn't Windsor-specific. Normal comparison and boolean operators, ternaries, string concatenation, and a full standard library (`map`, `filter`, `get`, `len`, and more) all work exactly as [expr's own syntax reference](https://expr-lang.org/docs/language-definition) documents them, with one exception: member access. See [Member access is always optional](#member-access-is-always-optional) below. Windsor adds a small, fixed set of functions on top, for these tasks:

- Reading environment variables
- Computing CIDR addresses
- Parsing YAML
- Reaching into Terraform outputs or secrets

```yaml
when: platform == 'aws' && (topology ?? 'single-node') == 'ha'
value: "${cluster.controlplanes.count ?? 1}"
```

## Windsor's functions

| Function | Does |
|---|---|
| `env(name)` | Reads an environment variable. Returns nothing when unset. |
| `secret(provider, name, field)` | Resolves a value from a configured secret store at apply time. |
| `terraform_output(component, output)` | Reads an output from an already-applied Terraform component. Returns nothing until that component has run — see [Deferred evaluation](#deferred-evaluation). |
| `yaml(pathOrContent, [input])` | Parses YAML from a file path or an inline string. |
| `yamlString(value)` / `yamlString(path, input)` | The inverse: marshals a value to a YAML string. |
| `jsonString(value)` | Marshals a value to a JSON string. |
| `file(path)` | Reads a file's raw contents. |
| `jsonnet(path)` | Evaluates a Jsonnet file and returns its result. |
| `split(str, sep)` | Splits a string on a separator. |
| `string(value)` | Coerces a value to a string; maps and slices render as YAML. |
| `cidrhost(prefix, hostnum)` | The address at a given host offset within a CIDR block. |
| `cidrsubnet(prefix, newbits, netnum)` | Carves a subnet out of a CIDR block. |
| `cidrsubnets(prefix, newbits...)` | Carves several subnets at once, one per `newbits` value. |
| `cidrnetmask(prefix)` | The dotted-decimal netmask for a CIDR block. |

A blueprint author reaches for these constantly. `platform-hetzner.yaml`'s
`k8s_service_host: "${cidrhost(network.cidr_block ?? '10.5.0.0/16', 10)}"` is a typical
example. Everything else in an expression (`??`, `in`, `map`, `filter`, `fromPairs`,
`toPairs`, `concat`, `values`) is plain expr, not something Windsor added.

## Member access is always optional

Plain expr distinguishes `a.b` (errors if `a` is missing) from `a?.b` (returns nil instead). Windsor patches every expression so every `.` already behaves like `?.`: `addons.database.enabled` and `addons?.database?.enabled` compile to the same thing. Writing the `?` changes nothing, and there's no way to write a *required* member access in a Windsor expression.

A missing or misspelled path resolves to nil, not an error:

- Alone, or in a boolean context like `when:`, it's `false`.
- Inside a `${...}` substitution embedded in a larger string, it's an empty string.
- Combined with `??`, the fallback wins, the same as if the path had resolved to nil on purpose.

This is intentional for `when:` — a facet has to evaluate cleanly against a blueprint that doesn't declare a given config section at all, not error out.

For a Terraform `inputs:` field, a nil result is dropped from the generated `.tfvars` entirely, rather than written as an empty value. If the module's own `variable` block has no `default`, Terraform's own "no value for required variable" check catches it. If the module does have a default, the input silently falls back to it, which is quiet but not corrupting: the operator's override just didn't take effect.

Kustomize `substitutions:` and any `${...}` embedded inside a larger string have no such backstop: a nil result there is written through as a literal empty string, with nothing downstream positioned to reject it.

If a value genuinely must be present, don't rely on an expression to catch it. Declare it under a facet's `requires:` block instead — that path does a real presence check on the composed scope and fails composition with a clear message, rather than resolving quietly to nil. See [Facets reference](https://www.windsorcli.dev/reference/cli/facets).

## Where expressions run

- **`when:`** on a facet, a config block, a Terraform or Flux entry — must evaluate to a boolean. See [Facets](facets.md).
- **`value:`** inside a facet's `config:` blocks — any expression, including nested maps and lists built from `fromPairs`/`map`.
- **`${...}` substitutions** inside schema values, Terraform `inputs:`, and Kustomize `substitutions:`. A string that's exactly one `${...}` expression evaluates to that expression's own type (a map, a number, a bool); `${...}` embedded alongside other text interpolates as a string, with a nil result rendering as empty (`"prefix-${cluster.undefined}-suffix"` becomes `"prefix--suffix"`).

## Deferred evaluation

`terraform_output()` can't resolve before its component has actually applied. During `windsor plan`, or on a facet's first evaluation pass, the referenced component may not have run yet. Windsor handles this by deferring: it leaves an expression that depends on a not-yet-available output unevaluated, and retries it once its dependency resolves, rather than failing the whole composition. This is why facets that read `terraform_output()` almost always pair it with a fallback (`?? cluster.controlplanes.nodes`), so the blueprint still composes something sensible before that Terraform component exists.

## Reference

- [expr language definition](https://expr-lang.org/docs/language-definition) — full syntax and standard library
- [Facets](facets.md) — `when:` conditions, ordinals, config blocks
- [Blueprint templates](templates.md) — composition order and substitution merging
- [Blueprint reference](https://www.windsorcli.dev/reference/cli/blueprint) — every field that accepts an expression
