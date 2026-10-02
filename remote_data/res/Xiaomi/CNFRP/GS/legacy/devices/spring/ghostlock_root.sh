#!/system/bin/sh
HOME_DIR='/data/local/tmp'
LOG="$HOME_DIR/.ghostlock_ksu.log"
KSUD="$HOME_DIR/ksud"
echo "[*] root script start uid=$(id -u) euid=$(id -u)" >"$LOG"
chmod 644 "$LOG" 2>/dev/null
echo "[*] seccomp=$(grep Seccomp /proc/self/status 2>/dev/null | tr '\n' ' ')" >>"$LOG"
if [ ! -x "$KSUD" ]; then
  KSUD=$(find /data/app -path '*/me.weishu.kernelsu*/lib/arm64/libksud.so' 2>/dev/null | head -1)
fi
if [ ! -x "$KSUD" ]; then
  KSUD=$(find /data/app -path '*/com.resukisu.resukisu*/lib/arm64/libksud.so' 2>/dev/null | head -1)
fi
if [ -z "$KSUD" ]; then KSUD=/data/local/tmp/ksud; fi
if [ ! -x "$KSUD" ]; then KSUD=/data/adb/ksu/bin/ksud; fi
echo "[*] ksud=$KSUD" >>"$LOG"
echo "[*] ksud_file=$(ls -l "$KSUD" 2>/dev/null)" >>"$LOG"
echo "[*] uname=$(uname -r)" >>"$LOG"
if [ "$(id -u)" -ne 0 ]; then
  echo '[!] temp su unavailable; aborting' | tee -a "$LOG"
  exit 1
fi
if ! grep -q kernelsu /proc/modules 2>/dev/null; then
  if [ ! -x "$KSUD" ]; then
    echo '[!] ksud missing; cannot late-load' | tee -a "$LOG"
    exit 1
  fi
  chmod 755 "$KSUD" 2>/dev/null
  KVER=$(uname -r | cut -d. -f1-2)
  AVER=$(uname -r | grep -o 'android[0-9]*' | head -1)
  KMI="${AVER}-${KVER}"
  if [ -z "$AVER" ] || [ -z "$KVER" ]; then KMI=android15-6.6; fi
  echo "[*] late-load kmi=$KMI" >>"$LOG"
  "$KSUD" late-load --kmi "$KMI" --allow-shell >>"$LOG" 2>&1
  echo "[*] late-load exit=$?" >>"$LOG"
fi
echo "[*] temp su uid=$(id -u); watching kernelsu.ko" >>"$LOG"
KSU_READY=0
for i in $(seq 1 50); do
  if grep -q kernelsu /proc/modules 2>/dev/null; then KSU_READY=1; break; fi
  sleep 0.1
done
if [ "$KSU_READY" -ne 1 ]; then
  echo '[!] KernelSU module not loaded; SELinux policy/enforcing unchanged' | tee -a "$LOG"
  exit 1
fi
echo '[+] KernelSU module loaded' | tee -a "$LOG"
echo "[*] kernelsu.ko loaded; root pid=$$ uid=$(id -u)" >>"$LOG"
echo 0 > /sys/fs/selinux/enforce 2>/dev/null
echo "[*] setenforce 0 rc=$?" >>"$LOG"
FIXUP_RC=1
for i in $(seq 1 10); do
  echo "[*] fixup: attempt $i" >>"$LOG"
  timeout 8 load_policy /sys/fs/selinux/policy >>"$LOG" 2>&1
  FIXUP_RC=$?
  if [ "$FIXUP_RC" -eq 0 ]; then
    break
  fi
  sleep 2
done
echo "[*] policy fixup rc=$FIXUP_RC" >>"$LOG"
if [ "$FIXUP_RC" -eq 0 ]; then
  echo "[*] restoring enforcing" >>"$LOG"
  echo 1 > /sys/fs/selinux/enforce 2>/dev/null
else
  echo '[!] fixup failed; SELinux left permissive' | tee -a "$LOG"
fi
