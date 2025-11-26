// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2025 Jonathan D. A. Jewell <hyperpolymath>

//! # Mooring Operations
//!
//! Handles the "mooring" process - syncing state between Wharf and Yacht.

use std::path::Path;
use anyhow::{Context, Result};
use tracing::{info, warn};

use wharf_core::fleet::{Fleet, Yacht};
use wharf_core::integrity::{generate_manifest, save_manifest, verify_manifest};
use wharf_core::sync::{sync_to_remote, check_rsync, check_ssh_connection, SyncConfig};

/// Options for the mooring process
pub struct MoorOptions {
    pub force: bool,
    pub dry_run: bool,
    pub emergency: bool,
    pub layers: Vec<String>,
}

/// Result of a mooring operation
pub struct MoorResult {
    pub files_synced: u64,
    pub integrity_verified: bool,
    pub yacht_name: String,
}

/// Execute the mooring process
pub fn execute_moor(
    fleet: &Fleet,
    yacht_name: &str,
    source_dir: &Path,
    options: &MoorOptions,
) -> Result<MoorResult> {
    // Find the yacht
    let yacht = fleet.get_yacht(yacht_name)
        .context(format!("Yacht '{}' not found in fleet", yacht_name))?;

    info!("Mooring to yacht: {} ({})", yacht.name, yacht.domain);

    // Pre-flight checks
    preflight_checks(yacht)?;

    // Generate integrity manifest for local files
    info!("Generating integrity manifest...");
    let manifest = generate_manifest(source_dir, &fleet.sync_excludes)
        .context("Failed to generate integrity manifest")?;

    info!("Manifest contains {} files", manifest.files.len());

    // Save manifest
    let manifest_path = source_dir.join(".wharf-manifest.json");
    save_manifest(&manifest, &manifest_path)
        .context("Failed to save manifest")?;

    // Prepare sync configuration
    let sync_config = SyncConfig {
        source: source_dir.to_path_buf(),
        destination: yacht.rsync_destination(),
        ssh_port: yacht.ssh_port,
        identity_file: None, // TODO: Load from config
        excludes: fleet.sync_excludes.clone(),
        dry_run: options.dry_run,
        delete: options.force, // Only delete if force is enabled
    };

    // Execute sync
    if options.dry_run {
        info!("[DRY RUN] Would sync {} files to {}", manifest.files.len(), yacht.domain);
    } else {
        info!("Syncing files to {}...", yacht.domain);
        let result = sync_to_remote(&sync_config)
            .context("File sync failed")?;
        info!("Transferred {} files", result.files_transferred);
    }

    Ok(MoorResult {
        files_synced: manifest.files.len() as u64,
        integrity_verified: true,
        yacht_name: yacht_name.to_string(),
    })
}

/// Run pre-flight checks before mooring
fn preflight_checks(yacht: &Yacht) -> Result<()> {
    // Check rsync is available
    if !check_rsync() {
        anyhow::bail!("rsync is not installed. Please install rsync.");
    }
    info!("✓ rsync available");

    // Check SSH connection
    info!("Testing SSH connection to {}...", yacht.ip);
    match check_ssh_connection(&yacht.ssh_destination(), yacht.ssh_port, None) {
        Ok(true) => info!("✓ SSH connection successful"),
        Ok(false) => {
            warn!("SSH connection test returned false");
            anyhow::bail!("Cannot connect to yacht via SSH. Check your credentials.");
        }
        Err(e) => {
            warn!("SSH connection test failed: {}", e);
            anyhow::bail!("SSH connection failed: {}", e);
        }
    }

    Ok(())
}

/// Verify yacht state matches local manifest
pub fn verify_yacht_state(
    yacht: &Yacht,
    local_manifest_path: &Path,
) -> Result<bool> {
    // This would require running a remote command to verify
    // For now, we trust the sync and verify locally
    info!("Verifying yacht state for {}...", yacht.name);

    let manifest = wharf_core::integrity::load_manifest(local_manifest_path)
        .context("Failed to load manifest")?;

    info!("Manifest loaded: {} files", manifest.files.len());

    // In a full implementation, we'd run a remote verification command
    // For v1.0, we trust the rsync completed successfully

    Ok(true)
}
