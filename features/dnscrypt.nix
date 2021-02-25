{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption;
  cfg = config.features.dnscrypt;
in
{
  options.features.dnscrypt = {
    enable = mkEnableOption "enable dnscrypt proxy";
  };

  config = mkIf cfg.enable {
    networking.nameservers = lib.mkForce [ "::1" "127.0.0.1" ];

    services.dnscrypt-proxy2 = {
      enable = true;
      settings = {
        local_doh = {
          listen_addresses = [ "127.0.0.1:3000" "[::1]:3000" ];
          path = "/dns-query";
          cert_file = "/etc/dnscrypt.pem";
          cert_key_file = "/etc/dnscrypt.pem";
        };
      };
    };

    environment.etc."dnscrypt.pem".source = ../dnscrypt.pem;
  };
}
