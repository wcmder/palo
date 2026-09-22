# Management GRE hub and spokes

The spoke stack layers `spoke-network` above `common-network`. The hub stack
layers `hub-network` above `common-network`. The common template still owns
WAN and management LAN interfaces, and the data virtual router.

The `spoke_template` and `hub_template` modules own their tunnel interfaces,
ping profiles, address variables, GRE endpoints, memberships.
Within each role module, `main.tf` creates template-scoped interfaces and
variables, plus endpoints, router/zone memberships at
**template-stack scope**. Panorama permits stack
configuration to reference inherited objects; one template cannot reference
objects in another template. See the [template-stack guide][stacks].

Each stack's management router and zone include the inherited management LAN
interface and its tunnel interfaces. The data router retains the WAN interface
and default route used to reach GRE peers. WAN routing between the three
endpoint addresses must already work.

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

All GRE local addresses reference the common interface's `$wan_ip` variable,
including its per-device address/prefix override. The source is an interface
address reference, not a bare peer address. Each spoke must set its own
`tunnel_ip`; PA-C must set both hub tunnel interface addresses. Hub defaults
may be configured in tfvars because that template serves one hub.

The older spoke `gre_local_ip` variable and overrides are retained for
compatibility with existing configuration, but GRE no longer references them.
They do not determine the source address.

Spoke and hub templates do not install static management routes. BGP will be
added later; remote management networks are not routed through GRE yet. The
common template's data-router default route remains for WAN reachability.
The common policy permits GRE between the configured WAN endpoints and allows
management TCP/22 between `site-all-mgmt` addresses. Existing ICMP policy remains.
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

Root `locals.tf` assembles common profiles, template inputs, stack membership
and deployment targets. GRE endpoints and
WAN peer values come from each role's template inputs. Each module's
`main.tf` declares its tunnels and memberships explicitly. Root module
calls pass `network = local.networks.<role>` and the created stack name.
These locals combine common network settings with the role's values.
GRE and future network features share this input object.
