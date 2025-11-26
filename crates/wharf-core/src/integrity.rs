// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2025 Jonathan D. A. Jewell <hyperpolymath>

//! # File Integrity Module
//!
//! BLAKE3-based file integrity verification for the Wharf/Yacht architecture.
//! Generates and verifies file manifests to detect unauthorized changes.

use blake3::Hasher;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::{self, File};
use std::io::{BufReader, Read};
use std::path::{Path, PathBuf};
use std::time::SystemTime;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum IntegrityError {
    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),

    #[error("Hash mismatch for {path}: expected {expected}, got {actual}")]
    HashMismatch {
        path: String,
        expected: String,
        actual: String,
    },

    #[error("File missing: {0}")]
    FileMissing(String),

    #[error("Unexpected file: {0}")]
    UnexpectedFile(String),

    #[error("Manifest parse error: {0}")]
    ParseError(String),
}

/// A single file entry in the manifest
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileEntry {
    /// Relative path from manifest root
    pub path: String,
    /// BLAKE3 hash (hex encoded)
    pub hash: String,
    /// File size in bytes
    pub size: u64,
    /// Last modified timestamp (Unix epoch)
    pub modified: u64,
    /// File permissions (Unix mode)
    pub mode: u32,
}

/// A complete integrity manifest for a directory tree
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Manifest {
    /// Version of the manifest format
    pub version: u32,
    /// Root directory this manifest covers
    pub root: String,
    /// When this manifest was generated (Unix epoch)
    pub generated: u64,
    /// All file entries
    pub files: HashMap<String, FileEntry>,
    /// Directories (for structure verification)
    pub directories: Vec<String>,
    /// Exclusion patterns used when generating
    pub excludes: Vec<String>,
}

impl Default for Manifest {
    fn default() -> Self {
        Self {
            version: 1,
            root: String::new(),
            generated: SystemTime::now()
                .duration_since(SystemTime::UNIX_EPOCH)
                .map(|d| d.as_secs())
                .unwrap_or(0),
            files: HashMap::new(),
            directories: Vec::new(),
            excludes: Vec::new(),
        }
    }
}

/// Generate a BLAKE3 hash for a file
pub fn hash_file(path: &Path) -> Result<String, IntegrityError> {
    let file = File::open(path)?;
    let mut reader = BufReader::new(file);
    let mut hasher = Hasher::new();

    let mut buffer = [0u8; 65536]; // 64KB buffer
    loop {
        let bytes_read = reader.read(&mut buffer)?;
        if bytes_read == 0 {
            break;
        }
        hasher.update(&buffer[..bytes_read]);
    }

    Ok(hasher.finalize().to_hex().to_string())
}

/// Generate a manifest for a directory tree
pub fn generate_manifest(
    root: &Path,
    excludes: &[String],
) -> Result<Manifest, IntegrityError> {
    let mut manifest = Manifest {
        root: root.to_string_lossy().to_string(),
        excludes: excludes.to_vec(),
        ..Default::default()
    };

    walk_directory(root, root, excludes, &mut manifest)?;

    Ok(manifest)
}

fn walk_directory(
    root: &Path,
    current: &Path,
    excludes: &[String],
    manifest: &mut Manifest,
) -> Result<(), IntegrityError> {
    for entry in fs::read_dir(current)? {
        let entry = entry?;
        let path = entry.path();
        let relative = path.strip_prefix(root).unwrap_or(&path);
        let relative_str = relative.to_string_lossy().to_string();

        // Check exclusions
        if should_exclude(&relative_str, excludes) {
            continue;
        }

        let metadata = entry.metadata()?;

        if metadata.is_dir() {
            manifest.directories.push(relative_str.clone());
            walk_directory(root, &path, excludes, manifest)?;
        } else if metadata.is_file() {
            let hash = hash_file(&path)?;
            let modified = metadata
                .modified()
                .ok()
                .and_then(|t| t.duration_since(SystemTime::UNIX_EPOCH).ok())
                .map(|d| d.as_secs())
                .unwrap_or(0);

            #[cfg(unix)]
            let mode = {
                use std::os::unix::fs::PermissionsExt;
                metadata.permissions().mode()
            };
            #[cfg(not(unix))]
            let mode = 0o644;

            let file_entry = FileEntry {
                path: relative_str.clone(),
                hash,
                size: metadata.len(),
                modified,
                mode,
            };

            manifest.files.insert(relative_str, file_entry);
        }
    }

    Ok(())
}

fn should_exclude(path: &str, excludes: &[String]) -> bool {
    for pattern in excludes {
        if pattern.starts_with('*') {
            // Suffix match (e.g., "*.log")
            let suffix = &pattern[1..];
            if path.ends_with(suffix) {
                return true;
            }
        } else if pattern.ends_with('*') {
            // Prefix match (e.g., "test_*")
            let prefix = &pattern[..pattern.len() - 1];
            if path.starts_with(prefix) {
                return true;
            }
        } else if path == pattern || path.contains(&format!("/{}/", pattern)) || path.starts_with(&format!("{}/", pattern)) {
            // Exact match or directory component match
            return true;
        }
    }
    false
}

/// Verification result
#[derive(Debug)]
pub struct VerifyResult {
    /// Files that passed verification
    pub passed: Vec<String>,
    /// Files with hash mismatches
    pub mismatched: Vec<(String, String, String)>, // (path, expected, actual)
    /// Files in manifest but missing on disk
    pub missing: Vec<String>,
    /// Files on disk but not in manifest
    pub unexpected: Vec<String>,
}

impl VerifyResult {
    pub fn is_ok(&self) -> bool {
        self.mismatched.is_empty() && self.missing.is_empty() && self.unexpected.is_empty()
    }
}

/// Verify a directory tree against a manifest
pub fn verify_manifest(
    root: &Path,
    manifest: &Manifest,
    allow_unexpected: bool,
) -> Result<VerifyResult, IntegrityError> {
    let mut result = VerifyResult {
        passed: Vec::new(),
        mismatched: Vec::new(),
        missing: Vec::new(),
        unexpected: Vec::new(),
    };

    // Check all files in manifest
    for (path, entry) in &manifest.files {
        let full_path = root.join(path);

        if !full_path.exists() {
            result.missing.push(path.clone());
            continue;
        }

        let actual_hash = hash_file(&full_path)?;

        if actual_hash == entry.hash {
            result.passed.push(path.clone());
        } else {
            result.mismatched.push((path.clone(), entry.hash.clone(), actual_hash));
        }
    }

    // Check for unexpected files (if not allowed)
    if !allow_unexpected {
        let current_files = collect_files(root, &manifest.excludes)?;
        for file in current_files {
            if !manifest.files.contains_key(&file) {
                result.unexpected.push(file);
            }
        }
    }

    Ok(result)
}

fn collect_files(root: &Path, excludes: &[String]) -> Result<Vec<String>, IntegrityError> {
    let mut files = Vec::new();
    collect_files_recursive(root, root, excludes, &mut files)?;
    Ok(files)
}

fn collect_files_recursive(
    root: &Path,
    current: &Path,
    excludes: &[String],
    files: &mut Vec<String>,
) -> Result<(), IntegrityError> {
    for entry in fs::read_dir(current)? {
        let entry = entry?;
        let path = entry.path();
        let relative = path.strip_prefix(root).unwrap_or(&path);
        let relative_str = relative.to_string_lossy().to_string();

        if should_exclude(&relative_str, excludes) {
            continue;
        }

        let metadata = entry.metadata()?;
        if metadata.is_dir() {
            collect_files_recursive(root, &path, excludes, files)?;
        } else if metadata.is_file() {
            files.push(relative_str);
        }
    }
    Ok(())
}

/// Save manifest to a JSON file
pub fn save_manifest(manifest: &Manifest, path: &Path) -> Result<(), IntegrityError> {
    let json = serde_json::to_string_pretty(manifest)
        .map_err(|e| IntegrityError::ParseError(e.to_string()))?;
    fs::write(path, json)?;
    Ok(())
}

/// Load manifest from a JSON file
pub fn load_manifest(path: &Path) -> Result<Manifest, IntegrityError> {
    let json = fs::read_to_string(path)?;
    serde_json::from_str(&json).map_err(|e| IntegrityError::ParseError(e.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use tempfile::tempdir;

    #[test]
    fn test_hash_file() {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("test.txt");
        fs::write(&file_path, "Hello, World!").unwrap();

        let hash = hash_file(&file_path).unwrap();
        assert!(!hash.is_empty());
        assert_eq!(hash.len(), 64); // BLAKE3 produces 256-bit (64 hex chars) hash
    }

    #[test]
    fn test_generate_and_verify_manifest() {
        let dir = tempdir().unwrap();

        // Create test files
        fs::write(dir.path().join("file1.txt"), "content1").unwrap();
        fs::create_dir(dir.path().join("subdir")).unwrap();
        fs::write(dir.path().join("subdir/file2.txt"), "content2").unwrap();

        // Generate manifest
        let manifest = generate_manifest(dir.path(), &[]).unwrap();
        assert_eq!(manifest.files.len(), 2);
        assert_eq!(manifest.directories.len(), 1);

        // Verify (should pass)
        let result = verify_manifest(dir.path(), &manifest, false).unwrap();
        assert!(result.is_ok());
        assert_eq!(result.passed.len(), 2);

        // Modify a file
        fs::write(dir.path().join("file1.txt"), "modified").unwrap();

        // Verify (should fail)
        let result = verify_manifest(dir.path(), &manifest, false).unwrap();
        assert!(!result.is_ok());
        assert_eq!(result.mismatched.len(), 1);
    }

    #[test]
    fn test_exclusions() {
        assert!(should_exclude("test.log", &["*.log".to_string()]));
        assert!(should_exclude(".git/config", &[".git".to_string()]));
        assert!(!should_exclude("file.txt", &["*.log".to_string()]));
    }
}
