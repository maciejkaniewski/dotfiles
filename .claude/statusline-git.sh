#!/bin/bash
input=$(cat)

# Single jq pass — one line per field; -1/0 sentinels keep lines aligned when a field is absent
readarray -t F < <(echo "$input" | jq -r '
    (.model.display_name // "?"),
    (.workspace.current_dir // "?"),
    (.session_id // "nosession"),
    (.context_window.used_percentage | if . then (. * 10 | round / 10 | tostring) + "%" else "?" end),
    ((.context_window.used_percentage // -1) | round),
    (.cost.total_cost_usd | if . then "$" + (. * 100 | round / 100 | tostring) else "$0" end),
    ((.rate_limits.five_hour.used_percentage // -1) | round),
    ((.rate_limits.five_hour.resets_at // 0) | if type == "number" then round else 0 end),
    ((.rate_limits.seven_day.used_percentage // -1) | round)
')
MODEL=${F[0]}
DIR=${F[1]}
SESSION_ID=${F[2]}
CTX_PCT=${F[3]}
CTX_RAW=${F[4]}
COST=${F[5]}
FIVE_H=${F[6]}
FIVE_H_RESET=${F[7]}
SEVEN_D=${F[8]}

NOW=$(date +%s)
CACHE_FILE="/tmp/statusline-git-cache-$SESSION_ID"
CACHE_MAX_AGE=5  # seconds

cache_is_stale() {
    # stat -c %Y is Linux, stat -f %m is macOS (try Linux first: on GNU stat,
    # -f means filesystem mode and prints garbage to stdout despite failing)
    local mtime
    mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
    [ ! -f "$CACHE_FILE" ] || [ $((NOW - mtime)) -gt $CACHE_MAX_AGE ]
}

if cache_is_stale; then
    BRANCH="" AHEAD=0 BEHIND=0 STAGED=0 MODIFIED=0 UNTRACKED=0
    # One git call for branch, ahead/behind and all file counts
    while IFS= read -r line; do
        case "$line" in
            "# branch.head "*) BRANCH=${line#"# branch.head "} ;;
            "# branch.ab "*)
                read -r AHEAD BEHIND <<<"${line#"# branch.ab "}"
                AHEAD=${AHEAD#+} BEHIND=${BEHIND#-}
                ;;
            "1 "* | "2 "*)
                xy=${line:2:2}
                [ "${xy:0:1}" != "." ] && STAGED=$((STAGED + 1))
                [ "${xy:1:1}" != "." ] && MODIFIED=$((MODIFIED + 1))
                ;;
            "u "*) MODIFIED=$((MODIFIED + 1)) ;;
            "? "*) UNTRACKED=$((UNTRACKED + 1)) ;;
        esac
    done < <(git status --porcelain=v2 --branch 2>/dev/null)
    echo "$BRANCH|$STAGED|$MODIFIED|$UNTRACKED|$AHEAD|$BEHIND" > "$CACHE_FILE"
fi

IFS='|' read -r BRANCH STAGED MODIFIED UNTRACKED AHEAD BEHIND < "$CACHE_FILE"

# Truncate long branch names
[ ${#BRANCH} -gt 30 ] && BRANCH="${BRANCH:0:29}…"

# Colors — follow the active theme picker (~/.config/theme/current, set by
# install.sh), same role mapping as tab_bar.py and the Powerlevel10k override.
read -r _FAMILY _VARIANT < ~/.config/theme/current 2>/dev/null
case "$_FAMILY $_VARIANT" in
    "catppuccin frappe")    H_MAUVE=ca9ee6 H_BLUE=8caaee H_GREEN=a6d189 H_YELLOW=e5c890 H_PEACH=ef9f76 H_SKY=99d1db H_SEP=737994 H_RED=e78284 ;;
    "catppuccin macchiato") H_MAUVE=c6a0f6 H_BLUE=8aadf4 H_GREEN=a6da95 H_YELLOW=eed49f H_PEACH=f5a97f H_SKY=91d7e3 H_SEP=6e738d H_RED=ed8796 ;;
    "gruvbox dark")         H_MAUVE=d3869b H_BLUE=83a598 H_GREEN=b8bb26 H_YELLOW=fabd2f H_PEACH=fe8019 H_SKY=8ec07c H_SEP=928374 H_RED=fb4934 ;;
    "dracula dark")         H_MAUVE=bd93f9 H_BLUE=8be9fd H_GREEN=50fa7b H_YELLOW=f1fa8c H_PEACH=ffb86c H_SKY=8be9fd H_SEP=6272a4 H_RED=ff5555 ;;
    *)                      H_MAUVE=cba6f7 H_BLUE=89b4fa H_GREEN=a6e3a1 H_YELLOW=f9e2af H_PEACH=fab387 H_SKY=89dceb H_SEP=6c7086 H_RED=f38ba8 ;;  # catppuccin mocha (default)
esac

hex_fg() {
    printf '\e[38;2;%d;%d;%dm' "$((16#${1:0:2}))" "$((16#${1:2:2}))" "$((16#${1:4:2}))"
}

R='\e[0m'
MAUVE=$(hex_fg "$H_MAUVE")    # model
BLUE=$(hex_fg "$H_BLUE")      # directory + ahead/behind
GREEN=$(hex_fg "$H_GREEN")    # branch
YELLOW=$(hex_fg "$H_YELLOW")  # staged
PEACH=$(hex_fg "$H_PEACH")    # modified + cost
SKY=$(hex_fg "$H_SKY")        # context %
SEP=$(hex_fg "$H_SEP")        # separators
RED=$(hex_fg "$H_RED")        # usage limits (high)

S="${SEP} | ${R}"

# Usage limit segment: green < 50%, yellow < 80%, red >= 80%
usage_color() {
    if [ "$1" -ge 80 ]; then printf '%s' "$RED"
    elif [ "$1" -ge 50 ]; then printf '%s' "$YELLOW"
    else printf '%s' "$GREEN"; fi
}

# Context %: sky < 70%, yellow < 90%, red >= 90% (approaching auto-compact)
CTX_COLOR=$SKY
if [ "$CTX_RAW" -ge 90 ]; then CTX_COLOR=$RED
elif [ "$CTX_RAW" -ge 70 ]; then CTX_COLOR=$YELLOW
fi

USAGE=""
if [ "$FIVE_H" -ge 0 ]; then
    RESET_STR=""
    if [ "$FIVE_H_RESET" -gt "$NOW" ]; then
        secs=$((FIVE_H_RESET - NOW))
        if [ "$secs" -ge 3600 ]; then
            RESET_STR="${SEP} ($((secs / 3600))h$(printf '%02d' $((secs % 3600 / 60)))m)${R}"
        else
            RESET_STR="${SEP} ($((secs / 60))m)${R}"
        fi
    fi
    USAGE="${S}${SEP}5h ${R}$(usage_color "$FIVE_H")${FIVE_H}%${R}${RESET_STR}"
fi
if [ "$SEVEN_D" -ge 0 ]; then
    USAGE="${USAGE:-$S}${USAGE:+ }${SEP}7d ${R}$(usage_color "$SEVEN_D")${SEVEN_D}%${R}"
fi

UNTRACKED_SEG=""
[ "${UNTRACKED:-0}" -gt 0 ] 2>/dev/null && UNTRACKED_SEG=" ${SEP}?${UNTRACKED}${R}"

AB_SEG=""
[ "${AHEAD:-0}" -gt 0 ] 2>/dev/null && AB_SEG="↑${AHEAD}"
[ "${BEHIND:-0}" -gt 0 ] 2>/dev/null && AB_SEG="${AB_SEG}↓${BEHIND}"
[ -n "$AB_SEG" ] && AB_SEG=" ${BLUE}${AB_SEG}${R}"

if [ -n "$BRANCH" ]; then
    printf "${SEP}[${MAUVE}%s${SEP}]${R} 📁 ${BLUE}%s${R}${S}🌿 ${GREEN}%s${R}%b ${YELLOW}+%s${R} ${PEACH}~%s${R}%b${S}${CTX_COLOR}%s${R}${S}${PEACH}%s${R}%b\n" \
        "$MODEL" "${DIR##*/}" "$BRANCH" "$AB_SEG" "$STAGED" "$MODIFIED" "$UNTRACKED_SEG" "$CTX_PCT" "$COST" "$USAGE"
else
    printf "${SEP}[${MAUVE}%s${SEP}]${R} 📁 ${BLUE}%s${R}${S}${CTX_COLOR}%s${R}${S}${PEACH}%s${R}%b\n" \
        "$MODEL" "${DIR##*/}" "$CTX_PCT" "$COST" "$USAGE"
fi
