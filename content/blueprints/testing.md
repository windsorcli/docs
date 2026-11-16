---
title: Testing
description: Check a blueprint's facets and composition with windsor test, using sample values and mock Terraform outputs, without provisioning anything.
---

A change to one [facet](facets.md) can drop a component from a platform you didn't try, and without a test you find out only when `windsor up` runs against that platform. [`windsor test`](https://www.windsorcli.dev/reference/cli/commands/test) composes the blueprint from sample values and checks the result, without provisioning any infrastructure. You write the values and the components you expect in YAML, and the CLI checks that facets and composition produce them.

## What is validated

A test checks these parts of the composed blueprint.

- Facet `when` expressions
- Presence of expected Terraform and Kustomize components
- Absence of excluded components
- Property assertions on components
- Duplicate components, circular dependencies, invalid references (always checked)

## Quick start

Test files live in `contexts/_template/tests/`. This case, trimmed from `core`'s [`platform-aws.test.yaml`](https://github.com/windsorcli/core/blob/main/contexts/_template/tests/platform-aws.test.yaml), composes an AWS context and expects the VPC and the EKS cluster.

```yaml
# contexts/_template/tests/platform-aws.test.yaml
cases:
  - name: minimal config creates VPC, EKS, and GitOps terraform chain
    values:
      platform: aws
      aws:
        region: us-west-2
      gateway:
        enabled: false
    expect:
      terraform:
        - name: network
          path: network/aws-vpc
        - name: cluster
          path: cluster/aws-eks
          dependsOn:
            - network
```

`values` holds what a context's `values.yaml` would hold. With `platform: aws`, the `platform-aws` facet applies, and the case passes when the composed blueprint has a `network` component at `network/aws-vpc` and a `cluster` component that depends on it. This command runs every test in the template.

```bash
windsor test
```

## Test file structure

Test files use the `.test.yaml` extension. Each case has `name` and `values`, and optionally `expect`, `exclude`, and `terraformOutputs`. Expectations match partially: a case lists only the fields it checks, and an array field passes when it contains the listed items.

`exclude` lists components that must not appear. This case, trimmed from `addon-database.test.yaml`, expects no `database` Flux system when Postgres is turned off.

```yaml
cases:
  - name: excludes database when disabled
    values:
      platform: metal
      database:
        postgres:
          enabled: false
    exclude:
      flux:
        - name: database
```

## Mocking Terraform outputs

A facet that reads `terraform_output()` gets nothing during a test, because no component has applied. The case supplies those outputs under `terraformOutputs:`, keyed by component. This mock, from an RDS case in `addon-database.test.yaml`, gives the `network` and `cluster` components the outputs that the database entries read.

```yaml
terraformOutputs:
  network:
    vpc_id: vpc-12345678
    db_subnet_group_name: test-rds
  cluster:
    cluster_name: cluster-test
```

## Running tests

Run every test, or one test by name.

```bash
windsor test              # all tests
windsor test <name>       # one test
```

## Best practices

- Name cases clearly (for example, `{condition}-{expectation}`).
- Test facet boundaries and mutual exclusion.
- Set only the `values` that affect the outcome.
