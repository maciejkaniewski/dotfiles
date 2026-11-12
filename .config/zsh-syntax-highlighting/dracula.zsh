# Dracula Theme (for zsh-syntax-highlighting)
#
# Paste this files contents inside your ~/.zshrc before you activate zsh-syntax-highlighting
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main cursor)
typeset -gA ZSH_HIGHLIGHT_STYLES

# Main highlighter styling: https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters/main.md
#
## General
### Diffs
### Markup
## Classes
## Comments
ZSH_HIGHLIGHT_STYLES[comment]='fg=#6272a4'
## Constants
## Entitites
## Functions/methods
ZSH_HIGHLIGHT_STYLES[alias]='fg=#50fa7b'
ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=#50fa7b'
ZSH_HIGHLIGHT_STYLES[global-alias]='fg=#50fa7b'
ZSH_HIGHLIGHT_STYLES[function]='fg=#50fa7b'
ZSH_HIGHLIGHT_STYLES[command]='fg=#50fa7b'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#50fa7b,italic'
ZSH_HIGHLIGHT_STYLES[autodirectory]='fg=#ffb86c,italic'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#ffb86c'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#ffb86c'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]='fg=#bd93f9'
## Keywords
## Built ins
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#8be9fd'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#8be9fd'
ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=#8be9fd'
## Punctuation
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#ff79c6'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]='fg=#f8f8f2'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-unquoted]='fg=#f8f8f2'
ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]='fg=#f8f8f2'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]='fg=#ff79c6'
ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=#ff79c6'
ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]='fg=#ff79c6'
## Serializable / Configuration Languages
## Storage
## Strings
ZSH_HIGHLIGHT_STYLES[command-substitution-quoted]='fg=#f1fa8c'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-quoted]='fg=#f1fa8c'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#f1fa8c'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument-unclosed]='fg=#ff5555'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#f1fa8c'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument-unclosed]='fg=#ff5555'
ZSH_HIGHLIGHT_STYLES[rc-quote]='fg=#f1fa8c'
## Variables
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#f8f8f2'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument-unclosed]='fg=#ff5555'
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=#f8f8f2'
ZSH_HIGHLIGHT_STYLES[assign]='fg=#f8f8f2'
ZSH_HIGHLIGHT_STYLES[named-fd]='fg=#f8f8f2'
ZSH_HIGHLIGHT_STYLES[numeric-fd]='fg=#f8f8f2'
## No category relevant in spec
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#ff5555'
ZSH_HIGHLIGHT_STYLES[path]='fg=#f8f8f2,underline'
ZSH_HIGHLIGHT_STYLES[path_pathseparator]='fg=#ff79c6,underline'
ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=#f8f8f2,underline'
ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]='fg=#ff79c6,underline'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=#f8f8f2'
ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=#bd93f9'
#ZSH_HIGHLIGHT_STYLES[command-substitution]='fg=?'
#ZSH_HIGHLIGHT_STYLES[command-substitution-unquoted]='fg=?'
#ZSH_HIGHLIGHT_STYLES[process-substitution]='fg=?'
#ZSH_HIGHLIGHT_STYLES[arithmetic-expansion]='fg=?'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-unclosed]='fg=#ff5555'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#f8f8f2'
ZSH_HIGHLIGHT_STYLES[arg0]='fg=#f8f8f2'
ZSH_HIGHLIGHT_STYLES[default]='fg=#f8f8f2'
ZSH_HIGHLIGHT_STYLES[cursor]='fg=#f8f8f2'
