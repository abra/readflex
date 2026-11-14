# Team handoff documentation

[team-handoff.ru.md](team-handoff.ru.md) is the maintained Russian source for
the team handoff PDF. Architecture and package references remain in English.
Update the source when core flows, package responsibilities, build requirements
or production gaps change; export a new PDF for each handoff.
The root README is a quick start. The handoff source keeps the detailed setup,
configuration, signing and verification procedures; package READMEs and
`test/ui/README.md` own their implementation and native-test contracts.

## PDF export

The optional local exporter uses Python 3 with the dependencies pinned in
[pdf-requirements.txt](pdf-requirements.txt). It is separate from the Flutter
build and normal test toolchain. Prepare an isolated environment if needed:

```sh
python3 -m venv .local/handoff/venv
.local/handoff/venv/bin/python -m pip install -r docs/pdf-requirements.txt
```

Run from the repository root, replacing the revision and date with the snapshot
being delivered:

```sh
.local/handoff/venv/bin/python scripts/render_handoff.py \
  --input docs/team-handoff.ru.md \
  --output .local/handoff/Readflex-Team-Handoff.pdf \
  --repository-root . \
  --revision '<commit> + documentation updates' \
  --date YYYY-MM-DD \
  --preview-dir .local/handoff/previews
```

The exporter embeds fonts already in the repository, adds a clickable contents
page and PDF outline, and prints page/size/text statistics. It uses no network
after dependencies are installed. Inspect rendered page previews, tables,
heading breaks, contents destinations and Cyrillic text before delivery.
Standard Markdown headings, lists, tables and fenced code are supported;
Mermaid/browser rendering is not part of this exporter. Code uses the repository
font consistently across hosts; it is not a monospace typesetting engine.

Source links become readable repository paths in a standalone PDF. Optionally
pass `--repository-url https://<host>/<owner>/<repo>` and an exact published
`--revision` to generate browser links. Do not use a dirty-revision annotation
as a remote revision or assume unpublished changes are accessible there.

The source, exporter and dependency pins are versioned. PDF, derived fonts,
previews and diagnostics belong under ignored `.local/handoff/`; archive the
final PDF with its source revision in the team's handoff storage. Keep secrets,
private runtime defines and user books out of the document and its inputs.
