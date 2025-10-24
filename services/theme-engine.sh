#!/bin/bash

class ThemeEngine {
  private current_theme=""
  private theme_components=()

  public load_theme() {
    local theme_name="$1"
    local theme_config="themes/$theme_name/theme.conf"

    if [[ -f "$theme_config"]]; then
      source "$theme_config"
      apply_theme_to_components
      current_theme="$theme_name"
    fi
  }

  private apply_theme_to_components() {
    for component in "${theme_components[@]}"; do
      "$component"::apply_theme "$current_theme"
    done
  }

  public register_component() {
    local component="$1"
    theme_components+=("$component")
  }
}