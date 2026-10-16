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
    in
    {
      packages = forAllSystems (pkgs: {
        nb = pkgs.stdenvNoCC.mkDerivation {
          pname = "nb";
          version =
            let
              match = builtins.match ''.*_VERSION="([^"]+)".*'' (builtins.readFile ./nb);
            in
            (if match == null then "unstable" else builtins.head match)
            + "-${self.shortRev or self.dirtyShortRev or "dirty"}";

          src = self;

          nativeBuildInputs = [
            pkgs.installShellFiles
            pkgs.makeWrapper
          ];

          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            runHook preInstall

            install -Dm755 nb $out/bin/nb

            installShellCompletion --cmd nb \
              --bash etc/nb-completion.bash \
              --zsh etc/nb-completion.zsh \
              --fish etc/nb-completion.fish

            runHook postInstall
          '';

          # git is required; suffix so the user's own tools take precedence.
          postFixup = ''
            wrapProgram $out/bin/nb \
              --suffix PATH : ${pkgs.lib.makeBinPath [ pkgs.git ]}
          '';

          meta = {
            description = "Command line note-taking, bookmarking, archiving, and knowledge base application";
            homepage = "https://github.com/zjom/nb";
            license = pkgs.lib.licenses.agpl3Plus;
            mainProgram = "nb";
            platforms = pkgs.lib.platforms.unix;
          };
        };

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
