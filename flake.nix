{
  description = "nb: CLI and local web plain text note-taking, bookmarking, and archiving (custom build)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # Override with e.g. `nb.override { settings = { EDITOR = "nvim"; NB_AUTO_SYNC = false; }; }`.
      # Each setting is exported only when not already set in the environment.
      # Settings set here take precedence over the same keys in ~/.nbrc.
      nbPackage =
        {
          lib,
          stdenvNoCC,
          installShellFiles,
          makeWrapper,
          git,
          settings ? { },
        }:
        let
          toValue =
            v:
            if builtins.isBool v then
              (if v then "1" else "0")
            else if builtins.isInt v || builtins.isString v || builtins.isPath v then
              toString v
            else
              throw "nb: setting values must be strings, integers, booleans, or paths";

          settingsArgs = lib.concatStringsSep " " (
            lib.mapAttrsToList (
              name: value:
              assert lib.assertMsg (
                builtins.match "[A-Za-z_][A-Za-z0-9_]*" name != null
              ) "nb: invalid setting name '${name}'";
              "--set-default ${name} ${lib.escapeShellArg (toValue value)}"
            ) settings
          );
        in
        stdenvNoCC.mkDerivation {
          pname = "nb";
          version =
            let
              match = builtins.match ''.*_VERSION="([^"]+)".*'' (builtins.readFile ./nb);
            in
            (if match == null then "unstable" else builtins.head match)
            + "-${self.shortRev or self.dirtyShortRev or "dirty"}";

          src = self;

          nativeBuildInputs = [
            installShellFiles
            makeWrapper
          ];

          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            runHook preInstall

            # nb takes its name from `basename $0`, and wrapProgram would rename
            # the script to .nb-wrapped. Keep the script named nb in libexec and
            # put the wrapper in bin.
            install -Dm755 nb $out/libexec/nb/nb

            installShellCompletion --cmd nb \
              --bash etc/nb-completion.bash \
              --zsh etc/nb-completion.zsh \
              --fish etc/nb-completion.fish

            runHook postInstall
          '';

          # git is required; suffix so the user's own tools take precedence.
          postFixup = ''
            makeWrapper $out/libexec/nb/nb $out/bin/nb \
              --suffix PATH : ${lib.makeBinPath [ git ]} ${settingsArgs}
          '';

          meta = {
            description = "Command line note-taking, bookmarking, archiving, and knowledge base application";
            homepage = "https://github.com/zjom/nb";
            license = lib.licenses.agpl3Plus;
            mainProgram = "nb";
            platforms = lib.platforms.unix;
          };
        };
    in
    {
      packages = forAllSystems (pkgs: {
        nb = pkgs.callPackage nbPackage { };

        default = self.packages.${pkgs.stdenv.hostPlatform.system}.nb;
      });

      apps = forAllSystems (pkgs: {
        default = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.nb}/bin/nb";
        };
      });

      overlays.default = final: prev: {
        nb = self.packages.${final.stdenv.hostPlatform.system}.nb;
      };

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.bats
            pkgs.git
            pkgs.shellcheck
          ];
        };
      });
    };
}
