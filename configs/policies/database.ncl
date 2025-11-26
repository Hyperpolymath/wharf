# Database Policy Configuration
# Defines the "Virtual Sharding" rules for the database proxy.
#
# The Rust Agent parses SQL queries using an AST (Abstract Syntax Tree)
# and enforces these policies. Regex is NOT used (too fragile/bypassable).
#
# Security Model:
# - MUTABLE (Blue Zone): Content tables - allowed to write
# - IMMUTABLE (Red Zone): Config tables - blocked unless from Wharf
# - HYBRID (Grey Zone): Conditional based on column/value patterns

{
  # Default policy for unknown tables
  # "allow" = fail-open (development)
  # "audit" = log and allow (staging)
  # "deny" = fail-closed (production)
  default_policy = "audit",

  # ============================================================
  # MUTABLE TABLES (Content - The Yacht owns these)
  # Writes are always allowed. Wharf only backs them up.
  # ============================================================
  allow_write = [
    # WordPress Core Content
    "wp_comments",
    "wp_commentmeta",

    # WooCommerce Orders & Sessions
    "wp_woocommerce_orders",
    "wp_woocommerce_order_items",
    "wp_woocommerce_order_itemmeta",
    "wp_woocommerce_sessions",

    # User meta (profile updates) - careful with this one
    # "wp_usermeta",

    # Transient/cache tables (if using DB for cache)
    "wp_options",  # Handled by hybrid rules below
  ],

  # ============================================================
  # IMMUTABLE TABLES (Config - The Wharf owns these)
  # Any write is BLOCKED unless the request is signed by Wharf.
  # ============================================================
  lock_down = [
    # WordPress Core Identity
    "wp_users",           # No new admins created online!
    "wp_posts",           # Optional: Lock posts to prevent injection
    "wp_postmeta",
    "wp_terms",
    "wp_term_taxonomy",
    "wp_term_relationships",
    "wp_links",

    # Plugin/Theme Management (Critical!)
    # Writes here = potential backdoor installation
  ],

  # ============================================================
  # HYBRID RULES (The Grey Zone)
  # wp_options is the problem child - holds both config and caches
  # ============================================================
  hybrid = {
    table = "wp_options",

    rules = [
      # Allow transient caches (standard WP noise)
      {
        action = "allow",
        column = "option_name",
        matches = "^_transient_.*",
      },
      {
        action = "allow",
        column = "option_name",
        matches = "^_site_transient_.*",
      },

      # Allow WooCommerce session data
      {
        action = "allow",
        column = "option_name",
        matches = "^_wc_session_.*",
      },

      # BLOCK critical configuration options
      # These MUST only be changed via Wharf
      {
        action = "deny",
        column = "option_name",
        matches = "^(siteurl|home|blogname|admin_email)$",
      },
      {
        action = "deny",
        column = "option_name",
        matches = "^active_plugins$",
      },
      {
        action = "deny",
        column = "option_name",
        matches = "^template$",
      },
      {
        action = "deny",
        column = "option_name",
        matches = "^stylesheet$",
      },
      {
        action = "deny",
        column = "option_name",
        matches = "^users_can_register$",
      },
      {
        action = "deny",
        column = "option_name",
        matches = "^default_role$",
      },

      # Block cron manipulation (common attack vector)
      {
        action = "deny",
        column = "option_name",
        matches = "^cron$",
      },
    ],
  },

  # ============================================================
  # STRUCTURAL OPERATIONS (Always Blocked from Yacht)
  # These can only be performed via Wharf mooring
  # ============================================================
  blocked_operations = [
    "DROP",
    "ALTER",
    "TRUNCATE",
    "CREATE",
    "GRANT",
    "REVOKE",
  ],
}
