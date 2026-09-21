# template-cv — CV ATS-Friendly (LaTeX)

Dual-mode x dual-bahasa, meniru pola `@template-ta/`:

|                                        | ID                     | EN                     |
| -------------------------------------- | ---------------------- | ---------------------- |
| ATS (portal: Workday/Taleo/Greenhouse) | `out/cv-ats-id.pdf`    | `out/cv-ats-en.pdf`    |
| Modern (email/networking/lokal)        | `out/cv-modern-id.pdf` | `out/cv-modern-en.pdf` |

## Struktur

```text
template-cv/
├── cv.tex                  # DO NOT EDIT — root, DocType x Lang injection
├── config/personal.tex     # EDITABLE — nama, kontak, \ShowPhoto
├── config/order.tex        # EDITABLE — urutan + on/off section
├── templates/ats/          # ultra-strict: no foto/ikon/tikz/tabel
├── templates/modern/       # accent + fontawesome5 + foto opsional
├── templates/README.md     # cara tambah varian ke-3
├── sections/id/*.tex       # EDITABLE per-section (Indonesia)
├── sections/en/*.tex       # EDITABLE per-section (Inggris)
├── assets/                 # taruh photo.jpg formal di sini (opsional)
├── compile.sh              # build + --check-ats
└── out/                    # hasil PDF (git-ignored)
```

## Prerequisites

Wajib: TeX Live (`pdflatex`). Opsional: poppler (`pdftotext` + `pdfinfo`,
hanya untuk `--check-ats`). Paket LaTeX yang hilang dicoba di-install
otomatis via `tlmgr` (atau pakai `--skip-deps` untuk bypass cek).

```bash
# Arch Linux (preferensi repo ini)
sudo pacman -S texlive-basic texlive-latexrecommended texlive-latexextra \
  texlive-fontsrecommended texlive-fontsextra poppler
# - fontsextra: fontawesome5 (mode Modern) | fontsrecommended: lmodern (mode ATS)

# Nix (reproducible, tanpa install manual)
nix develop   # flakes (experimental-features = nix-command flakes)
nix-shell     # klasik, tanpa setting tambahan
# → pdflatex + poppler siap, langsung ./compile.sh --all --check-ats

# Debian / Ubuntu
sudo apt install texlive-latex-recommended texlive-latex-extra \
  texlive-fonts-recommended lmodern poppler-utils

# Fedora
sudo dnf install texlive-scheme-medium texlive-fontawesome5 lmodern poppler-utils

# macOS (Homebrew)
brew install --cask mactex-no-gui   # TeX Live lengkap
brew install poppler                 # untuk --check-ats

# Windows: install MiKTeX atau TeX Live, paket di-install otomatis saat compile.
```

Tanpa install lokal: pakai Overleaf (lihat bawah) — cukup upload zip.

## Quick start

```bash
./compile.sh --all --check-ats   # build 4 PDF + validasi ATS
./compile.sh --ats --en          # satu PDF: out/cv-ats-en.pdf
./compile.sh --modern --id       # satu PDF: out/cv-modern-id.pdf
./compile.sh --ats --watch       # live rebuild saat nulis
```

## Aturan ATS strict

Single-column, font standar (Latin Modern Sans), margin 1.7cm,
section uppercase + rule sederhana, bullet `itemize`, hyperlink polos.
Tanpa: foto, ikon font, tabel kompleks, `tikz`, `multicol`, background.

Mode Modern boleh: foto formal (`\ShowPhoto{true}` + `assets/photo.jpg`),
ikon FontAwesome, warna aksen. Tetap single-column.

## Overleaf

Upload zip, set main document `cv.tex`, compile langsung
(default: ATS English). Ganti default bahasa di `cv.tex`
(`\providecommand{\Lang}{ID}`) bila perlu.
