{
  description = "Skillbox — MoonBit Native development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Pin/Bump to a known-working rev deliberately. HEAD sometimes depends on packages marked broken.
    moonbit-overlay = {
      url = "github:moonbit-community/moonbit-overlay/9a01af90b775869a76b1675a630e7fa0e3135255";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agent-skills-nix = {
      url = "github:Kyure-A/agent-skills-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    skills = {
      url = "github:toshiki-higa/skills";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.agent-skills-nix.follows = "agent-skills-nix";
    };
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      moonbit-overlay,
      agent-skills-nix,
      skills,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        agentLib = agent-skills-nix.lib.agent-skills;
        selectedSkills = [
          "lang/moonbit-agent-guide"
        ];
        selection = pkgs.lib.mapAttrs'
          (id: skill: pkgs.lib.nameValuePair (builtins.baseNameOf id) (skill // { id = builtins.baseNameOf id; }))
          (agentLib.selectSkills {
            inherit (skills) sources catalog;
            allowlist = selectedSkills;
          });
        skillsHook = agentLib.mkShellHook {
          inherit pkgs;
          bundle = agentLib.mkBundle { inherit pkgs selection; };
          targets.agents = agentLib.defaultLocalTargets.agents // { enable = true; };
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            # Generate core metadata for `moon ide doc`.
            (moonbit-overlay.packages.${system}.moonbit_latest.overrideAttrs (old: {
              buildCommand = old.buildCommand + ''
                $out/bin/moon -C $out/lib/core check --target all --warn-list -a
              '';
            }))
            # `moon prove` uses bundled Why3 and an external SMT solver.
            pkgs.z3
          ];
          shellHook = ''
            # Install selected skills into .agents/skills (project-local).
            ${skillsHook}
          '';
        };
      }
    );
}
