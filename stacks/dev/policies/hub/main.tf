# Hub-specific policies assigned to child device groups.
# Reserved for future Security/NAT rules; this scaffold creates no resources.
# Call ../../../modules/panos/policy/security and/or ../../../modules/panos/policy/nat.
# Accept multiple targets through an items map when implemented.
# Wire target names from module.device_groups.names in the environment root.
# Exactly one module instance must own each device-group/policy-type/rulebase scope.
# Put the complete ordered rule list for that scope under that owner.
