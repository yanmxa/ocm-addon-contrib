#!/bin/bash
# Dry-run: preview all flower pane messages by sending them to flower:0.0
# ctrl output stays in current session, flower content goes to flower:0.0

TARGET="flower:0"
REPO="/home/cloud-user/workspace/ocm-addon-contrib"

# Send a line to flower pane as a shell comment (no echo needed)
f() { tmux send-keys -t "$TARGET" "# $*" Enter; sleep 0.15; }
fs() { tmux send-keys -t "$TARGET" "" Enter; sleep 0.1; }

# Print in current session only
c() { echo "  $*"; }
s() { echo ""; }

note() {
  s
  c "# $*"
  fs
  f "  >> $*"
  fs
}

banner_ctrl() {
  s
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $*"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  [Enter to start this section]"
}

banner_flower() {
  fs
  f "================================================================"
  f " $*"
  f "================================================================"
  fs
}

run() {
  s
  c "next >> $*"
  c "[Enter to run]"
  f "  $*"
  fs
}

# ─── Startup ─────────────────────────────────────────────────
s
c "Sending preview to flower:0 ..."
tmux send-keys -t "$TARGET" q 2>/dev/null   # exit copy-mode if active
sleep 0.3
tmux send-keys -t "$TARGET" "cd $REPO/flower-addon" Enter
sleep 1
s

# ─── Agenda ──────────────────────────────────────────────────
f "=========================================================================="
f "  Flower Addon on Open Cluster Management -- Demo Agenda"
f "=========================================================================="
f ""
f "  1. OCM Multi-Cluster Setup"
f "     Bootstrap hub + cluster1 + cluster2, join and accept managed clusters"
f ""
f "  2. Flower Addon -- SuperNode Definition"
f "     Define addon via AddOnTemplate, ClusterManagementAddOn, ManagedClusterAddOn"
f ""
f "  3. Flower Addon -- Resource-based Scheduling"
f "     Schedule the flower-addon onto clusters based on GPU resource labels"
f ""
f "  4. Flower Addon -- Application Distribution"
f "     Distribute ClientApp across clusters via MWRS + data-aware Placement"
f ""
f "=========================================================================="
s
c "[Enter to begin]"

# ─── Section 1 ───────────────────────────────────────────────
banner_ctrl "Section 1/4  |  OCM Multi-Cluster Setup"
banner_flower "Section 1/4  |  OCM Multi-Cluster Setup"

run "kind create cluster --name hub --config .../hub-kind.yaml"
run "kind create cluster --name cluster1 & kind create cluster --name cluster2 & wait"
run "clusteradm init --wait"
run "clusteradm join cluster1  (via token, --kubeconfig \$KUBECONFIG_C1)"
run "clusteradm join cluster2  (via token, --kubeconfig \$KUBECONFIG_C2)"
run "clusteradm accept --clusters cluster1,cluster2 --wait"
run "kubectl get managedclusters"

# ─── Section 2 ───────────────────────────────────────────────
banner_ctrl "Section 2/4  |  Flower Addon -- SuperNode Definition"
banner_flower "Section 2/4  |  Flower Addon -- SuperNode Definition"

run "echo \"Hub IP: \$HUB_IP\""
run "helm install flower-addon ./charts/flower-addon --set deploymentConfig.superlinkAddress=\$HUB_IP --set addon.installStrategy=Placements --set placement.gpu.enabled=true --set placement.gpu.clusterSet=global"
run "kubectl wait --for=condition=available deployment/superlink -n flower-system --timeout=90s"
run "kubectl get pods -n flower-system"
note "AddOnTemplate -- defines how SuperNode is installed on each Managed Cluster"
run "kubectl get addontemplate flower-addon -oyaml"
note "ClusterManagementAddOn -- global Addon policy, installStrategy=Placements"
run "kubectl get clustermanagementaddon flower-addon -oyaml"

# ─── Section 3 ───────────────────────────────────────────────
banner_ctrl "Section 3/4  |  Flower Addon -- Resource-based Scheduling"
banner_flower "Section 3/4  |  Flower Addon -- Resource-based Scheduling"

note "GPU Placement selects only clusters labeled gpu=true"
run "kubectl get placement flower-addon-gpu-placement -n open-cluster-management -oyaml"
note "No cluster has gpu=true yet -- PlacementDecision selects nobody"
run "kubectl get placementdecisions -n open-cluster-management"
run "kubectl label managedcluster cluster2 gpu=true"
run "kubectl get placementdecisions -n open-cluster-management"
note "cluster2 selected -- SuperNode installing... watch the bottom-right pane"
run "kubectl get managedclusteraddons -A"
note "Scale out: label cluster1 gpu=true -- SuperNode auto-installed there too"
run "kubectl label managedcluster cluster1 gpu=true"
run "kubectl get managedclusteraddons -A"
note "ManagedClusterAddOn -- per-cluster addon status and linked config"
run "kubectl get managedclusteraddon flower-addon -n cluster1 -oyaml"

# ─── Section 4 ───────────────────────────────────────────────
banner_ctrl "Section 4/4  |  Flower Addon -- Application Distribution"
banner_flower "Section 4/4  |  Flower Addon -- Application Distribution"

run "kubectl label managedcluster cluster1 data=cifar10"
note "Placement: addon=Available AND data=cifar10  (cluster2 has no data label yet)"
run "kubectl apply -f .../clientapp-with-data.yaml"
note "ManifestWorkReplicaSet -- defines what to deploy and where via placementRefs"
run "kubectl get manifestworkreplicaset flower-superexec-clientapp -n flower-system -oyaml"
note "ManifestWork auto-created for cluster1 -- the per-cluster work package"
run "kubectl get manifestworks -A"
note "Scale out: label cluster2 with data=cifar10 -- ClientApp auto-distributed"
run "kubectl label managedcluster cluster2 data=cifar10"
run "kubectl get placementdecisions -n flower-system"
run "kubectl get manifestworks -A"

# ─── Done ────────────────────────────────────────────────────
banner_ctrl "Demo Complete"
f ""
f "  SuperNode  -- infrastructure layer : scheduled by gpu label"
f "  ClientApp  -- application layer    : scheduled by addon=Available + data label"
f "  MWRS drives automatic distribution as labels change"
f ""
s
c "Demo finished."
