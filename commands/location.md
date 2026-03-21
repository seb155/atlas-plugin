Invoke the `atlas-location` skill with the following arguments: $ARGUMENTS

Location-aware network management. Maps WiFi networks to locations with trust
levels. Automatically adapts ATLAS security posture per network.

Subcommands:
- `/atlas location` — Show current location, network, trust level
- `/atlas location add` — Register current network (HITL: name, trust, city)
- `/atlas location list` — Show all known locations
- `/atlas location trust [trusted|standard|restricted]` — Change trust for current network

Trust levels: trusted (home), standard (office), restricted (public).
Unknown networks default to "standard" (safe).
