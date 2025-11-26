# Network Policy Configuration
# Defines the Nebula mesh and firewall rules for the Wharf/Yacht architecture.
#
# Key Concept: Software Defined Perimeter (SDP)
# - Admin ports are INVISIBLE to the public internet
# - Only devices with valid Nebula certificates can see them
# - Firewall rules are embedded in the certificate itself

{
  # ============================================================
  # NEBULA MESH CONFIGURATION
  # ============================================================

  nebula = {
    # Listen port for Nebula UDP traffic
    listen_port = 4242,

    # Lighthouse configuration (the directory server)
    lighthouse = {
      # Is this node a lighthouse?
      am_lighthouse = false,

      # Known lighthouses to contact
      hosts = [
        "192.168.100.254",  # Your lighthouse's Nebula IP
      ],

      # Public addresses of lighthouses (for NAT traversal)
      static_host_map = {
        "192.168.100.254" = ["1.2.3.4:4242"],  # lighthouse_public_ip:port
      },
    },

    # Punch through NAT
    punchy = {
      punch = true,
      respond = true,
    },

    # Cipher suite (chacha20-poly1305 is faster on ARM)
    cipher = "aes",

    # Certificate paths
    pki = {
      ca = "infra/nebula/ca.crt",
      cert = "infra/nebula/host.crt",
      key = "infra/nebula/host.key",
    },
  },

  # ============================================================
  # FIREWALL RULES (Per-Node)
  # ============================================================
  # These rules define what traffic each node type accepts.

  firewall = {
    # Connection tracking settings
    conntrack = {
      tcp_timeout = "12m",
      udp_timeout = "3m",
      default_timeout = "10m",
    },

    # Outbound rules (what the node can initiate)
    outbound = [
      {
        port = "any",
        proto = "any",
        host = "any",
      },
    ],

    # Inbound rules (what the node accepts)
    # These are the SDP rules - the "invisible" part
    inbound = {
      # Rules for Yacht (Server) nodes
      server = [
        # Public web traffic (via standard interface, not Nebula)
        # Nebula is only for admin traffic

        # 1. The Mooring Port (Admin/Sync API)
        # ONLY allow if the certificate has group 'captain'
        {
          port = 9000,
          proto = "tcp",
          groups = ["captain"],
          comment = "Wharf Mooring API",
        },

        # 2. SSH Access (Emergency)
        # Only for captains, and only via Nebula
        {
          port = 22,
          proto = "tcp",
          groups = ["captain"],
          comment = "Emergency SSH",
        },

        # 3. Health checks from monitoring
        {
          port = 9100,
          proto = "tcp",
          groups = ["monitoring"],
          comment = "Prometheus metrics",
        },
      ],

      # Rules for Captain (Admin) nodes
      captain = [
        # Captains can receive nothing by default
        # They only initiate connections
      ],

      # Rules for Lighthouse nodes
      lighthouse = [
        # Lighthouses accept Nebula handshakes from anyone
        # But they can't access anything else
      ],
    },
  },

  # ============================================================
  # eBPF / XDP CONFIGURATION
  # ============================================================
  # The "Force Field" - drops packets at the driver level
  # This replaces the obsolete APL DNS record

  ebpf = {
    enabled = true,

    # XDP mode: "native" (fastest), "generic" (compatible)
    mode = "native",

    # IP allowlist (in addition to Nebula)
    # These IPs can reach the public web ports
    allowed_subnets = [
      # Cloudflare IPs (if using their CDN)
      "173.245.48.0/20",
      "103.21.244.0/22",
      "103.22.200.0/22",
      "103.31.4.0/22",
      "141.101.64.0/18",
      "108.162.192.0/18",
      "190.93.240.0/20",
      "188.114.96.0/20",
      "197.234.240.0/22",
      "198.41.128.0/17",
      "162.158.0.0/15",
      "104.16.0.0/13",
      "104.24.0.0/14",
      "172.64.0.0/13",
      "131.0.72.0/22",

      # Let's Encrypt validation
      # (They don't publish IPs, so this may need adjustment)
    ],

    # Rate limiting (requests per second per IP)
    rate_limit = {
      enabled = true,
      requests_per_second = 100,
      burst = 200,
    },
  },

  # ============================================================
  # TLS CONFIGURATION
  # ============================================================
  # For the admin API (port 9000), we use mTLS

  tls = {
    # The admin API requires mutual TLS
    mutual_tls = true,

    # Minimum TLS version
    min_version = "1.3",

    # Certificate paths (signed by Nebula CA)
    cert = "infra/nebula/host.crt",
    key = "infra/nebula/host.key",
    ca = "infra/nebula/ca.crt",

    # ALPN protocols
    alpn = ["h2", "http/1.1"],
  },
}
