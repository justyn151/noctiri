# Noctiri user executables.
# Keep this idempotent because login and interactive shell startup files may
# both source it.
case ":${PATH:-}:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin${PATH:+:$PATH}" ;;
esac
