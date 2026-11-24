{
  description = "Ferramentas locais para os grafos Graphify do NSS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      workspaceRoot = "/home/dock/dev/NSS";
    in
    {
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [ pkgs.coreutils pkgs.git pkgs.jq pkgs.uv ];
            shellHook = ''
              export NSS_GRAPHIFY_ROOT="${workspaceRoot}"
              echo "NSS Graphify shell ativo"
            '';
          };
        });

      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          nssGraphify = pkgs.writeShellApplication {
            name = "nss-graphify";
            runtimeInputs = [ pkgs.bash pkgs.coreutils pkgs.git pkgs.jq pkgs.uv ];
            text = ''
              exec ${workspaceRoot}/nss-deployment/scripts/graphify-nss.sh "$@"
            '';
          };
        in
        {
          default = nssGraphify;
          inherit nssGraphify;
        });

      apps = forAllSystems (system: {
        nss-graphify = {
          type = "app";
          program = "${self.packages.${system}.nssGraphify}/bin/nss-graphify";
        };
        default = self.apps.${system}.nss-graphify;
      });
    };
}
