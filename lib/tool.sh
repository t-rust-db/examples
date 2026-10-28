# shellcheck shell=bash
# Finds a t-rust-db tool binary for an example's run.sh, newest first.
#
#   . "$ROOT/../lib/tool.sh"
#   BIN="$(find_tool column-rs column-rs COLUMN_RS 0.32.0)"
#
# find_tool <bin> <package> <env-var> [min-version] resolves, in order:
#   1. $<env-var>                     -- an explicit path, used as given
#   2. ../../tools/target/release/<bin>, built first with
#      `cargo build --release -p <package> --bin <bin>` when the
#      t-rust-db/tools checkout sits next to this examples repo (cargo only
#      rebuilds what changed, so a fresh build costs seconds)
#   3. <bin> on $PATH                 -- an installed build
# It prints the binary's version to stderr, fails when it is older than
# [min-version], and prints the binary's path to stdout.

# Whether version $1 is lower than version $2 (dotted numbers).
version_lt() {
    local -a a b
    local i
    IFS=. read -ra a <<<"$1"
    IFS=. read -ra b <<<"$2"
    for i in 0 1 2; do
        if [ "${a[i]:-0}" -lt "${b[i]:-0}" ]; then return 0; fi
        if [ "${a[i]:-0}" -gt "${b[i]:-0}" ]; then return 1; fi
    done
    return 1
}

find_tool() {
    local bin="$1" package="$2" env="$3" min="${4:-}"
    local tools path version
    tools="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tools"
    if [ -n "${!env:-}" ]; then
        path="${!env}"
    elif [ -f "$tools/Cargo.toml" ] && command -v cargo >/dev/null 2>&1; then
        echo "building $bin in $tools ($(git -C "$tools" branch --show-current 2>/dev/null || echo '?'))..." >&2
        (cd "$tools" && cargo build --release -q -p "$package" --bin "$bin") >&2 || {
            echo "error: building $bin in $tools failed" >&2
            return 1
        }
        path="$tools/target/release/$bin"
    elif command -v "$bin" >/dev/null 2>&1; then
        path="$(command -v "$bin")"
    else
        echo "error: no $bin binary: set \$$env, check out t-rust-db/tools next to this" >&2
        echo "  examples repo (it is then built), or put $bin on \$PATH" >&2
        return 1
    fi
    if [ ! -x "$path" ]; then
        echo "error: no $bin binary at '$path'" >&2
        return 1
    fi
    version="$("$path" --version 2>/dev/null | awk '{print $NF}')"
    echo "using $bin ${version:-(unknown version)} ($path)" >&2
    if [ -n "$min" ] && [ -n "$version" ] && version_lt "$version" "$min"; then
        echo "error: $bin $version is older than $min, which this example needs" >&2
        return 1
    fi
    printf '%s\n' "$path"
}
