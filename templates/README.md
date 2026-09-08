# Adding a New Template Variant

Variants are folders under `templates/`. `cv.tex` loads
`templates/<DocType>/preamble.tex` + `header.tex`, so a new variant
needs exactly those three files (+ optional `style.tex`).

```bash
cp -r templates/modern templates/academic
# edit templates/academic/{style,preamble,header}.tex
```

Then register the name in `compile.sh` (`DOC_TYPES` list) so
`--academic` builds `out/cv-academic-<lang>.pdf`.
`--check-ats` only enforced for `ats`; other variants warn instead of fail.
