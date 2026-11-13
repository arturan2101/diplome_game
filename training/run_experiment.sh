#!/bin/bash
# Runs the bot experiment: every bot profile in every director mode, several headless
# Godot processes in parallel, the same seeds for every group. Logs go to
# user://sim_logs/<name>/<mode>_<bot>/ (on Windows: %APPDATA%/Godot/app_userdata/Ruins/sim_logs).
#
# Usage (from the project root, in Git Bash):
#   bash training/run_experiment.sh <name> [runs per process] [processes per group] [first seed]
#   bash training/run_experiment.sh experiment 15 2 3000      # 30 runs per bot and mode
# Environment (optional):
#   GODOT=<path to the console Godot binary>   (default: godot)
#   MODES="random rules"   BOTS="weak mid strong"   SECTIONS=60   SPEED=30
#   CONFIG=clean|clean_soft|full   (experiment series, res://experiment/<CONFIG>.tres; default full)
# Then: python training/analyze.py --logs <sim_logs>/<name> --out docs/figures
set -u
cd "$(dirname "$0")/.."
NAME=${1:?experiment name}
RUNS=${2:-15}
PROCS=${3:-2}
SEED0=${4:-3000}
GODOT=${GODOT:-godot}
start=$(date +%s)
for mode in ${MODES:-random rules}; do
	for bot in ${BOTS:-weak mid strong}; do
		for p in $(seq 0 $((PROCS - 1))); do
			# Each process plays RUNS runs with seeds SEED0 + p * RUNS and up.
			( "$GODOT" --headless --path . res://tools/simulate.tscn -- --bot="$bot" --mode="$mode" \
					--runs="$RUNS" --seed=$((SEED0 + p * RUNS)) --sections="${SECTIONS:-60}" \
					--speed="${SPEED:-30}" --config="${CONFIG:-full}" --log-dir="$NAME/${mode}_$bot" 2>&1 \
				| grep -E -A1 "STUCK|ERROR" | sed "s/^/$mode $bot: /" ) &
		done
	done
done
wait
echo "experiment $NAME done in $(( $(date +%s) - start )) s"
