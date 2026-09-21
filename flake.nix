# flake.nix — cv-main reproducible LaTeX CV dev environment (canonical).
# Usage: `nix develop` (requires flakes: experimental-features =
# nix-command flakes), then ./compile.sh as usual.
# NOTE: flake.lock is intentionally not committed yet — it is generated on
# first `nix develop` and should be committed as a follow-up.
{
  description = "cv-main — reproducible LaTeX CV dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        # devShell only (no `nix build` package): enter env, run ./compile.sh.
        devShells.default = pkgs.mkShell {
          packages = import ./nix/tex.nix { inherit pkgs; };
          shellHook = ''
            echo "cv-main env ready: pdflatex + poppler (run ./compile.sh --all --check-ats)"
          '';
        };
      });
}
