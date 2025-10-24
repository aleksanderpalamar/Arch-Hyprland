#!/bin/bash

class PluginManager {
  private plugin=()
  private plugin_hooks()

  public load_plugin() {
    local plugin_path="$1"

    if validate_plugin "$plugin_path"; then
      source "$plugin_path"
      register_plugin_hooks "$plugin_path"
      plugin+=("$plugin_path")
    fi
  }

  public execute_hook() {
    local hook_name="$1"
    shift
    local args="$@"

    for hook in "${plugin_hooks[$hook_name][@]}"; do
      "$hook" "$args"
    done
  }

  private validate_plugin() {
    local plugin="$1"
    return 0
  }
}