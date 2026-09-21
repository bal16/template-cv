# template-cv — CV ATS-Friendly (LaTeX)

Template CV untuk portal kerja ATS (Workday/Taleo/Greenhouse) dan lamaran
langsung (email/networking). Dua mode × dua bahasa, satu perintah build:

|                                        | ID                     | EN                     |
| -------------------------------------- | ---------------------- | ---------------------- |
| ATS (portal kerja)                     | `out/cv-ats-id.pdf`    | `out/cv-ats-en.pdf`    |
| Modern (email/networking/lokal)        | `out/cv-modern-id.pdf` | `out/cv-modern-en.pdf` |

## Cara pakai (pemilik CV)

**1. Isi data diri** di `config/personal.tex` — nama, kontak, tautan.
Untuk menonaktifkan sebuah field, beri `%` di depannya; pemisah `|`
otomatis hilang. Tautan banner dipisah `Url` (tujuan) vs `Label`
(tampilan), mis. `Label` cukup `username` sementara href tetap penuh.

**2. Atur urutan + on/off section** di `config/order.tex` — pindah baris
untuk re-order, beri `%` untuk mematikan section.

**3. Tulis isi per section** di `sections/id/*.tex` atau
`sections/en/*.tex`. Tautan proyek: `\cvLink{url-tanpa-https}{label}`,
gabung beberapa tautan dengan `\cvSep`.

**4. Compile:**

```bash
./compile.sh --all --check-ats   # build 4 PDF + validasi ATS
./compile.sh --ats --en          # satu PDF: out/cv-ats-en.pdf
./compile.sh --modern --id       # satu PDF: out/cv-modern-id.pdf
./compile.sh --ats --watch       # rebuild otomatis saat nulis
```

**Tanpa install apa pun:** pakai Overleaf — upload zip, set main document
`cv.tex`, compile langsung (default: ATS English). Ganti bahasa default di
`cv.tex` (`\providecommand{\Lang}{ID}`) bila perlu.

## Struktur repo

```text
template-cv/
├── cv.tex                  # JANGAN EDIT — root, injeksi DocType x Lang
├── config/personal.tex     # EDIT — nama, kontak, \ShowPhoto
├── config/order.tex        # EDIT — urutan + on/off section
├── templates/ats/          # sangat ketat: tanpa foto/ikon/tikz/tabel
├── templates/modern/       # aksen + fontawesome5 + foto opsional
├── sections/id/*.tex       # EDIT per-section (Indonesia)
├── sections/en/*.tex       # EDIT per-section (Inggris)
├── assets/                 # taruh photo.jpg formal di sini (opsional)
├── scripts/                # lib, ats-check, watch (dipakai compile.sh)
├── completions/            # autocomplete shell → lihat completions/README.md
├── nix/ + flake.nix        # env reproducible (nix develop / nix-shell)
├── .envrc                  # opsional, pengguna direnv saja
├── compile.sh              # build + --check-ats
├── CHANGELOG               # riwayat rilis
└── out/                    # hasil PDF (git-ignored)
```

## Aturan ATS strict

Satu kolom, font standar (Latin Modern Sans), margin 1,7cm,
section kapital + garis sederhana, bullet `itemize`, hyperlink polos.
Tanpa: foto, ikon font, tabel kompleks, `tikz`, `multicol`, background.

Mode Modern boleh: foto formal (`\ShowPhoto{true}` + `assets/photo.jpg`),
ikon FontAwesome, warna aksen. Tetap satu kolom.

## Untuk developer

- **Prasyarat:** TeX Live wajib (`pdflatex`); poppler opsional
  (`pdftotext` + `pdfinfo`, hanya untuk `--check-ats`). Paket LaTeX yang
  hilang dicoba di-install otomatis via `tlmgr`
  (atau `--skip-deps` untuk lewati cek).

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

- **Autocomplete shell:** `./completions/install.sh` —
  detail di [completions/README.md](completions/README.md).
- **Tambah varian ke-3:** panduan di [templates/README.md](templates/README.md).
- **Riwayat perubahan:** [CHANGELOG](CHANGELOG).
