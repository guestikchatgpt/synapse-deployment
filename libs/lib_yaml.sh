#!/bin/bash

CONFIG_FILE=${CONFIG_FILE:-config.yaml}

yaml_get() {
    local key="$1"
    local default_value="$2"
    local file="$CONFIG_FILE"

    if [ ! -f "$file" ]; then
        if [ -n "$default_value" ]; then
            printf '%s\n' "$default_value"
            return 0
        fi
        return 1
    fi

    local value
    value=$(awk -v search="$key" -v dflt="$default_value" '
    function trim(s){gsub(/^\s+|\s+$/, "", s); return s}
    /^[ \t]*#/ {next}
    /^[ \t]*$/ {next}
    {
        sub(/#.*/, "")
        if (match($0, /^([ ]*)([^:]+):[ ]*(.*)$/, m)) {
            indent = length(m[1])/2
            name = trim(m[2])
            val = trim(m[3])
            path[indent]=name
            for(i=indent+1;i in path;i++) delete path[i]
            full=""
            for(i=0;i<=indent;i++){full=full (i?".":"") path[i]}
            if (val != "") store[full]=val
        }
    }
    END{
        if (search in store) print store[search];
        else if (dflt != "") print dflt;
    }
    ' "$file")

    if [ -n "$value" ]; then
        printf '%s\n' "$value"
    else
        return 1
    fi
}

