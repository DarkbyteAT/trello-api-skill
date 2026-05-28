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

@rem Fast path (0..9 forwarded args): pass positionally as %1..%9 so
@rem each arg preserves the user's original quoting verbatim. Both shell
@rem operators (&, |, ^, <, >) and exclamation marks survive because the
@rem args are never stored in a cmd variable (which would trigger a
@rem second expansion pass that mangles one set or the other).
@rem
@rem Slow path (10+ forwarded args): cmd has a hard %1..%9 positional
@rem limit, so we write each arg to a temp file (one per line, with
@rem setlocal toggling to keep ! and & safe), then re-exec the target
@rem via _dispatch.py which reads the file and calls os.execv.
@rem
@rem The slow path is unreachable for any realistic Trello call (peak
@rem ~7 args) — it exists so we never silently truncate.

@call :has_more_than_nine %*
@if errorlevel 1 goto :slow_path

:fast_path
@where py       >nul 2>nul && goto :run_py_fast
@where python   >nul 2>nul && goto :run_python_fast
@where python3  >nul 2>nul && goto :run_python3_fast
@echo launch: no python interpreter found on PATH 1>&2
@exit /b 127

:run_py_fast
@py -3   "%SCRIPT%" %1 %2 %3 %4 %5 %6 %7 %8 %9
@exit /b %errorlevel%

:run_python_fast
@python  "%SCRIPT%" %1 %2 %3 %4 %5 %6 %7 %8 %9
@exit /b %errorlevel%

:run_python3_fast
@python3 "%SCRIPT%" %1 %2 %3 %4 %5 %6 %7 %8 %9
@exit /b %errorlevel%

:slow_path
@set "ARGSFILE=%TEMP%\trello-launch-%RANDOM%-%RANDOM%.args"
@type nul > "%ARGSFILE%"
:write_loop
@rem End-of-args check: `%~1` strips outer quotes, so an empty quoted
@rem arg ("") gives `%~1=""` AND `%1=""` (the literal quoted-empty
@rem form). A real end-of-args has both expansions empty. Requiring
@rem BOTH to be empty distinguishes the two cases.
@if "%~1"=="" if "%1"=="" goto :write_done
@rem Inline the writer (was :write_one) — DisableDelayedExpansion
@rem during the set so a literal ! in the arg survives; then
@rem EnableDelayedExpansion only for the echo so & | ^ < > inside the
@rem variable value aren't interpreted as cmd operators. `echo(` (open
@rem paren, no space) is the cmd idiom for echoing strings that may
@rem start with reserved tokens.
@setlocal DisableDelayedExpansion
@set "ARG=%~1"
@setlocal EnableDelayedExpansion
@(echo(!ARG!) >> "%ARGSFILE%"
@endlocal
@endlocal
@shift
@goto :write_loop

:write_done
@rem Dispatch through goto labels so `%errorlevel%` expands on its own
@rem line AFTER the interpreter exits. The previous inline-`&` form
@rem captured the errorlevel of the preceding `@where` check (always 0)
@rem because cmd parses the whole line before executing it. _dispatch.py
@rem cleans up ARGSFILE itself; the no-interpreter branch still needs
@rem an explicit @del since it never reaches _dispatch.py.
@where py       >nul 2>nul && goto :run_py_slow
@where python   >nul 2>nul && goto :run_python_slow
@where python3  >nul 2>nul && goto :run_python3_slow
@del "%ARGSFILE%"
@echo launch: no python interpreter found on PATH 1>&2
@exit /b 127

:run_py_slow
@py -3   "%~dp0_dispatch.py" "%SCRIPT%" "%ARGSFILE%"
@exit /b %errorlevel%

:run_python_slow
@python  "%~dp0_dispatch.py" "%SCRIPT%" "%ARGSFILE%"
@exit /b %errorlevel%

:run_python3_slow
@python3 "%~dp0_dispatch.py" "%SCRIPT%" "%ARGSFILE%"
@exit /b %errorlevel%

:has_more_than_nine
@rem Returns errorlevel 1 if more than 9 args were passed. Subroutines
@rem have their own positional-parameter scope so shifting here does
@rem not disturb the caller's %1..%9. The dual `%~1` / `%1` check
@rem mirrors :write_loop — needed so an empty quoted 10th arg ("")
@rem still trips the >9 detection.
@shift
@shift
@shift
@shift
@shift
@shift
@shift
@shift
@shift
@if not "%~1"=="" exit /b 1
@if not "%1"=="" exit /b 1
@exit /b 0
CMD_END
