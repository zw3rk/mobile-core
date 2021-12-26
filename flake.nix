{
  description = "Package build for mobile-core";
  inputs.nixpkgs.url = "github:angerman/nixpkgs/patch-1"; # based on 21.11
  inputs.haskellNix.url = "github:input-output-hk/haskell.nix/angerman/aarch64";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { self, haskellNix, nixpkgs, flake-utils }:
    let systems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ]; in
    flake-utils.lib.eachSystem systems (system:
      let pkgs = haskellNix.legacyPackages2111Patched.${system}; in
      let drv = pkgs': pkgs'.haskell-nix.project {
        compiler-nix-name = "ghc8107";
        index-state = "2020-12-15T00:00:00Z";
        src = pkgs.haskell-nix.haskellLib.cleanGit {
          name = "mobile-core";
          src = ./.;
        };
      }; in
      # let mkPkg = drv: {
      # # drv.override { postInstall = ''
      #     # mkdir -p $out/
      #     # zip -r -9 $out/${pkgs.stdenv.hostPlatform.config}-cardano-node-${cardano-node-info.rev or "unknown"}.zip cardano-node

      #     # mkdir -p $out/nix-support
      #     # echo "file binary-dist \"$(echo $out/*.zip)\"" \
      #     #   > $out/nix-support/hydra-build-products
      # # ''; }
      # };
      rec {
        packages = {
          "lib:mobile-core" = (drv pkgs).mobile-core.components.library;
          "lib:mobile-core:static" = (drv pkgs).mobile-core.components.library.override {
            enableShared = false;
            ghcOptions = [ "-staticlib" ];
            postInstall = ''
              ${pkgs.tree}/bin/tree $out
              mkdir -p $out/_pkg
              # copy over includes, we might want those, but maybe not.
              cp -r $out/lib/*/*/include $out/_pkg/
              # find the libHS...ghc-X.Y.Z.a static library; this is the
              # rolled up one with all dependencies included.
              find ./dist -name "libHS*-ghc*.a" -exec cp {} $out/_pkg \;

              find ${pkgs.libffi.overrideAttrs (old: { dontDisableStatic = true; })}/lib -name "*.a" -exec cp {} $out/_pkg \;
              find ${pkgs.gmp6.override { withStatic = true; }}/lib -name "*.a" -exec cp {} $out/_pkg \;
              
              ${pkgs.tree}/bin/tree $out/_pkg
              (cd $out/_pkg; ${pkgs.zip}/bin/zip -r -9 $out/pkg.zip *)
              rm -fR $out/_pkg

              mkdir -p $out/nix-support
              echo "file binary-dist \"$(echo $out/*.zip)\"" \
                  > $out/nix-support/hydra-build-products
            '';
          };
          "exe:mobile-core:mobile-core" = (drv pkgs).mobile-core.components.exes.mobile-core.override {
            postInstall = ''
              ${pkgs.tree}/bin/tree $out
            '';
          };
          "exe:mobile-core:mobile-core-c" = (drv pkgs).mobile-core.components.exes.mobile-core-c.override {
            postInstall = ''
              ${pkgs.tree}/bin/tree $out
            '';
          };
          # "lib:ffi:static" = pkgs.libffi.overrideAttrs (old: { dontDisableStatic = true; });
          # "lib:gmp:static" = pkgs.gmp6.override { withStatic = true; };
        } // ({ "x86_64-linux" = let muslPkgs = pkgs.pkgsCross.musl64; androidPkgs = pkgs.pkgsCross.aarch64-android; in {
                    "ghcjs:lib:mobile-core" = (drv pkgs.pkgsCross.ghcjs).mobile-core.components.library;

                    # "musl64:lib:ffi:static" = muslPkgs.libffi.overrideAttrs (old: { dontDisableStatic = true; });
                    # "musl64:lib:gmp:static" = muslPkgs.gmp6.override { withStatic = true; };
                    "musl64:lib:mobile-core" = (drv muslPkgs).mobile-core.components.library;
                    "musl64:exe:mobile-core:mobile-core" = (drv muslPkgs).mobile-core.components.exes.mobile-core;
                    "musl64:exe:mobile-core:mobile-core-c" = (drv muslPkgs).mobile-core.components.exes.mobile-core-c;
                    "musl64:lib:mobile-core:smallAddressSpace" = (drv muslPkgs).mobile-core.components.library.override {
                      smallAddressSpace = true; enableShared = false;
                      ghcOptions = [ "-staticlib" ];
                      postInstall = ''
                        ${pkgs.tree}/bin/tree $out
                        mkdir -p $out/_pkg
                        # copy over includes, we might want those, but maybe not.
                        cp -r $out/lib/*/*/include $out/_pkg/
                        # find the libHS...ghc-X.Y.Z.a static library; this is the
                        # rolled up one with all dependencies included.
                        find ./dist -name "libHS*-ghc*.a" -exec cp {} $out/_pkg \;

                        find ${muslPkgs.libffi.overrideAttrs (old: { dontDisableStatic = true; })}/lib -name "*.a" -exec cp {} $out/_pkg \;
                        find ${muslPkgs.gmp6.override { withStatic = true; }}/lib -name "*.a" -exec cp {} $out/_pkg \;
                        find ${muslPkgs.stdenv.cc.libc}/lib -name "*.a" -exec cp {} $out/_pkg \;
                        
                        ${pkgs.tree}/bin/tree $out/_pkg
                        (cd $out/_pkg; ${pkgs.zip}/bin/zip -r -9 $out/pkg.zip *)
                        rm -fR $out/_pkg

                        mkdir -p $out/nix-support
                        echo "file binary-dist \"$(echo $out/*.zip)\"" \
                           > $out/nix-support/hydra-build-products
                      '';
                    };


                    "aarch64-android:lib:ffi:static" = androidPkgs.libffi.overrideAttrs (old: {
                      dontDisableStatic = true;
                      hardeningDisable = [ "fortify" ];
                    });
                    # "aarch64-android:lib:gmp:static" = androidPkgs.gmp6.override { withStatic = true; };
                    "aarch64-android:lib:iconv:static" = androidPkgs.libiconv.override { enableStatic = true; };
                    "aarch64-android:lib:mobile-core" = (drv androidPkgs).mobile-core.components.library;
                    "aarch64-android:exe:mobile-core:mobile-core" = (drv androidPkgs).mobile-core.components.exes.mobile-core;
                    "aarch64-android:exe:mobile-core:mobile-core-c" = (drv androidPkgs).mobile-core.components.exes.mobile-core-c;
                    "aarch64-android:lib:mobile-core:smallAddressSpace" = (drv androidPkgs).mobile-core.components.library.override {
                      smallAddressSpace = true; enableShared = false;
                      ghcOptions = [ "-staticlib" ];
                      postInstall = ''
                        ${pkgs.tree}/bin/tree $out
                        mkdir -p $out/_pkg
                        # copy over includes, we might want those, but maybe not.
                        cp -r $out/lib/*/*/include $out/_pkg/
                        # find the libHS...ghc-X.Y.Z.a static library; this is the
                        # rolled up one with all dependencies included.
                        find ./dist -name "libHS*-ghc*.a" -exec cp {} $out/_pkg \;

                        find ${androidPkgs.libffi.overrideAttrs (old: { dontDisableStatic = true; })}/lib -name "*.a" -exec cp {} $out/_pkg \;
                        find ${androidPkgs.gmp6.override { withStatic = true; }}/lib -name "*.a" -exec cp {} $out/_pkg \;
                        find ${androidPkgs.libiconv.override { enableStatic = true; }}/lib -name "*.a" -exec cp {} $out/_pkg \;
                        find ${androidPkgs.stdenv.cc.libc}/lib -name "*.a" -exec cp {} $out/_pkg \;
                        
                        ${pkgs.tree}/bin/tree $out/_pkg
                        (cd $out/_pkg; ${pkgs.zip}/bin/zip -r -9 $out/pkg.zip *)
                        rm -fR $out/_pkg

                        mkdir -p $out/nix-support
                        echo "file binary-dist \"$(echo $out/*.zip)\"" \
                           > $out/nix-support/hydra-build-products
                      '';
                    };

                };
                "aarch64-linux" = let muslPkgs = pkgs.pkgsCross.aarch64-multiplatform-musl; androidPkgs = pkgs.pkgsCross.aarch64-android; in {
                    # "musl64:lib:ffi:static" = muslPkgs.libffi.overrideAttrs (old: { dontDisableStatic = true; });
                    # "musl64:lib:gmp:static" = muslPkgs.gmp6.override { withStatic = true; };
                    "musl64:lib:mobile-core" = (drv muslPkgs).mobile-core.components.library;
                    "musl64:exe:mobile-core:mobile-core" = (drv muslPkgs).mobile-core.components.exes.mobile-core;
                    "musl64:exe:mobile-core:mobile-core-c" = (drv muslPkgs).mobile-core.components.exes.mobile-core-c;
                    "musl64:lib:mobile-core:smallAddressSpace" = (drv muslPkgs).mobile-core.components.library.override {
                      smallAddressSpace = true; enableShared = false;
                      ghcOptions = [ "-staticlib" ];
                      postInstall = ''
                        ${pkgs.tree}/bin/tree $out
                        mkdir -p $out/_pkg
                        # copy over includes, we might want those, but maybe not.
                        cp -r $out/lib/*/*/include $out/_pkg/
                        # find the libHS...ghc-X.Y.Z.a static library; this is the
                        # rolled up one with all dependencies included.
                        find ./dist -name "libHS*-ghc*.a" -exec cp {} $out/_pkg \;

                        find ${muslPkgs.libffi.overrideAttrs (old: { dontDisableStatic = true; })}/lib -name "*.a" -exec cp {} $out/_pkg \;
                        find ${muslPkgs.gmp6.override { withStatic = true; }}/lib -name "*.a" -exec cp {} $out/_pkg \;
                        find ${muslPkgs.stdenv.cc.libc}/lib -name "*.a" -exec cp {} $out/_pkg \;
                        
                        ${pkgs.tree}/bin/tree $out/_pkg
                        (cd $out/_pkg; ${pkgs.zip}/bin/zip -r -9 $out/pkg.zip *)
                        rm -fR $out/_pkg

                        mkdir -p $out/nix-support
                        echo "file binary-dist \"$(echo $out/*.zip)\"" \
                           > $out/nix-support/hydra-build-products
                      '';
                    };

                    # "android64:exe:mobile-core:mobile-core" = (drv androidPkgs).mobile-core.components.exes.mobile-core;
                    # "android64:exe:mobile-core:mobile-core-c" = (drv androidPkgs).mobile-core.components.exes.mobile-core-c;
                    # "android64:lib:mobile-core:smallAddressSpace" = (drv androidPkgs).mobile-core.components.library.override {
                    #   smallAddressSpace = true; enableShared = false;
                    #   ghcOptions = [ "-staticlib" ];
                    #   postInstall = ''
                    #     ${pkgs.tree}/bin/tree $out
                    #     mkdir -p $out/_pkg
                    #     # copy over includes, we might want those, but maybe not.
                    #     cp -r $out/lib/*/*/include $out/_pkg/
                    #     # find the libHS...ghc-X.Y.Z.a static library; this is the
                    #     # rolled up one with all dependencies included.
                    #     find ./dist -name "libHS*-ghc*.a" -exec cp {} $out/_pkg \;

                    #     find ${androidPkgs.libffi.overrideAttrs (old: { dontDisableStatic = true; })}/lib -name "*.a" -exec cp {} $out/_pkg \;
                    #     find ${androidPkgs.gmp6.override { withStatic = true; }}/lib -name "*.a" -exec cp {} $out/_pkg \;
                        
                    #     ${pkgs.tree}/bin/tree $out/_pkg
                    #     (cd $out/_pkg; ${pkgs.zip}/bin/zip -r -9 $out/pkg.zip *)
                    #     rm -fR $out/_pkg

                    #     mkdir -p $out/nix-support
                    #     echo "file binary-dist \"$(echo $out/*.zip)\"" \
                    #        > $out/nix-support/hydra-build-products
                    #   '';
                    # };
                };
                "aarch64-darwin" = {
                    # "lib:ffi:static" = pkgs.libffi.overrideAttrs (old: { dontDisableStatic = true; });
                    # "lib:gmp:static" = pkgs.gmp6.override { withStatic = true; };
                    "lib:mobile-core:smallAddressSpace:static" = (drv pkgs).mobile-core.components.library.override {
                      smallAddressSpace = true; enableShared = false;
                      ghcOptions = [ "-staticlib" ];
                      postInstall = ''
                        ${pkgs.tree}/bin/tree $out
                        mkdir -p $out/_pkg
                        # copy over includes, we might want those, but maybe not.
                        cp -r $out/lib/*/*/include $out/_pkg/
                        # find the libHS...ghc-X.Y.Z.a static library; this is the
                        # rolled up one with all dependencies included.
                        find ./dist -name "libHS*-ghc*.a" -exec cp {} $out/_pkg \;

                        find ${pkgs.libffi.overrideAttrs (old: { dontDisableStatic = true; })}/lib -name "*.a" -exec cp {} $out/_pkg \;
                        find ${pkgs.gmp6.override { withStatic = true; }}/lib -name "*.a" -exec cp {} $out/_pkg \;
                        # There is no static libc 

                        ${pkgs.tree}/bin/tree $out/_pkg
                        (cd $out/_pkg; ${pkgs.zip}/bin/zip -r -9 $out/pkg.zip *)
                        rm -fR $out/_pkg

                        mkdir -p $out/nix-support
                        echo "file binary-dist \"$(echo $out/*.zip)\"" \
                           > $out/nix-support/hydra-build-products
                      '';
                    };
                };
            }.${system} or {});
        # build all packages in hydra.
        hydraJobs = packages;
      }
    );
}
