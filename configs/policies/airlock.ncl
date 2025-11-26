# HTTP Header Airlock Configuration
# Defines what HTTP headers are allowed through to the application.
#
# This implements a POSITIVE security model:
# - Everything is blocked by default
# - Only explicitly allowed headers pass through
# - Dangerous headers are stripped before PHP/application sees them
#
# This prevents:
# - Header injection attacks
# - HTTP desync/smuggling
# - Host header poisoning
# - Information leakage

{
  # ============================================================
  # INGRESS (Request Headers - What the client sends)
  # ============================================================
  ingress = {
    # Default action for unrecognized headers
    default_action = "drop",

    # The Clean List - Only these pass to PHP
    allow_list = [
      "Host",
      "User-Agent",
      "Accept",
      "Accept-Language",
      "Accept-Encoding",
      "Cookie",
      "Content-Type",
      "Content-Length",
      "Origin",
      "Referer",
      "Authorization",
      "X-Requested-With",  # For AJAX detection
    ],

    # Strict constraints on allowed headers
    constraints = {
      "User-Agent" = {
        max_length = 500,
        # Block known malicious patterns
        deny_patterns = [
          "\\x00",           # Null bytes
          "<script",         # XSS attempt
          "\\.\\.\\/"        # Path traversal
        ],
      },

      "Host" = {
        # Must exactly match one of these
        must_match_domains = [],  # Populated per-yacht
        max_length = 253,
      },

      "Content-Length" = {
        max_value = 104857600,  # 100MB
      },

      "Cookie" = {
        max_length = 8192,
        # Cookies are parsed and re-serialized by Rust
        # This prevents header injection via malformed cookies
        strict_parse = true,
      },
    },

    # Headers to ALWAYS drop (security critical)
    force_drop = [
      "X-Forwarded-For",     # Can be spoofed
      "X-Real-IP",           # Can be spoofed
      "X-Original-URL",      # IIS attack vector
      "X-Rewrite-URL",       # IIS attack vector
      "Proxy",               # httpoxy vulnerability
      "X-HTTP-Method-Override",  # Method spoofing
    ],
  },

  # ============================================================
  # EGRESS (Response Headers - What we send back)
  # ============================================================
  egress = {
    # Headers to ALWAYS strip (information leakage)
    strip = [
      "Server",
      "X-Powered-By",
      "X-AspNet-Version",
      "X-AspNetMvc-Version",
    ],

    # Headers to FORCE (security hardening)
    # These are injected regardless of what PHP sends
    force = {
      # Prevent clickjacking
      "X-Frame-Options" = "DENY",

      # Prevent MIME sniffing
      "X-Content-Type-Options" = "nosniff",

      # XSS Protection (legacy, but still useful)
      "X-XSS-Protection" = "1; mode=block",

      # Referrer Policy
      "Referrer-Policy" = "strict-origin-when-cross-origin",

      # Cross-Origin Isolation Suite (Spectre/Meltdown mitigation)
      "Cross-Origin-Opener-Policy" = "same-origin",
      "Cross-Origin-Embedder-Policy" = "require-corp",
      "Cross-Origin-Resource-Policy" = "same-origin",

      # Permissions Policy (Hardware/API lockdown)
      "Permissions-Policy" = "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()",

      # HSTS (HTTP Strict Transport Security)
      # Only set this if you're sure HTTPS is working!
      "Strict-Transport-Security" = "max-age=31536000; includeSubDomains; preload",
    },
  },

  # ============================================================
  # CONTENT SECURITY POLICY
  # ============================================================
  # This is complex and site-specific. Default is restrictive.
  csp = {
    enabled = true,

    # Report-only mode (for testing)
    report_only = false,

    directives = {
      "default-src" = "'self'",
      "script-src" = "'self'",
      "style-src" = "'self' 'unsafe-inline'",  # WordPress often needs this
      "img-src" = "'self' data: https:",
      "font-src" = "'self' data:",
      "connect-src" = "'self'",
      "frame-ancestors" = "'none'",
      "base-uri" = "'self'",
      "form-action" = "'self'",
      "upgrade-insecure-requests" = "",
    },

    # Where to send violation reports
    report_uri = "/.well-known/csp-report",
  },
}
