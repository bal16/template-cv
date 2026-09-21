# nix/tex.nix — shared package list for cv-main dev shells.
# Takes nixpkgs as argument so flake.nix and shell.nix stay in sync.
# Edit here once; both entry points pick it up.
{ pkgs }:
let
  tex = pkgs.texlive.combine {
    # scheme-medium covers geometry/titlesec/enumitem/hyperref/lmodern/
    # xcolor/graphicx/ifthen/url; fontawesome5 is explicit (Modern icons).
    inherit (pkgs.texlive) scheme-medium fontawesome5;
  };
in
[
  tex
  # poppler_utils = pdftotext + pdfinfo, only needed for --check-ats.
  pkgs.poppler_utils
]
