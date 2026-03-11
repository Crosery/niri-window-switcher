use serde::Deserialize;
use std::fs;

#[derive(Deserialize)]
pub struct Config {
    #[serde(default)]
    pub window: WindowConfig,
}

#[derive(Deserialize)]
pub struct WindowConfig {
    #[serde(default = "default_width")]
    pub width: i32,
    #[serde(default = "default_height")]
    pub height: i32,
}

impl Default for WindowConfig {
    fn default() -> Self {
        Self {
            width: default_width(),
            height: default_height(),
        }
    }
}

fn default_width() -> i32 {
    680
}

fn default_height() -> i32 {
    520
}

pub fn load_config() -> Config {
    dirs::config_dir()
        .map(|p| p.join("niri-window-switcher/config.toml"))
        .and_then(|p| fs::read_to_string(p).ok())
        .and_then(|s| toml::from_str(&s).ok())
        .unwrap_or_else(|| Config {
            window: WindowConfig::default(),
        })
}

pub fn load_css() -> String {
    dirs::config_dir()
        .map(|p| p.join("niri-window-switcher/style.css"))
        .and_then(|p| fs::read_to_string(p).ok())
        .unwrap_or_else(|| include_str!("../style.css").to_string())
}
