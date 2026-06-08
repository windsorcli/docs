---
title: Blueprint testing
description: Static testing for blueprint composition.
---

Windsor's `windsor test` command validates blueprint composition without provisioning infrastructure. You define input values and expected components in YAML; the CLI checks that [facets](/blueprints/facets) and composition behave as expected.

## What is validated

- Facet `when` expressions
- Presence of expected Terraform and Kustomize components
- Absence of excluded components
- Property assertions on components
- Duplicate components, circular dependencies, invalid references (always checked)

## Quick start

Create a test file under `contexts/_template/tests/`:

```yaml
# contexts/_template/tests/provider.test.yaml
cases:
  - name: aws-provider-includes-vpc
    values:
      provider: aws
    expect:
      terraform:
        - name: vpc
          source: core
```

Run:

```bash
windsor test
```

## Test file structure

Use the `.test.yaml` extension. Each case has `name`, `values`, and optionally `expect`, `exclude`, `terraformOutputs`. Expectations use **partial matching**; array fields use "contains" semantics.

## Mocking Terraform outputs

When blueprints use `terraform_output()` in [facets](/blueprints/facets), provide mock outputs in the test:

```yaml
terraformOutputs:
  network:
    vpc_id: "vpc-123456"
    subnet_ids: ["subnet-abc", "subnet-def"]
```

## Running tests

```bash
windsor test              # all tests
windsor test test-name    # specific test
```

## Best practices

- Name cases clearly (for example, `{condition}-{expectation}`).
- Test facet boundaries and mutual exclusion.
- Set only the `values` that affect the outcome.
