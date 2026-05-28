:<<"BATCH_END"
@echo off
goto :BATCH_MAIN
BATCH_END

# ============================================================
# POSIX shell side (when invoked via `sh launch.cmd <target>` or via
# the kernel/sh ENOEXEC fallback). The `:<<"BATCH_END" ... BATCH_END`
# block above is consumed by `:` (the null command) as a heredoc and
# discarded. The shell then runs the code below.
# ============================================================
if [ -z "${1:-}" ]; then
    printf 'launch: missing target script name\n' >&2
    exit 2
fi
target="$1"
shift
script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
script_path="$script_dir/$target.py"

for py in python3 python; do
    if command -v "$py" >/dev/null 2>&1; then
        exec "$py" "$script_path" "$@"
    fi
done

printf 'launch: no python3 interpreter found on PATH\n' >&2
exit 127

# ============================================================
# cmd.exe side (when invoked as `launch.cmd <target>` on Windows).
# cmd parses the first line as a label (its weird name is ignored
# because nothing ever `goto`s it), then runs `@echo off` and jumps
# to :BATCH_MAIN below.
#
# The whole batch block is also wrapped in a `:<<"CMD_END" ... CMD_END`
# heredoc so that `sh -n launch.cmd` parses cleanly. The sh side never
# reaches this block at runtime (the `exec` above replaces the shell
# process), but the syntactically-invalid-for-sh batch grammar would
# otherwise trip up linters.
# ============================================================
:<<"CMD_END"
:BATCH_MAIN
@setlocal
@set "TARGET=%~1"
@if "%TARGET%"=="" (
    @echo launch: missing target script name 1>&2
    @exit /b 2
)
@shift
@set "SCRIPT=%~dp0%TARGET%.py"

@where py       >nul 2>nul && goto :run_py
@where python   >nul 2>nul && goto :run_python
@where python3  >nul 2>nul && goto :run_python3
@echo launch: no python interpreter found on PATH 1>&2
@exit /b 127

:run_py
@py -3   "%SCRIPT%" %1 %2 %3 %4 %5 %6 %7 %8 %9
@exit /b %errorlevel%

:run_python
@python  "%SCRIPT%" %1 %2 %3 %4 %5 %6 %7 %8 %9
@exit /b %errorlevel%

:run_python3
@python3 "%SCRIPT%" %1 %2 %3 %4 %5 %6 %7 %8 %9
@exit /b %errorlevel%
CMD_END
