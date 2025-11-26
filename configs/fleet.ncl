# Fleet Configuration
# This file defines all managed Yachts (runtime servers) in your fleet.
# The Wharf Controller uses this to know where to connect.

{
  # Fleet Metadata
  fleet_name = "hyperpolymath",
  fleet_version = "0.1.0",

  # The Yachts (Live Servers)
  yachts = {
    # Primary production site
    "primary-site" = {
      id = "yacht-001",
      ip = "192.168.100.1",
      ipv6 = "2001:db8::1",
      domain = "example.com",
      adapter = "wordpress",
      policy = "strict",

      # Nebula mesh configuration
      nebula = {
        lighthouse = false,
        groups = ["server", "production"],
      },
    },

    # Staging environment
    "staging" = {
      id = "yacht-002",
      ip = "192.168.100.2",
      ipv6 = "2001:db8::2",
      domain = "staging.example.com",
      adapter = "wordpress",
      policy = "standard",

      nebula = {
        lighthouse = false,
        groups = ["server", "staging"],
      },
    },

    # Example Drupal site
    "drupal-site" = {
      id = "yacht-003",
      ip = "192.168.100.3",
      domain = "drupal.example.com",
      adapter = "drupal",
      policy = "standard",

      nebula = {
        lighthouse = false,
        groups = ["server", "production"],
      },
    },
  },

  # Nebula Mesh Configuration
  nebula = {
    # The CA certificate (public part - private stays offline)
    ca_cert_path = "infra/nebula/ca.crt",

    # Lighthouse (directory server) - can be a cheap VPS
    lighthouse = {
      public_ip = "1.2.3.4",
      nebula_ip = "192.168.100.254",
      port = 4242,
    },
  },

  # The Captains (Authorized Administrators)
  captains = {
    "jonathan" = {
      nebula_ip = "192.168.100.10",
      groups = ["captain", "admin"],
      fido2_credential_id = "base64-encoded-credential-id",
    },
  },
}
