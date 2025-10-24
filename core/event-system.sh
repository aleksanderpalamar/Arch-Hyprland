#!/bin/bash

# Sistema de Eventos Simples
declare -A event_listeners

register_event_handler() {
    local event_name="$1"
    local handler_function="$2"
    
    if [ -z "$event_name" ] || [ -z "$handler_function" ]; then
        return 1
    fi
    
    if [ -n "${event_listeners[$event_name]}" ]; then
        event_listeners["$event_name"]+=" $handler_function"
    else
        event_listeners["$event_name"]="$handler_function"
    fi
    
    return 0
}

emit_event() {
    local event_name="$1"
    local event_data="$2"
    
    if [ -z "$event_name" ]; then
        return 1
    fi
    
    local handlers="${event_listeners[$event_name]}"
    
    if [ -z "$handlers" ]; then
        return 0
    fi
    
    for handler in $handlers; do
        if command -v "$handler" >/dev/null 2>&1; then
            "$handler" "$event_data" 2>/dev/null || true
        fi
    done
    
    return 0
}

export -f register_event_handler emit_event
