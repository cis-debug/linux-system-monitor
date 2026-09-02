# Linux System Monitor

Petit outil de monitoring Linux écrit en **Bash**.  
Il surveille les ressources principales de la machine (**CPU, mémoire, disque**) et affiche un statut **OK / WARNING / CRITICAL**.

---

## Fonctionnalités

- Affichage de l’utilisation **CPU / Mémoire / Disque** en pourcentage
- Statuts par ressource : `OK` / `⚠ WARNING` / `✖ CRITICAL`
- **Overall Status** (statut global)
- Couleurs dans le terminal (vert / jaune / rouge)
- Rafraîchissement automatique (intervalle configurable)
- Mode **one-shot** (`-1`) : affiche une fois et quitte
- En mode `-1` : **codes de sortie** `0/1/2` utilisables en supervision (cron, CI, etc.)
- Seuils configurables en ligne de commande

---

## Prérequis

- Linux (ou **WSL**)
- Bash
- Outils disponibles sur la plupart des distributions : `top`, `free`, `df`, `awk`

---

## Installation

```bash
git clone https://github.com/<TON_PSEUDO_GITHUB>/linux-system-monitor.git
cd linux-system-monitor
chmod +x monitor.sh

##Utilisation
# Mode monitoring (refresh toutes les 2s, Ctrl+C pour quitter)
./monitor.sh

# Refresh toutes les secondes
./monitor.sh -i 1

# Afficher une fois et quitter
./monitor.sh -1

# Seuils personnalisés (WARNING / CRITICAL)
./monitor.sh -c 80 -C 95 -m 80 -M 95 -d 90 -D 98

# Aide
./monitor.sh -h
