# Skillbox

Skillbox is cli for agent skills.

**Feature**

- Discover local Agent Skills
- Search skills through their descriptions
- Recommend skills using system one models (e.g. jev, classifier.dev)

## Quick start

```sh
nix develop
moon run --target native src/cmd/skillbox -- list
moon run --target native src/cmd/skillbox -- get agent-browser
moon run --target native src/cmd/skillbox -- search 'browser testing'
moon run --target native src/cmd/skillbox -- recommend 'test browser forms'
moon run --target native src/cmd/skillbox -- recommend 'test browser forms' --format=json
```

Pass a `search` or `recommend` query as **one argument**; quote it if it contains spaces. `list`, `get`, and `search` work offline. `get <name>` looks up an exact, case-sensitive skill name and prints the path to its `SKILL.md`; a missing name is an error.

By default, `list`, `search`, and `recommend` print `name`, `relevance`, and `path` columns; `get` prints only the raw path. `--format=json` yields an array of `{name, relevance, path}` for the first three commands and a JSON string for `get`. List/search relevance is `null` in JSON and `-` in the table. Table cells display terminal control characters as visible escapes. Use `--` to search for the literal query `--format=json`.

## Discovery

Skillbox recursively finds `SKILL.md` under `~/.agents/skills/` and `<nearest Git root>/.agents/skills/`. It follows directory symlinks, including links outside these roots, while avoiding cycles and duplicate real files. An invalid file is skipped with a path-bearing diagnostic; duplicate skill names within one root are an error. The project root is searched first, so its names override home skills. Results are sorted by name.

Only the YAML frontmatter's nonempty string `name` and `description` are used for search and recommendation. Other frontmatter fields and the Markdown body are not used for classification. The parser does not enforce every [Agent Skills naming rule](https://agentskills.io/specification).

## Recommendation and privacy

`recommend` uses [classifier.dev](https://classifier.dev/) by default, via HTTPS. Its **no-key free tier** works without an account or API key; usage limits and availability are set by the provider and may change ([API specification](https://classifier.dev/openapi.json)). The classifier selects directly applicable skills; Skillbox displays at most five in relevance order. Relevance is a relative classification score, **not** a calibrated probability or a guarantee of recommendation quality. Current quality checks used only small synthetic and local examples.

**External data:** Skillbox sends the query and every discovered skill's `name` and `description` to classifier.dev, along with fixed classification labels and instructions. It does **not** send the `SKILL.md` body, file paths, or other frontmatter fields. Symlinks in an untrusted project may bring in skills from outside the discovery roots; inspect them before recommending. Do not include sensitive text in queries or descriptions unless you are willing to send it to the service. `SKILLBOX_CLASSIFIER_BASE_URL` overrides the service origin for testing and sends this same data to the chosen endpoint.

A request supports at most 1,000 skills and 32,000 characters per assembled classification input (query plus skill metadata); larger inputs fail rather than being truncated. The recommendation operation has a 15-second timeout. HTTP 429/5xx responses with a valid `Retry-After` of 0 or 1 second may be retried twice; other failures are reported rather than replaced with search results. An empty catalog makes no HTTP request.

## Architecture and development

- `src/core/`: parsing, discovery, merging, search, recommendation, and pure table/JSON formatting. Async use cases receive FS/HTTP operations as dependencies; core imports no concrete FS or HTTP client.
- `src/cmd/skillbox/`: native CLI, environment and discovery roots, real FS/HTTP adapters, retries, timeout, and terminal I/O.

```sh
nix develop --command moon check --target all --warn-list +73
nix develop --command moon test --target all
nix develop --command moon build --target all
```

Core's synchronous API is tested on native, wasm, wasm-gc, and js. Async use cases are tested with fake hosts on native, wasm, and js; wasm-gc compiles them but does not support their execution. The CLI is native-only.
