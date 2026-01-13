use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct IncludeConfig {
    #[serde(default)]
    pub patterns: Vec<String>,
    #[serde(default = "default_enabled")]
    pub enabled: bool,
    #[serde(default)]
    pub max_file_size: Option<String>,
}

#[derive(Debug, Clone)]
pub struct PatternRule {
    pub pattern: String,
    pub compiled: glob::Pattern,
}

#[derive(Debug, Clone)]
pub struct CopyOptions {
    pub source_root: PathBuf,
    pub destination_root: PathBuf,
    pub max_file_size: Option<u64>,
}

fn default_enabled() -> bool {
    true
}
