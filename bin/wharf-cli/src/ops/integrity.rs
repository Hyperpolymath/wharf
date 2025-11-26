// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2025 Jonathan D. A. Jewell <hyperpolymath>

//! # Integrity Operations
//!
//! File integrity manifest generation and verification.

use std::path::Path;
use anyhow::{Context, Result};
use tracing::info;

use wharf_core::integrity::{self, Manifest, VerifyResult};

/// Generate an integrity manifest for a directory
pub fn generate_manifest(
    root: &Path,
    excludes: &[String],
    output: Option<&Path>,
) -> Result<Manifest> {
    info!("Generating integrity manifest for {:?}", root);

    let manifest = integrity::generate_manifest(root, excludes)
        .context("Failed to generate manifest")?;

    info!("Generated manifest with {} files, {} directories",
          manifest.files.len(), manifest.directories.len());

    // Save if output path provided
    if let Some(out) = output {
        integrity::save_manifest(&manifest, out)
            .context("Failed to save manifest")?;
        info!("Manifest saved to {:?}", out);
    }

    Ok(manifest)
}

/// Verify a directory against a manifest
pub fn verify_against_manifest(
    root: &Path,
    manifest_path: &Path,
    allow_unexpected: bool,
) -> Result<VerifyResult> {
    info!("Verifying {:?} against manifest {:?}", root, manifest_path);

    let manifest = integrity::load_manifest(manifest_path)
        .context("Failed to load manifest")?;

    let result = integrity::verify_manifest(root, &manifest, allow_unexpected)
        .context("Verification failed")?;

    // Report results
    info!("Verification complete:");
    info!("  Passed: {} files", result.passed.len());

    if !result.mismatched.is_empty() {
        info!("  MISMATCHED: {} files", result.mismatched.len());
        for (path, expected, actual) in &result.mismatched {
            info!("    {} - expected: {}..., got: {}...",
                  path, &expected[..8], &actual[..8]);
        }
    }

    if !result.missing.is_empty() {
        info!("  MISSING: {} files", result.missing.len());
        for path in &result.missing {
            info!("    {}", path);
        }
    }

    if !result.unexpected.is_empty() {
        info!("  UNEXPECTED: {} files", result.unexpected.len());
        for path in &result.unexpected {
            info!("    {}", path);
        }
    }

    Ok(result)
}

/// Quick hash of a single file
pub fn hash_file(path: &Path) -> Result<String> {
    integrity::hash_file(path)
        .context(format!("Failed to hash file {:?}", path))
}
