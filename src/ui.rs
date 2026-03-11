use gtk4::prelude::*;
use gtk4::{ApplicationWindow, Entry, ListBox, ScrolledWindow, ListBoxRow, CssProvider};
use gtk4::gdk::Display;
use gtk4_layer_shell::{Layer, LayerShell};
use std::rc::Rc;
use std::cell::RefCell;
use fuzzy_matcher::FuzzyMatcher;
use fuzzy_matcher::skim::SkimMatcherV2;

use crate::config::Config;
use crate::window::{Window, focus_window};

pub fn setup_css(css_content: &str) {
    let css = CssProvider::new();
    css.load_from_data(css_content);
    gtk4::style_context_add_provider_for_display(
        &Display::default().unwrap(),
        &css,
        gtk4::STYLE_PROVIDER_PRIORITY_APPLICATION,
    );
}

pub fn create_window(app: &gtk4::Application, config: &Config) -> ApplicationWindow {
    let window = ApplicationWindow::builder()
        .application(app)
        .title("窗口切换")
        .default_width(config.window.width)
        .default_height(config.window.height)
        .build();

    window.init_layer_shell();
    window.set_layer(Layer::Overlay);
    window.set_keyboard_mode(gtk4_layer_shell::KeyboardMode::Exclusive);
    window.auto_exclusive_zone_enable();

    window
}

pub fn build_window_list(windows: &[Window], listbox: &ListBox) {
    for (i, win) in windows.iter().enumerate() {
        let row = ListBoxRow::new();
        let hbox = gtk4::Box::new(gtk4::Orientation::Horizontal, 12);

        let num_label = gtk4::Label::new(Some(&format!("{}", i + 1)));
        num_label.set_width_chars(2);
        num_label.set_xalign(0.5);
        num_label.add_css_class("dim-label");
        hbox.append(&num_label);

        let display_title = if win.title.is_empty() {
            &win.app_id
        } else {
            &win.title
        };
        let title_label = gtk4::Label::new(Some(display_title));
        title_label.set_xalign(0.0);
        title_label.set_hexpand(true);
        title_label.set_ellipsize(gtk4::pango::EllipsizeMode::End);
        hbox.append(&title_label);

        let sep = gtk4::Label::new(Some(""));
        sep.set_opacity(0.4);
        sep.set_margin_start(8);
        sep.set_margin_end(8);
        hbox.append(&sep);

        let app_label = gtk4::Label::new(Some(&win.app_id));
        app_label.set_opacity(0.6);
        app_label.add_css_class("dim-label");
        hbox.append(&app_label);

        row.set_child(Some(&hbox));
        listbox.append(&row);
    }
}
