# Authentication Policy Configuration
# Defines how the Wharf authenticates to the Yacht for mooring.
#
# Security Model: Zero Trust
# - The Yacht is hostile by default
# - Every command must be cryptographically signed
# - Hardware 2FA (FIDO2) is required for mooring
# - Time-limited sessions prevent replay attacks

{
  # ============================================================
  # FIDO2 / WEBAUTHN CONFIGURATION
  # ============================================================
  # Hardware key authentication (YubiKey, Nitrokey, SoloKey, etc.)

  fido2 = {
    enabled = true,

    # Requirements for authentication
    requirements = {
      # User must physically touch the key
      user_presence = true,

      # PIN or biometric verification
      # "preferred" = use if available
      # "required" = fail without it
      # "discouraged" = skip even if available
      user_verification = "preferred",
    },

    # Relying Party (your identity)
    relying_party = {
      id = "wharf.hyperpolymath.net",
      name = "Project Wharf",
    },

    # Timeout for authentication ceremony (milliseconds)
    timeout = 60000,

    # Allowed authenticator types
    # "platform" = built-in (TPM, TouchID)
    # "cross-platform" = external (USB keys)
    authenticator_attachment = "cross-platform",
  },

  # ============================================================
  # AUTHORIZED KEYS (The Captains)
  # ============================================================
  # Only these credential IDs can moor to yachts.
  # Add new keys via `wharf auth register`

  authorized_credentials = [
    # Format: Base64-encoded credential ID
    # Add your keys here after running `wharf auth register`
  ],

  # ============================================================
  # SESSION POLICY
  # ============================================================
  # Controls for the mooring session

  session = {
    # Maximum session duration (seconds)
    # After this, you must re-authenticate
    max_duration = 3600,  # 1 hour

    # Idle timeout (seconds)
    idle_timeout = 300,  # 5 minutes

    # Allow session extension via re-authentication
    allow_extension = true,
  },

  # ============================================================
  # EMERGENCY ACCESS (Break Glass)
  # ============================================================
  # If all hardware keys are lost, how to recover

  emergency_access = {
    enabled = true,

    # Method: "sharded_recovery" or "backup_codes"
    method = "sharded_recovery",

    # For sharded recovery: minimum shares needed
    threshold = 2,
    total_shares = 5,

    # Store recovery shares in separate secure locations
    # e.g., bank safe deposit box, trusted person, etc.
  },

  # ============================================================
  # PASSWORD HASHING (For encrypted volumes)
  # ============================================================
  # The Wharf container is an encrypted LUKS volume

  password_hashing = {
    algorithm = "argon2id",

    # Argon2id parameters (tuned for security)
    params = {
      # Memory cost (KB) - higher = more secure but slower
      memory = 65536,  # 64MB

      # Time cost (iterations)
      iterations = 3,

      # Parallelism (threads)
      parallelism = 4,

      # Output length (bytes)
      output_length = 32,
    },
  },
}
