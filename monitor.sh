#!/bin/bash
# ============================================================
#  Linux System Monitor (Bash)
#  - Affiche CPU / Mémoire / Disque
#  - Détecte OK / WARNING / CRITICAL
#  - Rafraîchit automatiquement (boucle) ou affiche une fois (-1)
#  - En one-shot, retourne un code de sortie (0/1/2)
# ============================================================

# ------------------------------------------------------------
# Étape 0 — Valeurs par défaut (seuils + intervalle + mode)
# ------------------------------------------------------------
CPU_WARN=80
MEM_WARN=80
DISK_WARN=90

CPU_CRIT=95
MEM_CRIT=95
DISK_CRIT=95

INTERVAL=2
ONE_SHOT=0

# ------------------------------------------------------------
# Étape 1 — Fonction d'aide
# ------------------------------------------------------------
usage () {
  cat <<EOF
========================================
LINUX SYSTEM MONITOR — Help
========================================
Usage: $0 [options]

Options:
  -c  CPU WARNING threshold (%)       (default: $CPU_WARN)
  -C  CPU CRITICAL threshold (%)      (default: $CPU_CRIT)
  -m  Memory WARNING threshold (%)    (default: $MEM_WARN)
  -M  Memory CRITICAL threshold (%)   (default: $MEM_CRIT)
  -d  Disk WARNING threshold (%)      (default: $DISK_WARN)
  -D  Disk CRITICAL threshold (%)     (default: $DISK_CRIT)
  -i  Refresh interval (seconds)      (default: $INTERVAL)
  -1  One-shot (print once and exit)
  -h  Show this help

Exit codes (only meaningful with -1):
  0 = OK, 1 = WARNING, 2 = CRITICAL

Examples:
  $0
  $0 -i 1
  $0 -1
  $0 -1 -c 80 -C 95 -m 80 -M 95 -d 90 -D 98
EOF
}

# ------------------------------------------------------------
# Étape 2 — Lire les options (getopts)
# ------------------------------------------------------------
while getopts ":c:C:m:M:d:D:i:1h" opt; do
  case "$opt" in
    c) CPU_WARN="$OPTARG" ;;
    C) CPU_CRIT="$OPTARG" ;;
    m) MEM_WARN="$OPTARG" ;;
    M) MEM_CRIT="$OPTARG" ;;
    d) DISK_WARN="$OPTARG" ;;
    D) DISK_CRIT="$OPTARG" ;;
    i) INTERVAL="$OPTARG" ;;
    1) ONE_SHOT=1 ;;
    h) usage; exit 0 ;;
    \?) usage; exit 1 ;;
  esac
done

# ------------------------------------------------------------
# Étape 3 — Validation simple des paramètres
# ------------------------------------------------------------
is_number () { [[ "$1" =~ ^[0-9]+$ ]]; }

for v in "$CPU_WARN" "$CPU_CRIT" "$MEM_WARN" "$MEM_CRIT" "$DISK_WARN" "$DISK_CRIT" "$INTERVAL"; do
  if ! is_number "$v"; then
    echo "Erreur: paramètres non numériques détectés." >&2
    exit 1
  fi
done

if [ "$INTERVAL" -le 0 ]; then
  echo "Erreur: INTERVAL doit être > 0" >&2
  exit 1
fi

# ------------------------------------------------------------
# Étape 4 — Couleurs (si la sortie est un terminal)
# ------------------------------------------------------------
if [ -t 1 ]; then
  GREEN=$'\033[1;32m'
  YELLOW=$'\033[1;33m'
  RED=$'\033[1;31m'
  RESET=$'\033[0m'
else
  GREEN=""; YELLOW=""; RED=""; RESET=""
fi

# Reset propre si Ctrl+C / kill
trap 'printf "%s" "$RESET"; exit 130' INT TERM

# ------------------------------------------------------------
# Étape 5 — Fonctions "métier": niveau et texte de statut
#   level: 0=OK, 1=WARNING, 2=CRITICAL
# ------------------------------------------------------------
level_for () {
  local value="$1" warn="$2" crit="$3"
  if [ "$value" -ge "$crit" ]; then
    echo 2
  elif [ "$value" -ge "$warn" ]; then
    echo 1
  else
    echo 0
  fi
}

status_for () {
  local value="$1" warn="$2" crit="$3"
  if [ "$value" -ge "$crit" ]; then
    printf "%s✖ CRITICAL%s" "$RED" "$RESET"
  elif [ "$value" -ge "$warn" ]; then
    printf "%s⚠ WARNING%s" "$YELLOW" "$RESET"
  else
    printf "%sOK%s" "$GREEN" "$RESET"
  fi
}

label_for_overall () {
  local level="$1"
  case "$level" in
    2) printf "%s✖ CRITICAL%s" "$RED" "$RESET" ;;
    1) printf "%s⚠ WARNING%s" "$YELLOW" "$RESET" ;;
    *) printf "%sOK%s" "$GREEN" "$RESET" ;;
  esac
}

# ------------------------------------------------------------
# Étape 6 — Mesure + affichage (1 “frame”)
# IMPORTANT: la fonction return le niveau global (0/1/2)
# ------------------------------------------------------------
show_monitor () {
  local NOW CPU_USAGE MEM_USAGE DISK_USAGE
  NOW=$(date "+%Y-%m-%d %H:%M:%S")

  # CPU: usage = 100 - idle
  CPU_USAGE=$(top -bn1 | awk -F'[, ]+' '/Cpu\(s\)/ {printf "%.0f", 100 - $8}')

  # Mémoire: (total - available) / total
  MEM_USAGE=$(free | awk '/Mem:/ {printf "%.0f", ($2-$7)/$2*100}')

  # Disque: / (racine)
  DISK_USAGE=$(df -P / | awk 'NR==2 {gsub("%",""); print $5}')

  local CPU_LEVEL MEM_LEVEL DISK_LEVEL OVERALL_LEVEL
  CPU_LEVEL=$(level_for "$CPU_USAGE" "$CPU_WARN" "$CPU_CRIT")
  MEM_LEVEL=$(level_for "$MEM_USAGE" "$MEM_WARN" "$MEM_CRIT")
  DISK_LEVEL=$(level_for "$DISK_USAGE" "$DISK_WARN" "$DISK_CRIT")

  OVERALL_LEVEL=$CPU_LEVEL
  [ "$MEM_LEVEL" -gt "$OVERALL_LEVEL" ] && OVERALL_LEVEL=$MEM_LEVEL
  [ "$DISK_LEVEL" -gt "$OVERALL_LEVEL" ] && OVERALL_LEVEL=$DISK_LEVEL

  local CPU_STATUS MEM_STATUS DISK_STATUS OVERALL_STATUS
  CPU_STATUS=$(status_for "$CPU_USAGE" "$CPU_WARN" "$CPU_CRIT")
  MEM_STATUS=$(status_for "$MEM_USAGE" "$MEM_WARN" "$MEM_CRIT")
  DISK_STATUS=$(status_for "$DISK_USAGE" "$DISK_WARN" "$DISK_CRIT")
  OVERALL_STATUS=$(label_for_overall "$OVERALL_LEVEL")

  printf "========================================\n"
  printf "        LINUX SYSTEM MONITOR\n"
  printf "========================================\n"
  printf "Updated        : %s\n\n" "$NOW"

  printf "CPU Usage       : %3s%%\n" "$CPU_USAGE"
  printf "Memory Usage    : %3s%%\n" "$MEM_USAGE"
  printf "Disk Usage      : %3s%%\n\n" "$DISK_USAGE"

  printf "========================================\n"
  printf "STATUS\n"
  printf "========================================\n\n"

  printf "CPU            : %s\n" "$CPU_STATUS"
  printf "Memory         : %s\n" "$MEM_STATUS"
  printf "Disk           : %s\n" "$DISK_STATUS"
  printf "\nOverall Status : %s\n" "$OVERALL_STATUS"

  printf "\nSeuils (W/C)    : CPU=%s/%s  MEM=%s/%s  DISK=%s/%s  Interval=%ss\n" \
    "$CPU_WARN" "$CPU_CRIT" "$MEM_WARN" "$MEM_CRIT" "$DISK_WARN" "$DISK_CRIT" "$INTERVAL"

  return "$OVERALL_LEVEL"
}

# ------------------------------------------------------------
# Étape 7 — Exécution: one-shot ou boucle
# ------------------------------------------------------------
if [ "$ONE_SHOT" -eq 1 ]; then
  show_monitor
  rc=$?
  printf "%s" "$RESET"
  exit "$rc"
fi

while true; do
  clear
  show_monitor >/dev/null
  # (on ignore le code de retour en mode boucle)
  show_monitor
  sleep "$INTERVAL"
done
