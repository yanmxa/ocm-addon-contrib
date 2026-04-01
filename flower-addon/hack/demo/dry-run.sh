#!/bin/bash
# Dry-run: send all demo content to flower:0.0 as # comments (no execution)
# Run from any session to preview the full demo flow in the flower pane.

HUB="flower:0.0"
CTX_DIR="$HOME/flower-demo"
DEMO_DIR="/home/cloud-user/workspace/flower-addon-demo/flower-addon/hack/demo"
KUBECONFIG_HUB=~/.kube/hub
KUBECONFIG_C1=~/.kube/cluster1
KUBECONFIG_C2=~/.kube/cluster2

f()  { tmux send-keys -t "$HUB" "# $*" Enter; sleep 0.12; }
fl() { tmux send-keys -t "$HUB" ""      Enter; sleep 0.08; }  # blank line

banner() {
  fl
  f "================================================================"
  f " $*"
  f "================================================================"
  fl
}

note() {
  f "-- $*"
}

run() {
  f "  \$ $*"
}

# ─── Reset hub pane ──────────────────────────────────────────
tmux send-keys -t "$HUB" "cd $CTX_DIR/hub && clear" Enter
sleep 0.5
tmux send-keys -t "$HUB" "export KUBECONFIG=$KUBECONFIG_HUB" Enter
sleep 0.3

# ─── Agenda ──────────────────────────────────────────────────
f "=========================================================================="
f " Flower Addon on Open Cluster Management -- Demo Agenda"
f "=========================================================================="
f ""
f "   1. OCM Multi-Cluster Setup"
f "      Bootstrap hub + cluster1 + cluster2, join and accept managed clusters"
f ""
f "   2. Flower Addon -- SuperNode Definition"
f "      Define addon via AddOnTemplate, ClusterManagementAddOn"
f ""
f "   3. Flower Addon -- Resource-based Scheduling"
f "      Schedule SuperNode onto clusters based on GPU resource labels"
f ""
f "   4. Flower Addon -- Application Distribution"
f "      Distribute ClientApp across clusters via MWRS + data-aware Placement"
f ""
f "=========================================================================="

# ─── Section 1 ───────────────────────────────────────────────
banner "Section 1/4  |  OCM Multi-Cluster Setup"

run "kind create cluster --name hub --config $DEMO_DIR/hub-kind.yaml"
run "kind create cluster --name cluster1 & kind create cluster --name cluster2 & wait"
run "clusteradm init --wait"
run 'eval "${JOINCMD//<cluster_name>/cluster1} --force-internal-endpoint-lookup --wait --kubeconfig $KUBECONFIG_C1"'
run 'eval "${JOINCMD//<cluster_name>/cluster2} --force-internal-endpoint-lookup --wait --kubeconfig $KUBECONFIG_C2"'
run "clusteradm accept --clusters cluster1,cluster2 --wait"
run "kubectl get managedclusters"

# ─── Section 2 ───────────────────────────────────────────────
banner "Section 2/4  |  Flower Addon -- SuperNode Definition"

run 'echo "Hub IP: $HUB_IP"'
run "helm install flower-addon ./charts/flower-addon --set deploymentConfig.superlinkAddress=\$HUB_IP --set addon.installStrategy=Placements --set placement.gpu.enabled=true --set placement.gpu.clusterSet=global"
run "kubectl wait --for=condition=available deployment/superlink -n flower-system --timeout=90s"
run "kubectl get pods -n flower-system"
note "AddOnTemplate -- defines how SuperNode is installed on each Managed Cluster"
run "kubectl get addontemplate flower-addon -oyaml"
note "ClusterManagementAddOn -- global Addon policy, installStrategy=Placements"
run "kubectl get clustermanagementaddon flower-addon -oyaml"

# ─── Section 3 ───────────────────────────────────────────────
banner "Section 3/4  |  Flower Addon -- Resource-based Scheduling"

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
run "kubectl get managedclusteraddon flower-addon -n cluster1 -oyaml"

# ─── Section 4 ───────────────────────────────────────────────
banner "Section 4/4  |  Flower Addon -- Application Distribution"

run "kubectl label managedcluster cluster1 data=cifar10"
note "Placement: addon=Available AND data=cifar10  (cluster2 has no data label yet)"
run "kubectl apply -f $DEMO_DIR/clientapp-with-data.yaml"
run "kubectl get manifestworkreplicaset flower-superexec-clientapp -n flower-system -oyaml"
note "ManifestWork auto-created for cluster1 -- the per-cluster work package"
run "kubectl get manifestworks -A"
note "Scale out: label cluster2 with data=cifar10 -- ClientApp auto-distributed"
run "kubectl label managedcluster cluster2 data=cifar10"
run "kubectl get placementdecisions -n flower-system"
run "kubectl get manifestworks -A"

# ─── Done ────────────────────────────────────────────────────
banner "Demo Complete"
f "  SuperNode  -- infrastructure layer  : scheduled by gpu label"
f "  ClientApp  -- application layer     : scheduled by addon=Available + data label"
f "  ManifestWorkReplicaSet drives automatic distribution as labels change"
