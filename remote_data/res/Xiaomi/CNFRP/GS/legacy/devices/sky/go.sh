#!/system/bin/sh
# ============================================================
#  GhostLock One-Click KSU Root (device-side, for A-Shell / adb shell)
#  纯运行时 LKM 方案 —— 不动 boot 分区，未解锁 BL 也可用
#
#  流程: exploit (root+permissive) -> anchor exec loader -> late-load 激活
#        -> boot_id 恢复 -> KSU root 生效
#
#  用法: 用 A-Shell 执行  sh /storage/emulated/0/ksu_root/go.sh
#        首次请先运行 setup (把文件部署到 /data/local/tmp)
# ============================================================
SRC=/storage/emulated/0/ksu_root
DST=/data/local/tmp
LOG=$DST/ksu_onelog.log
echo "=============================================" > $LOG
echo " GhostLock One-Click KSU Root  $(date)" >> $LOG
echo " id: $(id)" >> $LOG
echo "=============================================" >> $LOG

# ---------- 0. 前置: 用已加载的 KSU 直接 su（若已在 root 态） ----------
if grep -q kernelsu /proc/modules 2>/dev/null; then
  echo "[*] KSU 模块已加载，检查 su..." >> $LOG
  if su -c 'id' 2>/dev/null | grep -q 'uid=0'; then
    echo "[+] 已在 root 态 (KSU 已激活)。无需重复操作。" >> $LOG
    su -c id 2>&1 | head -1 >> $LOG
    echo "ALL_DONE_ALREADY_ROOT" >> $LOG
    cat $LOG
    exit 0
  fi
fi

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

if [ ! -x "$DST/gl_sky_exploit" ]; then
  echo "[X] exploit 部署失败，请确认 $SRC 下有 gl_sky_exploit" >> $LOG
  cat $LOG
  exit 1
fi
if [ ! -x "$DST/libksud.so" ]; then
  echo "[X] libksud.so 缺失" >> $LOG
  cat $LOG
  exit 1
fi

# ---------- 2. 创建运行目录 + 启动 exploit ----------
RD=$DST/ksu_run_$$
mkdir -p "$RD"
cp "$DST/gl_sky_exploit" "$RD/exploit"
cp "$DST/ksu_loader.sh" "$RD/ksu_loader.sh"
cp "$DST/libksud.so" "$RD/libksud.so"
[ -f "$DST/KernelSU_manager.apk" ] && cp "$DST/KernelSU_manager.apk" "$RD/KernelSU_manager.apk"
chmod 755 "$RD/exploit" "$RD/ksu_loader.sh" "$RD/libksud.so"
cd "$RD"

echo "[*] 运行 exploit (shift=0, 约30-500s)..."
echo "    boot_id: $(cat /proc/sys/kernel/random/boot_id)" >> $LOG
env SE_LINUX=1 SE_SKIP_RESTORE=0 KSU_LOADER=1 KSU_RUNDIR="$RD" \
  SLIDE_SHIFT=0 SUSPECT_CPU=150 SUSPECT_LIMIT=8 \
  SYSCTL_WALK_ATTEMPTS=6 \
  timeout 500 ./exploit >> "$RD/gl.log" 2>&1
echo "exploit exit=$?" >> $LOG

# --- 保持 SELinux Permissive（exploit 链可能恢复 enforcing -> 新应用打不开）---
for i in 1 2 3 4 5; do
  if su -c 'setenforce 0' 2>/dev/null; then
    echo "setenforce 0 (post-exploit try $i) -> $(getenforce 2>&1)" >> $LOG
    [ "$(getenforce 2>/dev/null)" = "Permissive" ] && break
  fi
  sleep 1
done
echo "final selinux: $(getenforce 2>&1)" >> $LOG

# ---------- 3. 汇总结果 ----------
echo "---------------------------------------------" >> $LOG
echo "[*] exploit 关键结果:" >> $LOG
grep -E 'landed|PERMISSIVE|chain complete|root proof' "$RD/gl.log" 2>/dev/null | tail -8 >> $LOG
echo "[*] ksu_loader 结果:" >> $LOG
cat "$RD/ksu_loader.log" 2>/dev/null | tail -15 >> $LOG
echo "---------------------------------------------" >> $LOG

# ---------- 4. 验证 ----------
if grep -q kernelsu /proc/modules 2>/dev/null; then
  echo "[+] KSU 模块已加载" >> $LOG
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

# ---------- 5. 清理残留 exploit 进程 ----------
for d in /proc/[0-9]*; do
  p=${d#/proc/}
  c=$(cat /proc/$p/comm 2>/dev/null)
  case "$c" in
    exploit|gl_*|ksanch0r|ksucmdwatch)
      kill -9 $p 2>/dev/null
      ;;
  esac
done

echo "[*] 完整日志: $LOG" >> $LOG
cat $LOG