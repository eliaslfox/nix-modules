{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption types;

  cfg = config.features.dnscrypt;

  configFile = pkgs.writeText "dnscrypt.toml" ''
    server_names = []

    fallback_resolvers = [${lib.concatMapStringsSep ", " (x: "'${x}'") cfg.fallbackResolvers}]

    ipv4_servers = true
    ipv6_servers = false

    dnscrypt_servers = true
    doh_servers = true

    require_dnssec = ${lib.boolToString cfg.requireDnssec}
    require_nolog = ${lib.boolToString cfg.requireNolog}
    require_nofilter = ${lib.boolToString cfg.requireNofilter}

    ignore_system_dns = true

    block_ipv6 = ${lib.boolToString cfg.blockIpv6}
    block_unqualified = true
    block_undelegated = true
    reject_ttl = 600

    ${lib.optionalString cfg.cache.enable ''
      cache = true
      cache_size = ${builtins.toString cfg.cache.size}
      cache_min_ttl = ${builtins.toString cfg.cache.maxTtl}
      cache_max_ttl = ${builtins.toString cfg.cache.maxTtl}
      cache_neg_min_ttl = ${builtins.toString cfg.cache.negMinTtl}
      cache_neg_max_ttl = ${builtins.toString cfg.cache.negMaxTtl}
    ''}

    ${lib.optionalString cfg.localDoh.enable ''
      [local_doh]
        listen_addresses = [${lib.concatMapStringsSep ", " (x: "'${x}'") cfg.localDoh.listenAddress}]
        path = "/dns-query"
        cert_file = "/etc/dnscrypt.pem"
        cert_key_file = "/etc/dnscrypt.pem"
    ''}

    [sources]
      [sources.'public-resolvers']
      urls = ['https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v2/public-resolvers.md', 'https://download.dnscrypt.info/resolvers-list/v2/public-resolvers.md']
      cache_file = '/tmp/public-resolvers.md'
      minisign_key = 'RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3'
      refresh_delay = 72
  '';

in
{
  options.features.dnscrypt = {
    enable = mkEnableOption "enable dnscrypt proxy";

    fallbackResolvers = mkOption {
      type = types.listOf types.str;
      default = [ "8.8.8.8:53" "8.8.4.4:53" ];
      description = "dns servers to use when bootstrapping the dns server";
    };

    requireDnssec = mkOption {
      type = types.bool;
      default = true;
      description = "require dnssec verification from resolvers";
    };

    requireNolog = mkOption {
      type = types.bool;
      default = true;
      description = "require resolvers to not log queries";
    };

    requireNofilter = mkOption {
      type = types.bool;
      default = true;
      description = "require resolvers to not filter queries";
    };

    blockIpv6 = mkOption {
      type = types.bool;
      default = false;
      description = "block ipv6 queries";
    };

    cache = mkOption {
      type = types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = false;
          };
          size = mkOption {
            type = types.int;
            default = 4096;
          };
          minTtl = mkOption {
            type = types.int;
            default = 2400;
          };
          maxTtl = mkOption {
            type = types.int;
            default = 86400;
          };
          negMinTtl = mkOption {
            type = types.int;
            default = 60;
          };
          negMaxTtl = mkOption {
            type = types.int;
            default = 600;
          };
        };
      };
      default = { };
    };

    localDoh = mkOption {
      type = types.submodule {
        options = {
          enable = mkEnableOption "enable local doh server";
          listenAddress = mkOption {
            type = types.listOf types.str;
            default = [ "127.0.0.1:3000" "[::1]:3000" ];
            description = "IP and port combinations to listen on";
          };
        };
      };
      default = { };
    };
  };

  config = mkIf cfg.enable {
    networking.nameservers = lib.mkForce [ "127.0.0.1" ];

    services.dnscrypt-proxy2 = {
      enable = true;
      configFile = configFile;
    };

    environment.etc."dnscrypt.pem".source = ../dnscrypt.pem;
  };
}
