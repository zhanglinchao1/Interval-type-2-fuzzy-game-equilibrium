#!/bin/bash

LAUNCHD_PORT=${LAUNCHD_PORT:-9999}
LAUNCHD_HOST=${LAUNCHD_HOST:-127.0.0.1}
LAUNCHD_BIN=${LAUNCHD_BIN:-../../bin/veins_launchd}
LAUNCHD_SUMO_CMD=${LAUNCHD_SUMO_CMD:-sumo}
LAUNCHD_LOG=${LAUNCHD_LOG:-logs/veins_launchd_strong_${LAUNCHD_PORT}.log}
LAUNCHD_PID=""

launchd_ready() {
    python3 - "$LAUNCHD_HOST" "$LAUNCHD_PORT" <<'PY'
import socket
import sys

host = sys.argv[1]
port = int(sys.argv[2])
sock = None
try:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(0.25)
    sock.connect((host, port))
except OSError:
    ok = False
else:
    ok = True
finally:
    if sock is not None:
        sock.close()
sys.exit(0 if ok else 1)
PY
}

ensure_launchd() {
    mkdir -p logs

    if [ "${LAUNCHD_REUSE_EXISTING:-1}" = "1" ] && launchd_ready; then
        echo "[$(date)] Reusing existing Veins launchd on ${LAUNCHD_HOST}:${LAUNCHD_PORT}"
        return 0
    fi

    if [ ! -x "$LAUNCHD_BIN" ]; then
        echo "ERROR: launchd executable not found or not executable: $LAUNCHD_BIN" >&2
        exit 1
    fi

    echo "[$(date)] Starting Veins launchd on ${LAUNCHD_HOST}:${LAUNCHD_PORT}"
    "$LAUNCHD_BIN" \
        --bind "$LAUNCHD_HOST" \
        --port "$LAUNCHD_PORT" \
        --command "$LAUNCHD_SUMO_CMD" \
        --logfile "$LAUNCHD_LOG" \
        > "${LAUNCHD_LOG}.stdout" 2>&1 &
    LAUNCHD_PID=$!

    for _ in $(seq 1 40); do
        if launchd_ready; then
            echo "[$(date)] Veins launchd ready (pid=${LAUNCHD_PID}, log=${LAUNCHD_LOG})"
            return 0
        fi
        if ! kill -0 "$LAUNCHD_PID" 2>/dev/null; then
            echo "ERROR: Veins launchd exited before opening ${LAUNCHD_HOST}:${LAUNCHD_PORT}" >&2
            tail -80 "${LAUNCHD_LOG}.stdout" 2>/dev/null || true
            tail -80 "$LAUNCHD_LOG" 2>/dev/null || true
            exit 1
        fi
        sleep 0.25
    done

    echo "ERROR: Veins launchd did not open ${LAUNCHD_HOST}:${LAUNCHD_PORT} in time" >&2
    tail -80 "${LAUNCHD_LOG}.stdout" 2>/dev/null || true
    tail -80 "$LAUNCHD_LOG" 2>/dev/null || true
    exit 1
}

cleanup_launchd() {
    if [ -n "$LAUNCHD_PID" ] && kill -0 "$LAUNCHD_PID" 2>/dev/null; then
        echo "[$(date)] Stopping Veins launchd pid=${LAUNCHD_PID}"
        kill "$LAUNCHD_PID" 2>/dev/null || true
        wait "$LAUNCHD_PID" 2>/dev/null || true
    fi
}

run_opp_with_retries() {
    local label=$1
    local log=$2
    shift 2

    local max_attempts=${STRONG_RUN_ATTEMPTS:-2}
    local attempt=1
    local rc=0
    while [ "$attempt" -le "$max_attempts" ]; do
        if [ "$attempt" -gt 1 ]; then
            echo "WARN: retrying ${label} (attempt ${attempt}/${max_attempts})" >&2
            sleep "$((attempt * 2))"
        fi

        "$@" > "$log" 2>&1
        rc=$?
        if [ "$rc" -eq 0 ]; then
            return 0
        fi

        echo "WARN: ${label} failed on attempt ${attempt}/${max_attempts} (exit=${rc})" >&2
        attempt=$((attempt + 1))
    done

    return "$rc"
}
