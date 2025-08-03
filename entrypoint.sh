#!/bin/sh

#entrypoint.sh

# Function to read variables with fallback from secrets to env var to default
get_var() {
    local var_name=$1
    local default_value=$2
    local secret_path="/run/secrets/${var_name}"
    local file_path_var="${var_name}_FILE"
    local env_var_value="${!var_name}"

    # Check for secret file first
    if [ -f "$secret_path" ]; then
        cat "$secret_path"
    # Check for _FILE environment variable
    elif [ -n "${!file_path_var}" ] && [ -f "${!file_path_var}" ]; then
        cat "${!file_path_var}"
    # Check for a regular environment variable
    elif [ -n "$env_var_value" ]; then
        echo "$env_var_value"
    # Use the default value
    else
        echo "$default_value"
    fi
}

MESH_DOMAINS=$(get_var MESH_DOMAINS "")
MESH_NETWORK_RANGE=$(get_var MESH_NETWORK_RANGE "")
NODE_DOMAINS=$(get_var NODE_DOMAINS "")

# Substitute the generated configurations into the template and start coredns
sed -e "s|{{MESH_DOMAINS}}|$(echo $MESH_DOMAINS | tr ' ' ',')|" \
    -e "s|{{MESH_NETWORK_RANGE}}|$MESH_NETWORK_RANGE|" \
    -e "s|{{NODE_DOMAINS}}|$(echo $NODE_DOMAINS | tr ' ' ',')|" \
    /etc/coredns/Corefile.tmpl > /etc/coredns/Corefile && \
coredns -conf /etc/coredns/Corefile
