#!/system/bin/sh
# ============================================================
#  GhostLock One-Click KSU Root - FULL run (sky V14.0.8.0 / 5.10.168)
#  运行时 LKM 方案：不动 boot 分区，未解锁 BL 也可用。
#  与 go.sh 的区别：go.sh 是智能入口（已 root 则跳过）；
#  run_ksu_full.sh 无条件完整跑一遍（适合强制重跑）。
#
#  用法（A-Shell 或 adb shell）:
#    sh /storage/emulated/0/ksu_root/run_ksu_full.sh
# ============================================================
SRC=/storage/emulated/0/ksu_root
DST=/data/local/tmp
LOG=$DST/ksu_run_full.log
echo "=============================================" > $LOG
echo " GhostLock One-Click KSU Root (FULL)  $(date)" >> $LOG
echo " id: $(id)" >> $LOG
echo " boot_id: $(cat /proc/sys/kernel/random/boot_id 2>/dev/null)" >> $LOG
echo "=============================================" >> $LOG

# ---------- 1. 部署文件到 /data/local/tmp ----------
echo "[*] 部署文件到 $DST" >> $LOG
for f in gl_sky_exploit libksud.so ksu_loader.sh KernelSU_manager.apk; do
  if [ -f "$SRC/$f" ]; then
    cp "$SRC/$f" "$DST/$f" 2>>$LOG && chmod 755 "$DST/$f" 2>>$LOG
    echo "    $f -> OK" >> $LOG
  else
    echo "    [X] 缺少 $SRC/$f" >> $LOG
  fi
done
[ ! -x "$DST/gl_sky_exploit" ] && { echo "[X] exploit 缺失" >> $LOG; cat $LOG; exit 1; }
[ ! -x "$DST/libksud.so" ] && { echo "[X] libksud.so 缺失" >> $LOG; cat $LOG; exit 1; }

# ---------- 2. 创建运行目录 + 启动 exploit（长超时，verify 每个 walk 40s） ----------
RD=$DST/ksu_run_$$
mkdir -p "$RD"
cp "$DST/gl_sky_exploit" "$RD/exploit"
cp "$DST/ksu_loader.sh" "$RD/ksu_loader.sh"
cp "$DST/libksud.so" "$RD/libksud.so"
chmod 755 "$RD/exploit" "$RD/ksu_loader.sh" "$RD/libksud.so"
cd "$RD"

echo "[*] 运行 exploit (shift=0, timeout 500s, WALK_ATTEMPTS=6)..." >> $LOG
env SE_LINUX=1 SE_SKIP_RESTORE=0 KSU_LOADER=1 KSU_RUNDIR="$RD" \
  SLIDE_SHIFT=0 SUSPECT_CPU=150 SUSPECT_LIMIT=8 \
  SYSCTL_WALK_ATTEMPTS=6 \
  timeout 500 ./exploit >> "$RD/gl.log" 2>&1
echo "exploit exit=$?" >> $LOG

# ---------- 3. 保持 SELinux Permissive（exploit 链可能恢复 enforcing） ----------
for i in 1 2 3 4 5 6 7 8; do
  if su -c 'setenforce 0' 2>/dev/null; then
    echo "setenforce 0 (post-exploit try $i) -> $(getenforce 2>&1)" >> $LOG
    [ "$(getenforce 2>/dev/null)" = "Permissive" ] && break
  fi
  sleep 1
done
echo "final selinux: $(getenforce 2>&1)" >> $LOG

# ---------- 4. 汇总结果 ----------
echo "---------------------------------------------" >> $LOG
echo "[*] exploit 关键结果:" >> $LOG
grep -E 'landed|PERMISSIVE|chain complete|root proof' "$RD/gl.log" 2>/dev/null | tail -10 >> $LOG
echo "[*] ksu_loader 结果:" >> $LOG
cat "$RD/ksu_loader.log" 2>/dev/null | tail -18 >> $LOG
echo "---------------------------------------------" >> $LOG

# ---------- 5. 验证 ----------
if grep -q kernelsu /proc/modules 2>/dev/null; then
  echo "[+] KSU 模块已加载: $(grep kernelsu /proc/modules | head -1)" >> $LOG
  if su -c id 2>/dev/null | grep -q 'uid=0'; then
    echo "[+] ROOT 成功: $(su -c id 2>&1 | head -1)" >> $LOG
    echo "ALL_DONE_ROOT_OK" >> $LOG
  else
    echo "[-] 模块加载但 su 不可用" >> $LOG
    echo "DONE_MODULE_NO_SU" >> $LOG
  fi
else
  echo "[-] KSU 模块未加载" >> $LOG
  echo "DONE_NO_MODULE" >> $LOG
fi

# ---------- 6. 清理残留 exploit 进程 ----------
for d in /proc/[0-9]*; do
  p=${d#/proc/}
  c=$(cat /proc/$p/comm 2>/dev/null)
  case "$c" in
    exploit|gl_*|ksanch0r|ksucmdwatch) kill -9 $p 2>/dev/null;;
  esac
done

echo "[*] 完整日志: $LOG" >> $LOG
cat $LOG
