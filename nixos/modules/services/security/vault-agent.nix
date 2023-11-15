{ config, lib, pkgs, ... }:

with lib;

let
  format = pkgs.formats.json { };
  commonOptions = { pkgName, flavour ? pkgName }: mkOption {
    default = { };
    description = mdDoc ''
      Attribute set of ${flavour} instances.
      Creates independent `${flavour}-''${name}.service` systemd units for each instance defined here.
    '';
    type = with types; attrsOf (submodule ({ name, ... }: {
      options = {
        enable = mkEnableOption (mdDoc "this ${flavour} instance") // { default = true; };

        package = mkPackageOptionMD pkgs pkgName { };

        user = mkOption {
          type = types.str;
          default = "root";
          description = mdDoc ''
            User under which this instance runs.
          '';
        };

        group = mkOption {
          type = types.str;
          default = "root";
          description = mdDoc ''
            Group under which this instance runs.
          '';
        };

        config = mkOption {
          type = types.path;
          description = mdDoc "Path for the HCL config";
        };
      };
    }));
  };

  createAgentInstance = { instance, name, flavour }:
    mkIf (instance.enable) {
      description = "${flavour} daemon - ${name}";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = [ pkgs.getent ];
      startLimitIntervalSec = 60;
      startLimitBurst = 3;
      serviceConfig = {
        User = instance.user;
        Group = instance.group;
        RuntimeDirectory = flavour;
        ExecStart = "${getExe instance.package} ${optionalString ((getName instance.package) == "vault") "agent"} -config ${instance.config}";
        ExecReload = "${pkgs.coreutils}/bin/kill -SIGHUP $MAINPID";
        KillSignal = "SIGINT";
        TimeoutStopSec = "30s";
        Restart = "on-failure";
      };
    };
in
{
  options = {
    services.consul-template.instances = commonOptions { pkgName = "consul-template"; };
    services.vault-agent.instances = commonOptions { pkgName = "vault"; flavour = "vault-agent"; };
  };

  config = mkMerge (map
    (flavour:
      let cfg = config.services.${flavour}; in
      mkIf (cfg.instances != { }) {
        systemd.services = mapAttrs'
          (name: instance: nameValuePair "${flavour}-${name}" (createAgentInstance { inherit name instance flavour; }))
          cfg.instances;
      })
    [ "consul-template" "vault-agent" ]);

  meta.maintainers = with maintainers; [ emilylange tcheronneau ];
}

