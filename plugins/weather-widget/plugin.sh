#!/bin/bash

plugin_init() {
  WaybarComponent::add_module "weather"
  register_hook "before_waybar_start" "weather_fetch_data"
}

weather_fetch_data() {
  echo "Weather data fetched"
}