#!/bin/bash
# ============================================================
# Flower Addon Demo  --  Interactive mode
#
# Run this script from any session (e.g. Test:0).
# It sends commands to flower:0 (the recording window).
#
# Interaction model:
#   1. Script prints a preview of the next command here
#   2. Press Enter to type it into flower pane (no execution yet)
#   3. Press Enter again to execute in flower pane
# ============================================================

REPO="/home/cloud-user/workspace/ocm-addon-contrib"
DEMO_DIR="/home/cloud-user/workspace/flower-addon-demo/flower-addon/hack/demo"
CTX_DIR="$HOME/flower-demo"   # context dirs -- outside git repo, no branch info in prompt

HUB="flower:0.0"   # top pane        -- hub context
C1="flower:0.1"    # bottom-left     -- cluster1 live view
C2="flower:0.2"    # bottom-right    -- cluster2 live view

KUBECONFIG_HUB=~/.kube/hub
KUBECONFIG_C1=~/.kube/cluster1
KUBECONFIG_C2=~/.kube/cluster2

# ─── Helpers ─────────────────────────────────────────────────

# Type speed (seconds per character)
TYPE_SPEED=0.04

# Type text into hub pane character by character (demo-magic style)
type_into_hub() {
  local text="$*"
  local i ch
  for (( i=0; i<${#text}; i++ )); do
    ch="${text:$i:1}"
    tmux set-buffer -- "$ch"
    tmux paste-buffer -t "$HUB"
    sleep $TYPE_SPEED
  done
}

# Type command into hub pane, wait for operator Enter, then execute
run() {
  type_into_hub "$*"
  read -rs
  tmux send-keys -t "$HUB" Enter
  sleep 0.8
}

# Run silently in hub pane (no typing effect, no interaction)
hub_silent() { tmux send-keys -t "$HUB" "$*" Enter; sleep 0.6; }
c1()         { tmux send-keys -t "$C1"  "$*" Enter; sleep 0.6; }
c2()         { tmux send-keys -t "$C2"  "$*" Enter; sleep 0.6; }

# Wait N seconds
hold() { sleep "${1:-4}"; }

# Section banner in hub pane -- operator presses Enter to proceed
banner() {
  hub_silent "# ================================================================"
  hub_silent "# $1"
  hub_silent "# ================================================================"
  read -rs
  tmux select-pane -t "$HUB" -T "$1"
  tmux select-pane -t "$C1"  -T "cluster1 | Managed Cluster"
  tmux select-pane -t "$C2"  -T "cluster2 | Managed Cluster"
  tmux select-pane -t "$HUB"
  sleep 0.3
}

# Inline comment in hub pane
note() {
  hub_silent "# $1"
  sleep 0.3
}

# ─── Pane Setup ──────────────────────────────────────────────

tmux split-window -t flower:0.0 -v -p 35
tmux split-window -t flower:0.1 -h
sleep 0.5

# Each pane cd into its named context dir (outside git repo -- clean prompt)
tmux send-keys -t "$C2"  "cd $CTX_DIR/cluster2 && clear" Enter; sleep 0.3
tmux send-keys -t "$C1"  "cd $CTX_DIR/cluster1 && clear" Enter; sleep 0.3
tmux send-keys -t "$HUB" "cd $CTX_DIR/hub      && clear" Enter; sleep 0.5

# Focus hub pane
tmux select-pane -t "$HUB"
sleep 0.5

# Export env vars in all panes
hub_silent "export REPO=$REPO DEMO_DIR=$DEMO_DIR"
hub_silent "export KUBECONFIG_HUB=$KUBECONFIG_HUB KUBECONFIG_C1=$KUBECONFIG_C1 KUBECONFIG_C2=$KUBECONFIG_C2"
hub_silent "export KUBECONFIG=$KUBECONFIG_HUB"
c1 "export KUBECONFIG=$KUBECONFIG_C1"
c2 "export KUBECONFIG=$KUBECONFIG_C2"
hold 1

# ─── Agenda (printed as comments in hub pane) ─────────────────
hub_silent "# =========================================================================="
hub_silent "# Flower Addon on Open Cluster Management -- Demo Agenda"
hub_silent "# =========================================================================="
hub_silent "#"
hub_silent "#   1. OCM Multi-Cluster Setup"
hub_silent "#      Bootstrap hub + cluster1 + cluster2, join and accept managed clusters"
hub_silent "#"
hub_silent "#   2. Flower Addon -- SuperNode Definition"
hub_silent "#      Define addon via AddOnTemplate, ClusterManagementAddOn"
hub_silent "#"
hub_silent "#   3. Flower Addon -- Resource-based Scheduling"
hub_silent "#      Schedule SuperNode onto clusters based on GPU resource labels"
hub_silent "#"
hub_silent "#   4. Flower Addon -- Application Distribution"
hub_silent "#      Distribute ClientApp across clusters via MWRS + data-aware Placement"
hub_silent "#"
hub_silent "# =========================================================================="
hold 2
read -rs

# ─── Section 1: OCM Environment Setup ────────────────────────

banner "Section 1/4  |  OCM Multi-Cluster Setup"

run "kind create cluster --name hub --config $DEMO_DIR/hub-kind.yaml"
hold 50

run "kind create cluster --name cluster1 & kind create cluster --name cluster2 & wait"
hold 65

hub_silent "kind get kubeconfig --name hub      > $KUBECONFIG_HUB"
hub_silent "kind get kubeconfig --name cluster1 > $KUBECONFIG_C1"
hub_silent "kind get kubeconfig --name cluster2 > $KUBECONFIG_C2"

hub_silent "export KUBECONFIG=$KUBECONFIG_HUB"
c1         "export KUBECONFIG=$KUBECONFIG_C1"
c2         "export KUBECONFIG=$KUBECONFIG_C2"
hold 2

run "clusteradm init --wait"
hold 90

hub_silent 'JOINCMD=$(clusteradm get token | grep clusteradm)'
hold 2

run 'eval "${JOINCMD//<cluster_name>/cluster1} --force-internal-endpoint-lookup --wait --kubeconfig $KUBECONFIG_C1"'
hold 35

run 'eval "${JOINCMD//<cluster_name>/cluster2} --force-internal-endpoint-lookup --wait --kubeconfig $KUBECONFIG_C2"'
hold 35

run "clusteradm accept --clusters cluster1,cluster2 --wait"
hold 40

run "kubectl get managedclusters"
hold 4

# ─── Section 2: Flower Addon Deployment ──────────────────────

banner "Section 2/4  |  Flower Addon -- SuperNode Definition"

hub_silent 'HUB_IP=$(kubectl get nodes -o jsonpath="{.items[0].status.addresses[?(@.type==\"InternalIP\")].address}")'
run 'echo "Hub IP: $HUB_IP"'
hold 2

run 'cd $REPO/flower-addon && helm install flower-addon ./charts/flower-addon --set deploymentConfig.superlinkAddress=$HUB_IP --set addon.installStrategy=Placements --set placement.gpu.enabled=true --set placement.gpu.clusterSet=global'
hold 20

run "kubectl wait --for=condition=available deployment/superlink -n flower-system --timeout=90s"
hold 5

run "kubectl get pods -n flower-system"
hold 3

note "AddOnTemplate -- defines how SuperNode is installed on each Managed Cluster"
run "kubectl get addontemplate flower-addon -oyaml"
hold 12

note "ClusterManagementAddOn -- global Addon policy, installStrategy=Placements"
run "kubectl get clustermanagementaddon flower-addon -oyaml"
hold 12

# ─── Section 3: Resource-based Scheduling → SuperNode ────────

banner "Section 3/4  |  Flower Addon -- Resource-based Scheduling"

run "kubectl get placement flower-addon-gpu-placement -n open-cluster-management -oyaml"
hold 8

note "No cluster has gpu=true yet -- PlacementDecision selects nobody"
run "kubectl get placementdecisions -n open-cluster-management"
hold 3

# Start live pod watch in bottom panes (silent, no interaction needed)
c1 "watch kubectl get pods -n flower-addon"
c2 "watch kubectl get pods -n flower-addon"
hold 1

run "kubectl label managedcluster cluster2 gpu=true"
hold 3

run "kubectl get placementdecisions -n open-cluster-management"
hold 5

note "cluster2 selected -- SuperNode installing... watch the bottom-right pane"
run "kubectl get managedclusteraddons -A"
hold 30

note "Scale out: label cluster1 gpu=true -- SuperNode auto-installed there too"
run "kubectl label managedcluster cluster1 gpu=true"
hold 5

run "kubectl get managedclusteraddons -A"
hold 35

run "kubectl get managedclusteraddon flower-addon -n cluster1 -oyaml"
hold 10

# ─── Section 4: ManifestWorkReplicaSet App Distribution ──────

banner "Section 4/4  |  Flower Addon -- Application Distribution"

run "kubectl label managedcluster cluster1 data=cifar10"
hold 2

note "Placement: addon=Available AND data=cifar10  (cluster2 has no data label yet)"
run "kubectl apply -f $DEMO_DIR/clientapp-with-data.yaml"
hold 5

run "kubectl get manifestworkreplicaset flower-superexec-clientapp -n flower-system -oyaml"
hold 10

note "ManifestWork auto-created for cluster1 -- the per-cluster work package"
run "kubectl get manifestworks -A"
hold 6

note "Scale out: label cluster2 with data=cifar10 -- ClientApp auto-distributed"
run "kubectl label managedcluster cluster2 data=cifar10"
hold 8

run "kubectl get placementdecisions -n flower-system"
hold 4

run "kubectl get manifestworks -A"
hold 5

banner "Demo Complete"
hub_silent "# SuperNode  -- infrastructure layer  : scheduled by gpu label"
hub_silent "# ClientApp  -- application layer     : scheduled by addon=Available + data label"
hub_silent "# ManifestWorkReplicaSet drives automatic distribution as labels change"
