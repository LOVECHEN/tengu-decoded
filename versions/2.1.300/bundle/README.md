# v2.1.300 bundle

From 2.1.300 onward, Claude Code ships as a **code-split ESM** Bun executable: 2,651 files embedded in the
ELF `.bun` section rather than one CommonJS bundle. `extract.py` parses Bun's module table and writes
everything in this folder.

| File | Committed | What it is |
|---|---|---|
| `extract.py` | yes | Parses the `.bun` section (module table: 2,651 records × 52 bytes) and writes the files below |
| `cli.min.js` | yes | All 2,401 application JS modules concatenated in module-table order, each preceded by `//// ===== MODULE <id> <name> (<bytes> bytes) =====` |
| `manifest.tsv` | yes | One row per embedded file: id, name, size, bytecode size, flags, sha256, whether it is in `cli.min.js` |
| `modules/` | yes | Every embedded file not in `cli.min.js` (assets, vendored libraries, native addons); each `.zst` has a decompressed sibling |
| `cli.beauty.js` | **no** | Beautified `cli.min.js`. Regenerate it locally (below) |
| `../data/raw/strings-full.txt`, `strings-long-prompts.txt` | **no** | Full `strings` dumps of the binary. Regenerate them locally (below) |
| `ANALYSIS_CONTEXT.md`, `_facts.md` | yes | Ground truth and canonical counts shared by the analysis |

## Regenerating `cli.beauty.js`

The analysis cites `cli.beauty.js:LINE` throughout. It is left out of git to save 60 MB per version, and
it is deterministic, so you can rebuild it byte-for-byte:

```bash
npx --yes js-beautify@1.15.1 --indent-size 2 -o cli.beauty.js cli.min.js
```

On ~46 MB of input, Node may need a bigger heap: prefix the command with `NODE_OPTIONS=--max-old-space-size=12288`.

Check that the result matches the file the line numbers refer to:

| File | Bytes | Lines | SHA-256 |
|---|---|---|---|
| `cli.min.js` | 46,253,541 | 56,440 | `cb3807a756a304ce64e95fb9755b264d021c364a399b8e401ea8a5b22f137a31` |
| `cli.beauty.js` | 60,301,182 | 1,857,789 | `a25d9fb3ecfc14caad535e27cc81f78012a5b0fda237581e842131d87de2e290` |

## Raw string dumps (not committed)

The two full string dumps under `../data/raw/` are also left out of git (106 MB together). The small
extracts derived from them (`strings-tengu.txt`, `strings-urls.txt`, `strings-env-vars.txt`,
`env-claude.txt`, `models.txt`) are committed. Regenerate the dumps from the binary with
GNU strings (GNU Binutils for Ubuntu) 2.46:

```bash
BIN=~/.local/share/claude/versions/2.1.300
strings -n 6   "$BIN" > ../data/raw/strings-full.txt
strings -n 300 "$BIN" > ../data/raw/strings-long-prompts.txt
```

| File | Bytes | Lines | SHA-256 |
|---|---|---|---|
| `strings-full.txt` | 61,030,348 | 566,014 | `1fc99ad4a9f36fb0d1cba7edd0137d5b2556ad82f241cfd182f677d1cde2776d` |
| `strings-long-prompts.txt` | 45,191,665 | 7,963 | `fc9d0e4257da0314e6dbf4fef6aa6d5c1b6d2854a07804d55a49b88929d2a3a3` |

Other binutils versions may produce slightly different output.

## Re-extracting from the binary

```bash
python3 -I extract.py ~/.local/share/claude/versions/2.1.300 .
```

`extract.py` finds the `.bun` section from the ELF section headers (it is at `0x5c93000` in this build),
so it also works on other Bun-compiled Linux builds as long as Bun's module-table layout
(52-byte records, 32-byte `Offsets` struct) hasn't changed. Running it on this binary reproduces
`cli.min.js`, `manifest.tsv` and `modules/` byte-for-byte.
