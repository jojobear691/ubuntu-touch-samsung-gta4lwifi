#!/bin/bash
set +e

LOG="/userdata/ut-tests/taba7-audio-kernel.log"
mkdir -p /userdata/ut-tests

{
echo
echo "===== TABA7 AUDIO KERNEL BRING-UP ====="
date
uptime
cat /proc/sys/kernel/random/boot_id 2>&1 || true

echo
echo "===== PRE AUDIO STATE ====="
cat /proc/asound/cards 2>&1 || true

if grep -q "bengal-qrd-snd-card" /proc/asound/cards 2>/dev/null; then
  echo "CARD_ALREADY_UP=1"
  exit 0
fi

echo
echo "===== LOAD HOST AUDIO MODULES ====="
modprobe -a -v \
  q6_pdr_dlkm q6_notifier_dlkm snd_event_dlkm apr_dlkm adsp_loader_dlkm q6_dlkm \
  native_dlkm usf_dlkm pinctrl_lpi_dlkm swr_dlkm swr_ctrl_dlkm platform_dlkm stub_dlkm \
  wcd_core_dlkm wcd9xxx_dlkm wsa881x_analog_dlkm bolero_cdc_dlkm va_macro_dlkm \
  rx_macro_dlkm tx_macro_dlkm mbhc_dlkm wcd937x_dlkm wcd937x_slave_dlkm \
  pm2250_spmi_dlkm rouleur_dlkm rouleur_slave_dlkm machine_dlkm fs18xx_dlkm
MODPROBE_RC=$?
echo "MODPROBE_RC=$MODPROBE_RC"

sleep 2

echo
echo "===== BOOT ADSP IF CARD STILL ABSENT ====="
if grep -q "bengal-qrd-snd-card" /proc/asound/cards 2>/dev/null; then
  echo "CARD_UP_AFTER_MODPROBE=1"
else
  if [ -w /sys/kernel/boot_adsp/boot ]; then
    echo 1 > /sys/kernel/boot_adsp/boot
    BOOT_ADSP_RC=$?
    echo "BOOT_ADSP_RC=$BOOT_ADSP_RC"
  else
    echo "BOOT_ADSP_PATH_NOT_WRITABLE"
  fi
fi

echo
echo "===== WAIT FOR CARD0 ====="
CARD_UP=0
for i in $(seq 1 30); do
  if grep -q "bengal-qrd-snd-card" /proc/asound/cards 2>/dev/null; then
    CARD_UP=1
    echo "CARD_UP_AT_SECOND=$i"
    break
  fi
  sleep 1
done

echo
echo "===== POST AUDIO STATE ====="
cat /sys/devices/platform/soc/ab00000.qcom,lpass/subsys0/state 2>&1 || true
cat /proc/asound/cards 2>&1 || true
aplay -l 2>&1 | sed -n "1,120p" || true

echo
echo "===== RECENT AUDIO DMESG ====="
dmesg -T 2>&1 \
  | grep -i -E "adsp|audio_pd|apr|q6|bengal-asoc|sound card|snd|asoc|wcd|bolero|macro|fs18|fail|error" \
  | tail -160 || true

if [ "$CARD_UP" = "1" ]; then
  echo "TABA7_AUDIO_KERNEL_RESULT=PASS"
  exit 0
else
  echo "TABA7_AUDIO_KERNEL_RESULT=FAIL"
  exit 1
fi
} >> "$LOG" 2>&1
