#!/system/bin/sh
# KSU loader — exec'd by the rooted anchor (uid=0, kernel:s0 context).
# CORRECT RECIPE (validated on sky):
#   1) FORCE SELinux permissive FIRST — the exploit's arb-write permissive
#      gets reverted to enforcing by the time we run; late-load under
#      enforcing leaves the module refcount=0 and new apps get SIGKILLed.
#   2) late-load --allow-shell (insmod)
#   3) ksud stages post-fs-data/services/boot-completed (without them the
#      module stays refcount=0 and apps still get killed).
#   NEVER run pm/cmd/binder commands: in kernel:s0 binder is unavailable
#   ("Can't find service: package") and pm install corrupts system state.
RUNDIR=${KSU_RUNDIR:-/data/local/tmp}
LOG=$RUNDIR/ksu_loader.log
echo "=== ksu_loader start $(date) uid=$(id -u) rundir=$RUNDIR ===" > "$LOG"
echo "selinux before: $(getenforce 2>&1)" >> "$LOG"

# --- 1. FORCE permissive ---
# anchor holds kernel creds; write via the sysfs knob (setenforce 0)
if [ -w /sys/fs/selinux/enforce ] || echo 0 > /sys/fs/selinux/enforce 2>/dev/null; then
  echo 0 > /sys/fs/selinux/enforce 2>/dev/null
  echo "setenforce 0 -> $(getenforce 2>&1)" >> "$LOG"
else
  setenforce 0 2>/dev/null
  echo "setenforce 0 (alt) -> $(getenforce 2>&1)" >> "$LOG"
fi
# hard fallback: loader may run as non-root macro context in some paths
[ "$(getenforce 2>/dev/null)" = "Permissive" ] || echo "WARN: still $(getenforce 2>&1)" >> "$LOG"

MGR=me.weishu.kernelsu
LIBKSUD=""
for c in "$RUNDIR/libksud.so" /data/local/tmp/libksud.so; do
  if [ -x "$c" ]; then LIBKSUD=$c; break; fi
done
if [ -z "$LIBKSUD" ]; then
  LIBKSUD=$(find /data/app -name libksud.so 2>/dev/null | grep "$MGR" | head -1)
fi
echo "libksud: $LIBKSUD" >> "$LOG"
[ -z "$LIBKSUD" ] && { echo "FAIL: no libksud.so" >> "$LOG"; exit 1; }

echo "=== late-load ===" >> "$LOG"
"$LIBKSUD" late-load --allow-shell --package-name "$MGR" >> "$LOG" 2>&1
echo "late-load exit=$?" >> "$LOG"

echo "=== ksud stages ===" >> "$LOG"
"$LIBKSUD" post-fs-data >> "$LOG" 2>&1;    echo "post-fs-data exit=$?" >> "$LOG"
"$LIBKSUD" services >> "$LOG" 2>&1;        echo "services exit=$?" >> "$LOG"
"$LIBKSUD" boot-completed >> "$LOG" 2>&1;  echo "boot-completed exit=$?" >> "$LOG"

echo "=== verify ===" >> "$LOG"
getenforce >> "$LOG" 2>&1
grep kernelsu /proc/modules >> "$LOG" 2>&1
echo "=== done ===" >> "$LOG"