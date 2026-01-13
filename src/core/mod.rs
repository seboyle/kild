pub mod config;
pub mod errors;
pub mod events;
pub mod logging;

// Re-export commonly used types
pub use config::{ShardsConfig, AgentConfig, TerminalConfig};
pub use errors::ConfigError;
