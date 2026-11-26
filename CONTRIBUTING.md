# Contributing

## Ready to merge

The merge bot evaluates a pull request against this section. Every item below has to be true before the pull request is merged.

### Required checks

Run `scripts/check.sh` from the repository root. It checks the root package, `shared/`, and `client/`. In each package it runs `gleam format --check`, `gleam build --warnings-as-errors`, `gleam test`, and glinter.

glinter counts are compared with `lint-baseline.json`. A higher total or a higher per-rule count fails the script. Do not raise a count in that file. When a change touches a file that already has a finding, fix a cheap finding in that file and run `scripts/check.sh --update-lint-baseline` in the same change. That command writes the lower counts and exits non-zero if a count would rise.

GitHub Actions will run the same script in NES-152. Until that workflow exists, `scripts/check.sh` is the gate.

### Required evidence in the PR description

The pull request description must include:

- The `scripts/check.sh` output.
- A screenshot or `curl` output of the user-visible result when the change has one.

### PR and commit conventions

- The branch name and the pull request title include the Linear ID, for example `NES-150`.
- The pull request description links the Linear ticket.

### Merge style

Squash merge.

### Releases and versioning

Every merge to main deploys to Fly.io through [.github/workflows/fly-deploy.yml](.github/workflows/fly-deploy.yml). There is no versioning yet.
