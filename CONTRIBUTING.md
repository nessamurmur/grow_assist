# Contributing

## Ready to merge

The merge bot evaluates a pull request against this section. Every item below has to be true before the pull request is merged.

### Required checks

Run `scripts/check.sh` from the repository root. It checks the root package, `shared/`, and `client/`. In each package it runs `gleam format --check`, `gleam build --warnings-as-errors`, `gleam test`, and glinter. A `gleam.toml` for any other package fails the script, including when you name one package. Each package it finds needs an entry in `lint-baseline.json`. `build/`, `_build/`, and `deps/` are ignored.

glinter counts are compared with `lint-baseline.json`. A higher total or a higher per-rule count fails the script. Do not raise a count in that file. When a change touches a file that already has a finding, fix a cheap finding in that file and run `scripts/check.sh --update-lint-baseline` in the same change. That command writes the lower counts and exits non-zero if a count would rise.

`scripts/check.sh` is the local Gleam gate. The CI workflow must be green before merge. It runs `scripts/check.sh` for the root package, `shared/`, and `client/`, and it runs `mix format --check-formatted` and `mix hex.audit` in `elixir/`. The same workflow runs `scripts/a11y.sh` in the `a11y` job. A failure in that job fails the workflow, so it blocks merge and the Fly deploy.

`scripts/a11y.sh` builds `priv/static/client.js`, starts `gleam run` on port 8080 when that port is closed, and checks `http://127.0.0.1:8080`. The script does not call a model and does not read an API key.

`@axe-core/playwright` is the merge bar. It runs the key views in `a11y/axe.spec.ts` in dark and light, at 360px and 1280px. The empty form and the results view also run in light with forced colours. Light and forced-colours runs inject `design/tokens/build/light.css` through `a11y/light-remap.css`. The tags are `wcag2a`, `wcag2aa`, `wcag21aa`, and `wcag22aa`. A serious or critical violation fails the job. The bar is 0. `forcedColorsRuleIds` in `a11y/key-views.ts` is the only allow-list, and it applies only to the forced-colours runs. That list is empty.

The API key step is a skipped test marked PENDING until the just-in-time key step ships.

Lighthouse CI (`@lhci/cli`) runs on `/` only. It asserts `categories:accessibility` at minScore 1.0. The score is a trend. A passing Lighthouse score does not waive an axe violation.

Results, Loading, and Server Problem stub `POST /analyze` in the browser. Offline aborts that request.

### Required evidence in the PR description

The pull request description must include:

- The `scripts/check.sh` output.
- A screenshot or `curl` output of the user-visible result when the change has one.
- For an accessibility change: the CI run on the head commit, the `axe-results` artifact, and the `lighthouse-reports` artifact.
- Screenshots of the running app for the empty form with Seedling selected, a field error, loading, stubbed results, a server problem, and offline. Include dark and light, at 360 and 1280.
- The rule ids in `forcedColorsRuleIds` when that list is not empty.
- A CI run where a deliberate serious or critical break failed the axe job. That commit is not the merged commit.

### PR and commit conventions

- The branch name and the pull request title include the Linear ID, for example `NES-150`.
- The pull request description links the Linear ticket.

### Merge style

Squash merge.

### Releases and versioning

Every merge to main runs CI. Fly.io deploys the latest commit on main through [.github/workflows/fly-deploy.yml](.github/workflows/fly-deploy.yml) only after CI succeeds on it. Re-running CI for an older commit does not deploy. There is no versioning yet.
