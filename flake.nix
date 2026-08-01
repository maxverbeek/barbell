{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs, ... }:
    let
      forAllSystems =
        function:
        nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
          system: function nixpkgs.legacyPackages.${system}
        );
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.quickshell pkgs.qt6.qtdeclarative ];
          # Qt has no platform theme on NixOS by default, so QIcon falls back to
          # hicolor and app icons come up empty. gtk3 makes it read
          # ~/.config/gtk-3.0/settings.ini, where the real theme (Papirus) lives.
          QT_QPA_PLATFORMTHEME = "gtk3";
          shellHook = ''
            echo "quickshell -p . to run"
          '';
        };
      });

      packages = forAllSystems (pkgs: {
        # `barbell` runs the bar; `barbell ipc ...` talks to it. The ipc
        # subcommand exists because quickshell addresses instances by config
        # path, and the store path changes every rebuild — nothing outside this
        # wrapper should ever need to know it.
        default = pkgs.writeShellScriptBin "barbell" ''
          export QT_QPA_PLATFORMTHEME=gtk3
          if [ "$1" = "ipc" ]; then
            shift
            exec ${pkgs.quickshell}/bin/quickshell ipc -p ${self} "$@"
          fi
          exec ${pkgs.quickshell}/bin/quickshell -p ${self}
        '';
      });
    };
}
