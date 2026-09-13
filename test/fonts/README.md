# Golden Test Fonts

These fonts are loaded by `test/ui/golden_support.dart`, not declared in any
application asset manifest. They do not increase the installed application size.
They make fallback text in widget goldens deterministic instead of using the
test renderer's missing-glyph boxes or a host-dependent font.

Geist, Literata, and Lucide come from the application's existing package assets.
Additional fonts come from the Google Fonts repository (retrieved 2026-09-13):

| Local file | Upstream | License |
| --- | --- | --- |
| `NotoSansArabic.ttf` | [Noto Sans Arabic](https://github.com/google/fonts/tree/main/ofl/notosansarabic) | `OFL-NotoSansArabic.txt` |
| `NotoSansDevanagari.ttf` | [Noto Sans Devanagari](https://github.com/google/fonts/tree/main/ofl/notosansdevanagari) | `OFL-NotoSansDevanagari.txt` |
| `NotoSansJP.ttf` | [Noto Sans JP](https://github.com/google/fonts/tree/main/ofl/notosansjp) | `OFL-NotoSansJP.txt` |
| `NotoSansSC.ttf` | [Noto Sans SC](https://github.com/google/fonts/tree/main/ofl/notosanssc) | `OFL-NotoSansSC.txt` |

Arabic and Devanagari are unmodified variable fonts. The Japanese font is a
small fontTools subset containing the Japanese language name and shared CJK
characters. The Simplified Chinese subset supplies the complete Chinese
language label, including parentheses and characters missing from the JP font.
These are not complete CJK test fonts. Expand the subsets before adding golden
profiles containing other CJK text.
Upstream copyright metadata and SIL Open Font License files are retained.

SHA-256 of the committed files:

```text
63111b5b2e074dd48cc67692e0a2726d86ee94c1c37fe8598257b7b4e87e869e  NotoSansArabic.ttf
14ec4af41f27482216d1c2229f417ff9b1425e1babb014e57d1d40d03229853e  NotoSansDevanagari.ttf
309822629e8e9e23884e2c148d2536e599c80733664700041252f3696204cd1c  NotoSansJP.ttf
98f147c154a78ae166506e6a372df7692ef3b26cb5e3f9ac81c05c0da4233760  NotoSansSC.ttf
```

The original `NotoSansJP[wght].ttf` had SHA-256
`c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f`.
To reproduce the subset from that upstream file:

```sh
pyftsubset .local/NotoSansJP-original.ttf \
  --unicodes=U+65E5,U+672C,U+8A9E,U+4E2D,U+6587 \
  --output-file=test/fonts/NotoSansJP.ttf \
  --layout-features='*' --name-IDs='*' --name-languages='*'
```

The original `NotoSansSC[wght].ttf` had SHA-256
`a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da`.
To reproduce its subset:

```sh
pyftsubset .local/NotoSansSC-original.ttf \
  --unicodes=U+4E2D,U+6587,U+FF08,U+FF09,U+7B80,U+4F53 \
  --output-file=test/fonts/NotoSansSC.ttf \
  --layout-features='*' --name-IDs='*' --name-languages='*'
```

Font fetching/subsetting is a maintenance operation, not part of a test run.
Fresh checkouts run tests from the committed font files without downloading
fonts or installing fontTools.
