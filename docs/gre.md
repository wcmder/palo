# Management GRE hub and spokes

The spoke stack layers `spoke-network` above `common-network`; the hub stack
layers `hub-network` above `common-network`. Common is reserved for independent
shared device settings. It currently contains only the template container.

Each role's `main.tf` owns its complete network inside its own template:
WAN/LAN interfaces, subinterfaces, tunnel interfaces, variables, profiles,
routers, zones, GRE endpoints, and the data router's WAN default route.
Spoke has one GRE tunnel; hub has two. Each management router and zone includes
its management subinterface and its tunnels. Stacks only assign templates and
devices; no network resource uses template-stack scope.

All interface references resolve within the same template. Shared profile
settings are reused from root locals, with separate Panorama profile objects
in each role template. WAN routing between GRE endpoints must already work.

## Inputs and variables

`templates.spoke.var` and `templates.hub.var` in
`env/dev/templates.auto.tfvars` define their WAN endpoints and peers. Update
these when your underlay changes:

| Device | WAN endpoint | Management network |
| --- | --- | --- |
| PA-A | `10.0.1.2` | `10.1.20.0/24` |
| PA-B | `10.0.2.2` | `10.2.20.0/24` |
| PA-C | `10.0.3.2` | `10.3.20.0/24` |

Tunnel addresses are intentionally `"None"` in `templates.auto.tfvars`. No
point-to-point address range has been chosen. Assign non-overlapping tunnel
subnets before pushing. Both ends of each link must use the same subnet.

Add these values to each device's `var` object in `device_overrides.json`:

| Device | Variable | Value to supply |
| --- | --- | --- |
| PA-A | `tunnel_ip` | PA-A tunnel address/prefix |
| PA-B | `tunnel_ip` | PA-B tunnel address/prefix |
| PA-C | `spoke_a_tunnel_ip` | PA-C address/prefix on the PA-A tunnel |
| PA-C | `spoke_b_tunnel_ip` | PA-C address/prefix on the PA-B tunnel |

All GRE local addresses reference their role interface's `$wan_ip` variable,
including its per-device address/prefix override. The source is an interface
address reference, not a bare peer address. Each spoke must set its own
`tunnel_ip`; PA-C must set both hub tunnel interface addresses. Hub defaults
may be configured in tfvars because that template serves one hub.

The unused `gre_local_ip` variable has been removed. Existing deployments
should remove any remaining per-device overrides for it in Panorama. Removing
a key from the local JSON does not delete its existing Panorama override.
GRE continues to use `$wan_ip`.

Spoke and hub templates use eBGP for management routing through GRE. Only
connected routes on the management subinterface are redistributed into BGP.
The data-router default routes remain for WAN reachability.
The common policy permits GRE between the configured WAN endpoints and allows
management TCP/22 between `site-all-mgmt` addresses. Existing ICMP policy
remains.
Keep `policies.common.gre_endpoints` aligned with WAN endpoint changes.

## Deployment

Apply Terraform to create the templates, stack configuration and variables.
Then populate the tunnel overrides and run:

```sh
palo dev overrides plan
palo dev overrides apply
```

Commit Panorama and push both stacks after all required variables resolve to
valid addresses. An unresolved `None` on an interface causes firewall
validation failure. No live connectivity or commits are performed by mock
Terraform tests.

GRE uses IP protocol 47 and does not encrypt its payload. These tunnels use
IPv4 with a 1476-byte tunnel MTU and keepalives. See the [GRE setup guide][gre].

[stacks]: https://docs.paloaltonetworks.com/panorama/administration/manage-firewalls/manage-templates-and-template-stacks/configure-a-template-stack
[gre]: https://docs.paloaltonetworks.com/ngfw/networking/gre-tunnels/create-a-gre-tunnel

Root `locals.tf` assembles selected profiles, template inputs and stack
membership. Root calls pass `network = var.templates.<role>.var`; each role
receives its complete network configuration, including future network features.

## Migration from shared networking

This changes Panorama ownership, not just Terraform addresses. Existing
network resources in common must become separate resources in spoke and hub.
Existing stack-scoped GRE endpoints and management router/zone overrides must
be removed as their template-scoped replacements take ownership. Template and
stack names, firewall assignments, and variable names are preserved.

Before applying to an existing deployment:

1. Save the Terraform state and a Panorama configuration snapshot. Record the
   current per-device overrides and effective network configuration.
2. Review a Terraform plan against the actual state. Expect common networking
   to be removed, base networking to be created in both role templates, and
   stack-scoped GRE/router/zone resources to change location. Do not use state
   moves to pretend an object has changed Panorama location, or map the one
   common object to both roles. Import any role objects already created outside
   Terraform before managing them.
3. Apply the reviewed migration to the candidate configuration. If Panorama
   rejects deletion of a referenced object, stage the migration so replacement
   role resources exist and references are changed before deleting old objects.
   Do not commit or push an intermediate, partially migrated configuration.
4. Verify that both role templates are complete and old stack network overrides
   are gone. Check the effective stack configuration, including the single
   management router, full memberships, WAN default route and GRE sources.
5. Reconcile per-device overrides using `palo dev overrides plan` and
   `palo dev overrides apply`. Supply all tunnel addresses, validate Panorama,
   then commit and push both stacks.

Mock tests verify Terraform composition only. They do not verify API relocation
behavior or migrate existing Panorama objects. This refactor does not include
an automatic live migration.

## BGP over GRE

The common pre-rulebase includes `allow-bgp-management`: management zone to
management zone, any source/destination address, application `bgp`, service
`application-default`, with session-end logging. This permits tunnel peer
addresses without restricting them to the site management subnet group.

BGP is configured on the existing management router in each role template.
Spoke has one eBGP peer; hub has separate peers for spoke A and spoke B. No
additional router or stack override is created. The peer's local address uses
its tunnel interface and the same address variable as that interface; there is
no separate `local_bgp_ip` input.

All BGP inputs belong to `templates.<role>.var` in `templates.auto.tfvars`:

- Spoke: `local_bgp_asn`, `remote_bgp_asn`, `remote_bgp_peer_ip`,
  `bgp_password`, and `bgp_router_id`.
- Hub: `local_bgp_asn`, `bgp_router_id`, `spoke_a_remote_bgp_asn`,
  `spoke_a_remote_bgp_peer_ip`, `spoke_a_bgp_password`, and the corresponding
  `spoke_b_` fields. These are direct fields in `templates.hub.var`.

`bgp_router_id` is a unique bare IPv4 address, independent of the session's
local interface address. The local override file sets it to the spoke tunnel
IP on PA-A/PA-B and the first hub tunnel IP on PA-C, without prefixes.
The spoke peer overrides use the hub address on each respective tunnel.
Hub peer addresses use the existing spoke tunnel assignments.

ASNs remain `"None"` until selected. Use different local ASNs for PA-A, PA-B
and PA-C in this eBGP example so spoke-to-spoke routes are not rejected as
AS-path loops. ASNs use decimal strings, without dotted notation. Supply:

| Device | Override keys |
| --- | --- |
| PA-A / PA-B | `local_bgp_asn`, `remote_bgp_asn` |
| PA-C | `local_bgp_asn` |
| PA-C peers | `spoke_a_remote_bgp_asn`, `spoke_b_remote_bgp_asn` |

On PA-A/PA-B, the remote ASN is PA-C's local ASN. On PA-C, the two remote ASNs
are PA-A's and PA-B's respective local ASNs. Hub peer defaults may instead be
set in `templates.hub.var`.

Replace `example-bgp-password` in the Terraform inputs before deployment.
The spoke template shares one password across its devices, so both hub peer
passwords must match it. These are TCP MD5 authentication secrets, passed to
BGP authentication profiles. The installed provider marks secrets sensitive,
but Terraform state still contains them. They are not Panorama variables or
entries in `device_overrides.json`; the installed provider's template-variable
schema does not expose a secret type.

Connected management routes are advertised; connected tunnel routes and the
WAN default route are not redistributed. Learned BGP routes are installed,
default routes from peers are rejected, and the hub uses itself as next hop
when exporting routes. No static management routes are added.

Apply the Terraform candidate configuration, reconcile device overrides, and
validate before committing and pushing both stacks. All ASNs, router IDs,
peer addresses and interface addresses must resolve before the push. Mock
tests cannot verify adjacency or routing on running firewalls.

References: [PAN-OS BGP configuration][bgp] and the
[installed provider's virtual-router schema][bgp-provider].

[bgp]: https://docs.paloaltonetworks.com/ngfw/networking/bgp/configure-bgp
[bgp-provider]: https://github.com/PaloAltoNetworks/terraform-provider-panos/blob/v2.0.13/docs/resources/virtual_router.md
