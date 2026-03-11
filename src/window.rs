use std::process::Command;

#[derive(Clone)]
pub struct Window {
    pub id: String,
    pub title: String,
    pub app_id: String,
    pub workspace: String,
}

pub fn get_windows() -> Vec<Window> {
    let output = Command::new("niri")
        .args(&["msg", "windows"])
        .output()
        .expect("Failed to get windows");

    let text = String::from_utf8_lossy(&output.stdout);
    let mut windows = Vec::new();
    let mut id = String::new();
    let mut title = String::new();
    let mut app = String::new();
    let mut ws = String::new();

    for line in text.lines() {
        if line.starts_with("Window ID") {
            if !id.is_empty() {
                windows.push(Window {
                    id: id.clone(),
                    title: title.clone(),
                    app_id: app.clone(),
                    workspace: ws.clone(),
                });
            }
            id = line
                .split_whitespace()
                .nth(2)
                .unwrap_or("")
                .trim_end_matches(':')
                .to_string();
        } else if line.contains("Title:") {
            title = line.split('"').nth(1).unwrap_or("").to_string();
        } else if line.contains("App ID:") {
            app = line.split('"').nth(1).unwrap_or("").to_string();
        } else if line.contains("Workspace ID:") {
            ws = line.split_whitespace().last().unwrap_or("").to_string();
        }
    }
    if !id.is_empty() {
        windows.push(Window {
            id,
            title,
            app_id: app,
            workspace: ws,
        });
    }
    windows
}

pub fn focus_window(id: &str) {
    Command::new("niri")
        .args(&["msg", "action", "focus-window", "--id", id])
        .spawn()
        .ok();
    std::process::exit(0);
}
