{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption types;
  inherit (map) builtins;

  cfg = config.features.wireguard;

  dhcpcdConf = pkgs.writeText "dhcpcd.conf" ''
    hostname

    option classless_staic_routes, interface_mtu

    nooption domain_name_servers, domain_name, domain_search, host_name, ntp_servers

    nohook lookup-hostname

    waitip
  '';

in
{
  options.features.wireguard = {
    enable = mkEnableOption "wireguard vpn";
    wirelessInterface = mkOption {
      type = types.str;
      description =
        "The id of your wireless interface. This is the only interface that will have dhcp enabled.";
      example = "wlan0";
    };
    extraInterfaces = mkOption {
      type = types.listOf types.str;
      description = "Extra interfaces to move into the physical namespace";
      example = [ "eth0" ];
      default = [ ];
    };

    credentials = mkOption {
      type = types.submodule {
        options = {
          address = mkOption {
            type = types.str;
            description = "The ip address assigned to your client";
          };
          endpoint = mkOption {
            type = types.str;
            description = "The ip of the server";
          };
          publickey = mkOption {
            type = types.str;
            description = "The public key of the server";
          };
          privatekey = mkOption {
            type = types.str;
            description = "A string containg the path to a private key";
            example = "/root/wg/privatekey";
          };
        };
      };
    };

  };

  config = mkIf cfg.enable {
    networking.wireguard = {
      enable = true;

      interfaces."wg0" = {
        ips = [ cfg.credentials.address ];
        privateKeyFile = cfg.credentials.privatekey;
        interfaceNamespace = "init";
        socketNamespace = "physical";

        peers = [{
          allowedIPs = [ "0.0.0.0/0" ];
          endpoint = cfg.credentials.endpoint;
          publicKey = cfg.credentials.publickey;
        }];
      };
    };

    systemd.services = {
      physical-netns = {
        description = "Network namespace for physical devices";
        after = [ "sys-subsystem-net-devices-${cfg.wirelessInterface}.device" ]
          ++
          map
            (x: "sys-subsystem-net-devices-${x}.device")
            cfg.extraInterfaces;
        wantedBy = [ "multi-user.target" ];
        before = [ "network.target" ];
        wants = [ "network.target" ];
        restartIfChanged = false;
        path = [ pkgs.iproute pkgs.iw ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeScript "physical-netns-start" ''
            #!${pkgs.bash}/bin/bash
            set -eou pipefail

            ip netns add physical
            iw phy phy0 set netns name physical
            ${lib.concatMapStringsSep "\n" (x: "ip link set ${x} netns physical") cfg.extraInterfaces}

          '';
          ExecStop = pkgs.writeScript "physical-netns-stop" ''
            #!${pkgs.bash}/bin/bash
            set -euo pipefail

            ip netns exec physical iw phy phy0 set netns 1
            ${lib.concatMapStringsSep "\n" (x: "ip -n physical link set ${x} netns 1") cfg.extraInterfaces}

            ip netns delete physical
          '';
        };
      };

      wireguard-wg0 = { after = [ "physical-netns.service" ]; };

      wpa_supplicant = {
        after = lib.mkForce [ "physical-netns.service" ];
        requires = lib.mkForce [ "physical-netns.service" ];
        serviceConfig = { NetworkNamespacePath = "/var/run/netns/physical"; };
      };

      firewall = {
        after = lib.mkForce [ "physical-netns.service" ];
        requires = lib.mkForce [ "physical-netns.service" ];
        serviceConfig = { NetworkNamespacePath = "/var/run/netns/physical"; };
      };

      dhcpcd = {
        after = lib.mkForce [ "physical-netns.service" ];
        requires = lib.mkForce [ "physical-netns.service" ];
        serviceConfig = {
          NetworkNamespacePath = "/var/run/netns/physical";
          ExecStart = lib.mkForce
            "@${pkgs.dhcpcd}/sbin/dhcpcd dhcpcd --quiet --config ${dhcpcdConf} ${cfg.wirelessInterface}";
          PIDFile = lib.mkForce "/run/dhcpcd-${cfg.wirelessInterface}.pid";
        };
      };
    };
  };
}
