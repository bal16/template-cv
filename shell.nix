# shell.nix — classic fallback, no flakes required: `nix-shell`
# Canonical package list lives in nix/tex.nix (shared with flake.nix).
{ pkgs ? import <nixpkgs> { } }:
pkgs.mkShell {
  packages = import ./nix/tex.nix { inherit pkgs; };
  shellHook = ''
    echo "cv-main env ready: pdflatex + poppler (run ./compile.sh --all --check-ats)"
  '';
}
