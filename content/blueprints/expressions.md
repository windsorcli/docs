---
title: Expressions
description: The expression language behind facet when clauses and ${expr} substitutions, and the functions Windsor adds on top of it.
---

A facet has to decide whether it applies to a context, and then compute the inputs it passes to its components from that context's values. Both jobs use [*expressions*](overview.md#expressions). This excerpt from `core`'s [`platform-aws.yaml`](https://github.com/windsorcli/core/blob/main/contexts/_template/facets/platform-aws.yaml) has one of each kind.

```yaml
when: platform == 'aws'
terraform:
  - name: network
    path: network/aws-vpc
    inputs:
      cidr_block: ${network.cidr_block}
      single_nat_gateway: "${topology != 'ha'}"
```

For the `production` context, `platform == 'aws'` is true, so the facet applies. `${network.cidr_block}` reads the context's CIDR and passes it to the VPC module as a string. `${topology != 'ha'}` evaluates to a boolean, so the module gets `true` unless the context asks for a highly available topology.

The language is [expr](https://expr-lang.org), a general-purpose expression language for Go. Comparison and boolean operators, ternaries, string concatenation, and expr's standard library (`map`, `filter`, `get`, `len`) work as [expr's syntax reference](https://expr-lang.org/docs/language-definition) documents them. The one exception is member access, which [Member access is always optional](#member-access-is-always-optional) covers. Windsor adds a fixed set of functions that read environment variables, compute CIDR addresses, parse YAML, and reach into Terraform outputs or secrets.

## Windsor's functions

| Function | Does |
|---|---|
| `env(name)` | Reads an environment variable. Returns nothing when unset. |
| `secret(vault, item, field)` | Resolves a value from a configured secret store when Windsor runs Terraform or applies the blueprint. See [Secrets](../secrets/overview.md). |
| `terraform_output(component, output)` | Reads an output from an already-applied Terraform component. Returns nothing until that component has run. See [Deferred evaluation](#deferred-evaluation). |
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

A blueprint author reaches for these constantly. In `option-workstation.yaml`, `ip: "${cidrhost(network.cidr_block ?? '10.5.0.0/16', 266)}"` places the gateway's internal address at a fixed offset in the workstation network. Everything else in an expression (`??`, `in`, `map`, `filter`, `fromPairs`, `toPairs`, `concat`, `values`) is plain expr, not something Windsor added.

## Member access is always optional

Plain expr distinguishes `a.b` (errors if `a` is missing) from `a?.b` (returns nil instead). Windsor patches every expression so every `.` already behaves like `?.`: `addons.database.enabled` and `addons?.database?.enabled` compile to the same thing. Writing the `?` changes nothing, and there's no way to write a *required* member access in a Windsor expression.

A missing or misspelled path resolves to nil, not an error. What nil becomes depends on where the path appears.

- Alone, or in a boolean context like `when:`, it's `false`.
- Inside a `${...}` substitution embedded in a larger string, it's an empty string.
- Combined with `??`, the fallback wins, the same as if the path had resolved to nil on purpose.

Windsor does this on purpose for `when:`, so that a facet evaluates cleanly against a blueprint that doesn't declare a given config section at all.

For a Terraform `inputs:` field, Windsor drops a nil result from the generated `.tfvars` entirely, rather than writing an empty value. If the module's own `variable` block has no `default`, Terraform's "no value for required variable" check catches it. If the module does have a default, the input falls back to it without a warning. Nothing breaks, but the operator's override doesn't take effect.

Kustomize `substitutions:` and any `${...}` embedded inside a larger string have no such check. Windsor writes a nil result there as a literal empty string, and nothing downstream rejects it.

When a value must be present, declare it under the facet's `requires:` block instead of relying on an expression. Windsor checks for it in the composed scope and fails composition with the block's message, rather than resolving it to nil. The [facets reference](https://www.windsorcli.dev/reference/cli/facets) documents `requires:`.

## Where expressions run

A `when:` on a facet, a config block, or a Terraform or Flux entry must evaluate to a boolean, as [Facets](facets.md) describes. The `value:` of a config block accepts any expression, including nested maps and lists built with `fromPairs` or `map`. A `${...}` substitution can appear in schema values, Terraform `inputs:`, and Kustomize `substitutions:`.

A string that is exactly one `${...}` expression evaluates to that expression's own type, such as a map, a number, or a bool. A `${...}` embedded alongside other text interpolates as a string, and a nil result renders as empty, so `"prefix-${cluster.undefined}-suffix"` becomes `"prefix--suffix"`.

## Deferred evaluation

`terraform_output()` can't resolve before its component has applied. During [`windsor plan`](https://www.windsorcli.dev/reference/cli/commands/plan), or on a facet's first evaluation pass, the referenced component may not have run yet. Windsor leaves an expression that depends on a missing output unevaluated and retries it once its dependency resolves, rather than failing the whole composition. That is why facets that read `terraform_output()` almost always pair it with a fallback, as `addon-database.yaml` does in `cluster_name: "${terraform_output('cluster', 'cluster_name') ?? ''}"`. The blueprint then composes before that Terraform component exists.

`secret()` defers the same way. Composition leaves the call as written, and Windsor resolves it when it runs Terraform for the component or applies the blueprint. That keeps decrypted values out of the composed blueprint and the generated tfvars.

## Reference

- [expr language definition](https://expr-lang.org/docs/language-definition): full syntax and standard library
- [Facets](facets.md): `when:` conditions, ordinals, and config blocks
- [The _template folder](templates.md): composition order and substitution merging
- [Blueprint reference](https://www.windsorcli.dev/reference/cli/blueprint): every field that accepts an expression
