# Independent Archive

This repository is an independent, non-fork archive of
[`wtfwhs/tengu-decoded`](https://github.com/wtfwhs/tengu-decoded). The original
material remains licensed under CC BY 4.0 and is attributed to `whs` in
[`LICENSE`](LICENSE).

## Retention model

- `main` contains the initially cloned source, archive automation, and ongoing
  analysis reports.
- `upstream/<branch>` tracks the latest observed tip of each upstream branch.
- `archive/heads/<branch>/<timestamp>-<object>` is an immutable tag for every
  distinct upstream branch tip observed by the monitor.
- `archive/tags/<tag>/<timestamp>-<object>` preserves every distinct upstream
  tag object observed by the monitor.
- `upstream/<tag>` mirrors the latest observed target of an upstream tag.
- `analysis/upstream-updates/` records tree and commit differences whenever
  upstream `main` changes.

The monitor never deletes a snapshot tag or a retained live pointer. A later
force-push, branch deletion, tag replacement, squash, or empty-tree commit
therefore cannot make an already observed object unreachable in this archive.
The unavoidable boundary is observation frequency: a ref created and deleted
entirely between two monitor runs cannot be captured.

The scheduled workflow runs at minutes 7 and 37 of every hour and can also be
started manually from the Actions tab.

## Recovery examples

List observed snapshots of upstream `main`:

```bash
git tag --list 'archive/heads/main/*' --sort=-refname
```

Restore a snapshot as a local branch:

```bash
git switch -c recovered-main 'archive/heads/main/<timestamp>-<object>'
```

Compare two observations:

```bash
git diff 'archive/heads/main/<older>' 'archive/heads/main/<newer>'
```
