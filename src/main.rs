// ============================================================================
// Modules
// ============================================================================
mod config;
mod window;
mod ui;

// ============================================================================
// Imports
// ============================================================================
use gtk4::prelude::*;
use gtk4::{Application, Entry, ListBox, ScrolledWindow, ListBoxRow};
use std::rc::Rc;
use std::cell::RefCell;
use fuzzy_matcher::FuzzyMatcher;
use fuzzy_matcher::skim::SkimMatcherV2;

use config::{load_config, load_css};
use window::{get_windows, focus_window};
use ui::{setup_css, create_window, build_window_list};

// ============================================================================
// Main Entry Point
// ============================================================================
fn main() {
    let app = Application::builder()
        .application_id("com.niri.switcher")
        .flags(gtk4::gio::ApplicationFlags::default())
        .build();

    app.connect_activate(|app| {
        if let Some(window) = app.active_window() {
            window.close();
        } else {
            build_ui(app);
        }
    });

    app.run();
}

// ============================================================================
// UI Builder
// ============================================================================
fn build_ui(app: &Application) {
    // Load configuration and setup CSS
    let config = load_config();
    setup_css(&load_css());
    let window = create_window(app, &config);

    // Create main layout
    let vbox = gtk4::Box::new(gtk4::Orientation::Vertical, 16);
    vbox.set_margin_top(28);
    vbox.set_margin_bottom(28);
    vbox.set_margin_start(28);
    vbox.set_margin_end(28);

    // Search entry
    let entry = Entry::new();
    entry.set_placeholder_text(Some("搜索窗口..."));
    vbox.append(&entry);

    // Scrollable window list
    let scrolled = ScrolledWindow::new();
    scrolled.set_vexpand(true);
    let listbox = ListBox::new();
    scrolled.set_child(Some(&listbox));
    vbox.append(&scrolled);

    // Load windows and setup state
    let windows = Rc::new(get_windows());
    let window_ids = Rc::new(RefCell::new(Vec::new()));
    let visible_indices = Rc::new(RefCell::new(Vec::new()));

    for (i, win) in windows.iter().enumerate() {
        window_ids.borrow_mut().push(win.id.clone());
        visible_indices.borrow_mut().push(i);
    }

    build_window_list(&windows, &listbox);

    if let Some(first_row) = listbox.row_at_index(0) {
        listbox.select_row(Some(&first_row));
    }

    // Setup event handlers
    setup_search(&entry, &listbox, &windows, &visible_indices);
    setup_activation(&entry, &listbox, &window_ids, &visible_indices);
    setup_keyboard(&window, &listbox, &scrolled, &window_ids, &visible_indices);

    window.set_child(Some(&vbox));
    window.present();
}

// ============================================================================
// Search Handler
// ============================================================================
fn setup_search(entry: &Entry, listbox: &ListBox, windows: &Rc<Vec<window::Window>>, visible_indices: &Rc<RefCell<Vec<usize>>>) {
    let listbox = listbox.clone();
    let windows = windows.clone();
    let visible_indices = visible_indices.clone();
    let matcher = SkimMatcherV2::default();
    
    entry.connect_changed(move |entry| {
        let text = entry.text();
        visible_indices.borrow_mut().clear();
        
        while let Some(child) = listbox.first_child() {
            listbox.remove(&child);
        }

        if text.is_empty() {
            for i in 0..windows.len() {
                visible_indices.borrow_mut().push(i);
            }
            build_window_list(&windows, &listbox);
        } else {
            let mut matches: Vec<(usize, i64)> = Vec::new();
            for (i, win) in windows.iter().enumerate() {
                let title_score = matcher.fuzzy_match(&win.title, &text).unwrap_or(0);
                let app_score = matcher.fuzzy_match(&win.app_id, &text).unwrap_or(0);
                let score = title_score.max(app_score);
                if score > 0 {
                    matches.push((i, score));
                }
            }
            matches.sort_by(|a, b| b.1.cmp(&a.1));

            let filtered: Vec<window::Window> = matches.iter().map(|(i, _)| windows[*i].clone()).collect();
            for (orig_i, _) in matches.iter() {
                visible_indices.borrow_mut().push(*orig_i);
            }
            build_window_list(&filtered, &listbox);
        }

        if let Some(first_row) = listbox.row_at_index(0) {
            listbox.select_row(Some(&first_row));
        }
    });
}

// ============================================================================
// Activation Handler
// ============================================================================
fn setup_activation(entry: &Entry, listbox: &ListBox, window_ids: &Rc<RefCell<Vec<String>>>, visible_indices: &Rc<RefCell<Vec<usize>>>) {
    let window_ids = window_ids.clone();
    let visible_indices = visible_indices.clone();
    let listbox_clone = listbox.clone();
    
    listbox.connect_row_activated(move |_, row| {
        let index = row.index() as usize;
        let visible = visible_indices.borrow();
        if let Some(&real_index) = visible.get(index) {
            if let Some(id) = window_ids.borrow().get(real_index) {
                focus_window(id);
            }
        }
    });

    let listbox_clone2 = listbox_clone.clone();
    entry.connect_activate(move |_| {
        if let Some(row) = listbox_clone2.selected_row() {
            row.activate();
        }
    });
}

// ============================================================================
// Keyboard Handler
// ============================================================================
fn setup_keyboard(window: &gtk4::ApplicationWindow, listbox: &ListBox, scrolled: &ScrolledWindow, window_ids: &Rc<RefCell<Vec<String>>>, visible_indices: &Rc<RefCell<Vec<usize>>>) {
    let listbox = listbox.clone();
    let scrolled = scrolled.clone();
    let window_ids = window_ids.clone();
    let visible_indices = visible_indices.clone();
    
    let key_controller = gtk4::EventControllerKey::new();
    key_controller.connect_key_pressed(move |_, key, _, modifiers| {
        if key == gtk4::gdk::Key::Escape {
            std::process::exit(0);
        }

        // Down navigation
        if key == gtk4::gdk::Key::Down || (key == gtk4::gdk::Key::n && modifiers.contains(gtk4::gdk::ModifierType::CONTROL_MASK)) {
            if let Some(current) = listbox.selected_row() {
                let mut next = current.next_sibling();
                while let Some(row) = next {
                    if let Some(row) = row.downcast_ref::<ListBoxRow>() {
                        if row.is_visible() {
                            listbox.select_row(Some(row));
                            let adj = scrolled.vadjustment();
                            let alloc = row.allocation();
                            let row_y = alloc.y() as f64;
                            let row_h = alloc.height() as f64;
                            if row_y + row_h > adj.value() + adj.page_size() {
                                adj.set_value(row_y + row_h - adj.page_size());
                            }
                            break;
                        }
                    }
                    next = row.next_sibling();
                }
            }
            return gtk4::glib::Propagation::Stop;
        }

        // Up navigation
        if key == gtk4::gdk::Key::Up || (key == gtk4::gdk::Key::p && modifiers.contains(gtk4::gdk::ModifierType::CONTROL_MASK)) {
            if let Some(current) = listbox.selected_row() {
                let mut prev = current.prev_sibling();
                while let Some(row) = prev {
                    if let Some(row) = row.downcast_ref::<ListBoxRow>() {
                        if row.is_visible() {
                            listbox.select_row(Some(row));
                            let adj = scrolled.vadjustment();
                            let alloc = row.allocation();
                            let row_y = alloc.y() as f64;
                            if row_y < adj.value() {
                                adj.set_value(row_y);
                            }
                            break;
                        }
                    }
                    prev = row.prev_sibling();
                }
            }
            return gtk4::glib::Propagation::Stop;
        }

        // Number keys for quick select
        let num = match key {
            gtk4::gdk::Key::_1 => Some(0), gtk4::gdk::Key::_2 => Some(1),
            gtk4::gdk::Key::_3 => Some(2), gtk4::gdk::Key::_4 => Some(3),
            gtk4::gdk::Key::_5 => Some(4), gtk4::gdk::Key::_6 => Some(5),
            gtk4::gdk::Key::_7 => Some(6), gtk4::gdk::Key::_8 => Some(7),
            gtk4::gdk::Key::_9 => Some(8), _ => None,
        };

        if let Some(n) = num {
            let visible = visible_indices.borrow();
            if n < visible.len() {
                if let Some(id) = window_ids.borrow().get(visible[n]) {
                    focus_window(id);
                }
            }
        }
        
        gtk4::glib::Propagation::Proceed
    });
    
    window.add_controller(key_controller);
}
