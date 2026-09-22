locals {
  # Shared dev starting points, NOT measured production thresholds. Rates are new CPS.
  # Tune to normal/peak traffic and firewall capacity before deployment.
  zone_protection_common = {
    discard_unknown_option                   = true
    discard_malformed_option                 = true
    discard_strict_source_routing            = true
    discard_loose_source_routing             = true
    discard_tcp_syn_with_data                = true
    discard_tcp_synack_with_data             = true
    discard_overlapping_tcp_segment_mismatch = true
    discard_tcp_split_handshake              = true
    remove_tcp_timestamp                     = true
    # Keep ICMP errors/PMTUD and legitimate fragmented traffic available.
    discard_icmp_error         = false
    discard_ip_frag            = false
    suppress_icmp_needfrag     = false
    suppress_icmp_timeexceeded = false
    flood = {
      tcp_syn  = { enable = true, syn_cookies = { alarm_rate = 1000, activate_rate = 2000, maximal_rate = 4000 } }
      udp      = { enable = true, red = { alarm_rate = 1000, activate_rate = 2000, maximal_rate = 4000 } }
      icmp     = { enable = true, red = { alarm_rate = 100, activate_rate = 200, maximal_rate = 400 } }
      icmpv6   = { enable = true, red = { alarm_rate = 100, activate_rate = 200, maximal_rate = 400 } }
      other_ip = { enable = true, red = { alarm_rate = 1000, activate_rate = 2000, maximal_rate = 4000 } }
    }
    # TCP scan, host sweep, UDP scan; vendor default intervals/event thresholds.
    scan = [
      { name = "8001", interval = 2, threshold = 100, action = { block = {} } },
      { name = "8002", interval = 10, threshold = 100, action = { block = {} } },
      { name = "8003", interval = 2, threshold = 100, action = { block = {} } }
    ]
    scan_white_list = []
  }

  # Named sets selected in templates.auto.tfvars; settings are shared across templates.
  zone_protection_profiles = {
    standard = {
      wan = merge(local.zone_protection_common, {
        name             = "wan-protection"
        description      = "Dev WAN ingress protection; tune flood thresholds to traffic baseline"
        discard_ip_spoof = false
      })
      lan = merge(local.zone_protection_common, {
        name             = "lan-protection"
        description      = "Dev LAN ingress protection; tune flood thresholds to traffic baseline"
        discard_ip_spoof = true
      })
    }
  }

  # Shared interface management settings selected by each template input.
  interface_management_profiles = {
    ping_only = {
      wan  = { name = "wan-ping", ping = true }
      lan  = { name = "lan-ping", ping = true }
      mgmt = { name = "mgmt-ping", ping = true }
    }
  }

  # tfvars files cannot reference locals directly, so resolve the set here.
  templates = {
    common = merge(var.templates.common, {
      zone_protection_profiles = local.zone_protection_profiles[
        var.templates.common.zone_protection_profile_set
      ]
      interface_management_profiles = local.interface_management_profiles[
        var.templates.common.interface_management_profile_set
      ]
    })
  }

  # Translate root template keys to names of templates created once above.
  template_names = {
    common = module.common_template.names.templates["template"]
  }
  template_stacks = {
    for key, item in var.template_stacks : key => merge(item, {
      templates = [for key in item.templates : local.template_names[key]]
    })
  }
}
