{
  description = "Package build for mobile-core";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.haskellNix.url = "github:input-output-hk/haskell.nix/angerman/aarch64";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { self, haskellNix, nixpkgs, flake-utils }:
    let systems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ]; in
    flake-utils.lib.eachSystem systems (system:
      let pkgs = haskellNix.legacyPackages.${system}; in
      let drv = pkgs.haskell-nix.project {
        compiler-nix-name = "ghc8107";
        index-state = "2020-12-15T00:00:00Z";
        src = pkgs.haskell-nix.haskellLib.cleanGit {
          name = "mobile-core";
          src = ./.;
        };
      }; in
      rec {
        packages = {
          "lib:mobile-core" = drv.mobile-core.components.library;
        };
        # build all packages in hydra.
        hydraJobs = packages;
      }
    );
}