# Contributing

## Ready to merge

The merge bot evaluates a pull request against this section. Every item below has to be true before the pull request is merged.

### Required checks

Run these three commands in each Gleam package. The packages are the repository root (the Wisp/Mist server), `shared/`, and `client/`.

- `gleam format --check`
- `gleam test`
- `gleam build`

All of them must succeed. GitHub Actions will run the same checks later in NES-152. Until that workflow exists, run them locally.

### Required evidence in the PR description

The pull request description must include:

- The commands you ran, pasted with their real output. That means `gleam format --check`, `gleam test`, and `gleam build` for each package above.
- A screenshot or `curl` output of the user-visible result.

### PR and commit conventions

- The branch name and the pull request title include the Linear ID, for example `NES-150`.
- The pull request description links the Linear ticket.

### Merge style

Squash merge.

### Releases and versioning

No releases yet; deploys to Fly.io are covered by NES-158; versioning to be decided.
