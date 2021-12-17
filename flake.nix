{
  description = "Package build for mobile-core";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.haskellNix.url = "github:input-output-hk/haskell.nix/angerman/aarch64";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { self, haskellNix, nixpkgs, flake-utils }:
    let
        ghcjs = { config = "js-unknown-ghcjs"; };
        x86_64-musl64 = { config = "x86_64-unknown-linux-musl"; };
        aarch64-musl64 = { config = "aarch64-unknown-linux-musl"; };
        systems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
    in
    flake-utils.lib.eachSystem systems (system:
      let pkgs = haskellNix.legacyPackages.${system}; in
      let drv = pkgs': pkgs'.haskell-nix.project {
        compiler-nix-name = "ghc8107";
        index-state = "2020-12-15T00:00:00Z";
        src = pkgs.haskell-nix.haskellLib.cleanGit {
          name = "mobile-core";
          src = ./.;
        };
      }; in
      rec {
        packages = {
          "lib:mobile-core" = (drv pkgs).mobile-core.components.library;
        } // ({ "x86_64-linux" = {
                    "ghcjs:lib:mobile-core" = (drv (haskellNix.internal.compat { inherit system; crossSystem = ghcjs; }).pkgs).mobile-core.components.library;
                    "musl64:lib:mobile-core" = (drv (haskellNix.internal.compat { inherit system; crossSystem = x86_64-musl64; }).pkgs).mobile-core.components.library;
                };
                "aarch64-linux" = {
                    "musl64:lib:mobile-core" = (drv (haskellNix.internal.compat { inherit system; crossSystem = aarch64-musl64; }).pkgs).mobile-core.components.library;
                };
            }.${system} or {});
        # build all packages in hydra.
        hydraJobs = packages;
      }
    );
}