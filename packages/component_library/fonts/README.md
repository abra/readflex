# Phonetic Font

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
