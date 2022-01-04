
{
  description = "Package build for mobile-core";
  inputs.nixpkgs.url = "github:angerman/nixpkgs/patch-1"; # based on 21.11
  inputs.haskellNix.url = "github:input-output-hk/haskell.nix/angerman/aarch64";
  inputs.haskellNix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { self, haskellNix, nixpkgs, flake-utils }:
    let systems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ]; in
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
      # This will package up all *.a in $out into a pkg.zip that can
      # be downloaded from hydra.
      let withHydraLibPkg = pkg: pkg.overrideAttrs (old: {
        postInstall = ''
          mkdir -p $out/_pkg
          find $out/lib -name "*.a" -exec cp {} $out/_pkg \;

          (cd $out/_pkg; ${pkgs.zip}/bin/zip -r -9 $out/pkg.zip *)
          rm -fR $out/_pkg

          mkdir -p $out/nix-support
          echo "file binary-dist \"$(echo $out/*.zip)\"" \
              > $out/nix-support/hydra-build-products
        '';
      }); in
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
        } // ({ "x86_64-linux" = let muslPkgs = pkgs.pkgsCross.musl64;
                                     androidPkgs = pkgs.pkgsCross.aarch64-android;
                                     # For some reason building libiconv with nixpgks android setup produces
                                     # LANGINFO_CODESET to be found, which is not compatible with android sdk 23;
                                     # so we'll patch up iconv to not include that.
                                     androidIconv = (androidPkgs.libiconv.override { enableStatic = true; }).overrideAttrs (old: {
                                      postConfigure = ''
                                        echo "#undef HAVE_LANGINFO_CODESET" >> libcharset/config.h
                                        echo "#undef HAVE_LANGINFO_CODESET" >> lib/config.h
                                      '';
                                     });
                                     # Similarly to icovn, for reasons beyond my current knowledge, nixpkgs andorid
                                     # toolchain makes configure believe we have MEMFD_CREATE, which we don't in
                                     # sdk 23.
                                     androidFFI = androidPkgs.libffi.overrideAttrs (old: {
                                      dontDisableStatic = true;
                                      hardeningDisable = [ "fortify" ];
                                      postConfigure = ''
                                        echo "#undef HAVE_MEMFD_CREATE" >> aarch64-unknown-linux-android/fficonfig.h
                                      '';
                                     });
                in {
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


                    "aarch64-android:lib:ffi:static" = withHydraLibPkg androidFFI;
                    # "aarch64-android:lib:gmp:static" = androidPkgs.gmp6.override { withStatic = true; };
                    "aarch64-android:lib:iconv:static" = withHydraLibPkg androidIconv;
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

                        find ${androidFFI}/lib -name "*.a" -exec cp {} $out/_pkg \;
                        find ${androidPkgs.gmp6.override { withStatic = true; }}/lib -name "*.a" -exec cp {} $out/_pkg \;
                        find ${androidIconv}/lib -name "*.a" -exec cp {} $out/_pkg \;
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
