# Bundled Supplemental Fonts

## Symbol Fallback

`NotoSansSymbols-Regular.ttf` is the complete regular (weight 400) instance of
[Noto Sans Symbols](https://github.com/google/fonts/tree/8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5/ofl/notosanssymbols),
retrieved 2026-09-20. It includes U+267E (permanent paper sign), recycling,
music and other symbols that may occur in book quotations and translations.
This is not a subset tailored to a particular sentence. At about 181 KiB
uncompressed, it avoids bundling unused variable-weight data.

The app's common fallback chain uses it only when the primary UI font lacks
a glyph. The book WebView separately exposes the same asset through the local
reader server and declares it after the selected reading font. The reader's
monospace code stack also uses it for missing symbols. Flutter font
registration alone does not make fonts available inside a WebView. Text contents
are not changed. The font provides monochrome symbols, not complete emoji or
Unicode coverage.

The font is declared in both the app and component-library pubspecs; the app
declaration exposes the short family name used by `AppTypography`.
`OFL-NotoSansSymbols.txt` is included through the package's `flutter.licenses`.
Copyright metadata is retained. No runtime network access is needed.

Reproduce with fontTools 4.39.4 (maintenance only, not a build/test dependency):

```sh
curl -fL 'https://raw.githubusercontent.com/google/fonts/8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5/ofl/notosanssymbols/NotoSansSymbols%5Bwght%5D.ttf' -o NotoSansSymbols-original.ttf
fonttools varLib.instancer NotoSansSymbols-original.ttf wght=400 -o NotoSansSymbols-Regular.ttf
```

SHA-256 of the downloaded source and committed instance:

```text
f7e7e04b4a24b6c78893d50cbfd2b2f6cae49617ab047bfef668d252adb128f7  NotoSansSymbols-original.ttf
544ba22a3cfac2fccc1b7a0c63b4f11af641e12bda0dc2a9419a62c061b8c4b8  NotoSansSymbols-Regular.ttf
```

## Phonetic Font

`NotoSans-Phonetics.ttf` is a static regular subset of
[Noto Sans](https://github.com/google/fonts/tree/main/ofl/notosans), retrieved
2026-09-19. It covers Latin, IPA, combining marks and phonetic extensions rather
than one test word. Geist does not include several common IPA letters. This
subset is used only for pronunciation, not as the application's default font.
It adds about 211 KiB uncompressed and requires no runtime network requests.

Copyright metadata is retained. `OFL-NotoSans.txt` is registered through the
package's `flutter.licenses` so Flutter includes it in the app license bundle.

Reproduce with fontTools (maintenance only, not a build/test dependency):

```sh
python3 -m fontTools.varLib.instancer NotoSans-original.ttf wght=400 wdth=100 -o NotoSans-regular.ttf
python3 -m fontTools.subset NotoSans-regular.ttf \
  --unicodes=U+0020-024F,U+0250-036F,U+1D00-1DBF,U+1E00-1EFF,U+2000-206F,U+2C60-2C7F,U+A720-A7FF,U+AB30-AB6F \
  --output-file=NotoSans-Phonetics.ttf \
  --layout-features='*' --name-IDs='*' --name-languages='*'
```

SHA-256:

```text
bfb7bb691513f12e734dc346c03a03f784912432d7e3fa8e56efcf906fe86b3d  NotoSans-original.ttf
c16df7227398827625a939aa22a01c12f5a18679033a90d61048830858724d90  NotoSans-Phonetics.ttf
```
