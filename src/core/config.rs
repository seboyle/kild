use std::path::PathBuf;
use std::collections::HashMap;
use serde::{Deserialize, Serialize};
use std::fs;

#[derive(Debug, Clone)]
pub struct Config {
    pub shards_dir: PathBuf,
    pub log_level: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ShardsConfig {
    #[serde(default)]
    pub agent: AgentConfig,
    #[serde(default)]
    pub terminal: TerminalConfig,
    #[serde(default)]
    pub agents: HashMap<String, AgentSettings>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentConfig {
    #[serde(default = "default_agent")]
    pub default: String,
    #[serde(default)]
    pub startup_command: Option<String>,
    #[serde(default)]
    pub flags: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct TerminalConfig {
    #[serde(default)]
    pub preferred: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentSettings {
    #[serde(default)]
    pub startup_command: Option<String>,
    #[serde(default)]
    pub flags: Option<String>,
}

fn default_agent() -> String {
    "claude".to_string()
}

impl Default for AgentConfig {
    fn default() -> Self {
        Self {
            default: default_agent(),
            startup_command: None,
            flags: None,
        }
    }
}

impl ShardsConfig {
    pub fn load_hierarchy() -> Result<Self, Box<dyn std::error::Error>> {
        let mut config = ShardsConfig::default();
        
        // Load user config
        if let Ok(user_config) = Self::load_user_config() {
            config = Self::merge_configs(config, user_config);
        }
        
        // Load project config
        if let Ok(project_config) = Self::load_project_config() {
            config = Self::merge_configs(config, project_config);
        }
        
        Ok(config)
    }
    
    fn load_user_config() -> Result<ShardsConfig, Box<dyn std::error::Error>> {
        let home_dir = dirs::home_dir().ok_or("Could not find home directory")?;
        let config_path = home_dir.join(".shards").join("config.toml");
        Self::load_config_file(&config_path)
    }
    
    fn load_project_config() -> Result<ShardsConfig, Box<dyn std::error::Error>> {
        let config_path = std::env::current_dir()?.join("shards").join("config.toml");
        Self::load_config_file(&config_path)
    }
    
    fn load_config_file(path: &PathBuf) -> Result<ShardsConfig, Box<dyn std::error::Error>> {
        let content = fs::read_to_string(path)?;
        let config: ShardsConfig = toml::from_str(&content)?;
        Ok(config)
    }
    
    fn merge_configs(base: ShardsConfig, override_config: ShardsConfig) -> ShardsConfig {
        ShardsConfig {
            agent: AgentConfig {
                default: if override_config.agent.default != default_agent() {
                    override_config.agent.default
                } else {
                    base.agent.default
                },
                startup_command: override_config.agent.startup_command.or(base.agent.startup_command),
                flags: override_config.agent.flags.or(base.agent.flags),
            },
            terminal: TerminalConfig {
                preferred: override_config.terminal.preferred.or(base.terminal.preferred),
            },
            agents: {
                let mut merged = base.agents;
                for (key, value) in override_config.agents {
                    merged.insert(key, value);
                }
                merged
            },
        }
    }
    
    pub fn get_agent_command(&self, agent_name: &str) -> String {
        // Check agent-specific settings first
        if let Some(agent_settings) = self.agents.get(agent_name)
            && let Some(command) = &agent_settings.startup_command {
                let mut full_command = command.clone();
                if let Some(flags) = &agent_settings.flags {
                    full_command.push(' ');
                    full_command.push_str(flags);
                }
                return full_command;
            }
        
        // Fall back to global agent config
        let base_command = self.agent.startup_command.as_deref().unwrap_or(
            match agent_name {
                "claude" => "claude",
                "kiro" => "kiro-cli chat",
                "gemini" => "gemini",
                "codex" => "codex",
                "aether" => "aether",
                _ => agent_name,
            }
        );
        
        let mut full_command = base_command.to_string();
        if let Some(flags) = &self.agent.flags {
            full_command.push(' ');
            full_command.push_str(flags);
        }
        
        full_command
    }
}

impl Default for Config {
    fn default() -> Self {
        let home_dir = dirs::home_dir().expect("Could not find home directory");

        Self {
            shards_dir: home_dir.join(".shards"),
            log_level: std::env::var("SHARDS_LOG_LEVEL").unwrap_or_else(|_| "info".to_string()),
        }
    }
}

impl Config {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn worktrees_dir(&self) -> PathBuf {
        self.shards_dir.join("worktrees")
    }

    pub fn sessions_dir(&self) -> PathBuf {
        self.shards_dir.join("sessions")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_config_default() {
        let config = Config::new();
        assert!(config.shards_dir.to_string_lossy().contains(".shards"));
        assert_eq!(config.log_level, "info");
    }

    #[test]
    fn test_config_paths() {
        let config = Config::new();
        assert!(
            config
                .worktrees_dir()
                .to_string_lossy()
                .contains("worktrees")
        );
        assert!(
            config
                .sessions_dir()
                .to_string_lossy()
                .contains("sessions")
        );
    }
}
