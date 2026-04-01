#!/bin/bash
# ============================================================
# Flower Addon Demo  --  Interactive mode
#
# Run from any session (e.g. Test:0).
# Sends commands to flower:0 (the recording window).
# ============================================================

REPO="/home/cloud-user/workspace/ocm-addon-contrib"
DEMO_DIR="/home/cloud-user/workspace/flower-addon-demo/flower-addon/hack/demo"
CTX_DIR="$HOME/flower-demo"

HUB="flower:0.0"
C1="flower:0.1"
C2="flower:0.2"

KUBECONFIG_HUB=~/.kube/hub
KUBECONFIG_C1=~/.kube/cluster1
KUBECONFIG_C2=~/.kube/cluster2

SEP="# ================================================================================"

# ─── Helpers ─────────────────────────────────────────────────

# Show next command, type into hub pane, wait for operator Enter to execute
run() {
  hub_silent ""
  echo ""
  echo "  >> $*"
  tmux send-keys -t "$HUB" "$*"
  read -rs
  tmux send-keys -t "$HUB" Enter
  sleep 0.3
}

# Interactive command into cluster1 pane
run_c1() {
  echo "  [cluster1] >> $*"
  tmux send-keys -t "$C1" "$*"
  read -rs
  tmux send-keys -t "$C1" Enter
  sleep 0.3
}

# Interactive command into cluster2 pane
run_c2() {
  echo "  [cluster2] >> $*"
  tmux send-keys -t "$C2" "$*"
  read -rs
  tmux send-keys -t "$C2" Enter
  sleep 0.3
}

hub_silent() { tmux send-keys -t "$HUB" "$*" Enter; sleep 0.3; }
c1()         { tmux send-keys -t "$C1"  "$*" Enter; sleep 0.3; }
c2()         { tmux send-keys -t "$C2"  "$*" Enter; sleep 0.3; }

# Multi-line command: each arg is one line, displayed with \ continuation in hub pane
run_ml() {
  local -a lines=("$@")
  local i last=$(( ${#lines[@]} - 1 ))
  hub_silent ""
  echo ""
  # Print hint in control terminal
  echo "  >> ${lines[0]} \\"
  for (( i=1; i<last; i++ )); do printf "       %s \\\\\n" "${lines[$i]}"; done
  echo "       ${lines[$last]}"
  # Type lines into hub pane first
  for (( i=0; i<last; i++ )); do
    tmux send-keys -t "$HUB" "${lines[$i]} \\"
    tmux send-keys -t "$HUB" Enter
    sleep 0.2
  done
  tmux send-keys -t "$HUB" "${lines[$last]}"
  read -rs
  tmux send-keys -t "$HUB" Enter
  sleep 0.3
}

# Wait for operator Enter (used after long-running commands complete)
wait_enter() { echo ""; echo "  [Enter to continue]"; read -rs; echo ""; }

# Print blank lines in control terminal to visually separate major steps
space() { echo ""; echo ""; }

banner() {
  hub_silent ""
  hub_silent ""
  hub_silent "$SEP"
  hub_silent "# $1"
  hub_silent "$SEP"
  echo ""
  echo "  ── $1"
  read -rs
  tmux select-pane -t "$HUB" -T "hub | $1"
  tmux select-pane -t "$C1"  -T "cluster1 | Managed Cluster" 2>/dev/null || true
  tmux select-pane -t "$C2"  -T "cluster2 | Managed Cluster" 2>/dev/null || true
  tmux select-pane -t "$HUB"
  sleep 0.2
}

note() { echo "  # $1"; }

# Print a section recap in both hub pane and control terminal, then wait for Enter
recap() {
  hub_silent ""
  hub_silent "# $1"
  echo ""
  echo "  # $1"
  echo "  [Enter to continue to next section]"
  read -rs
  echo ""
}

# Split into 3 panes and set up cluster1/cluster2 contexts
split_panes() {
  C1=$(tmux split-window -t "$HUB" -v -p 35 -P -F "#{pane_id}")
  sleep 0.3
  C2=$(tmux split-window -t "$C1" -h -P -F "#{pane_id}")
  sleep 0.3

  tmux send-keys -t "$C1" "zle_highlight=(default:none)" Enter; sleep 0.3
  tmux send-keys -t "$C1" "cd $CTX_DIR/cluster1 && clear" Enter; sleep 0.3
  tmux send-keys -t "$C1" "export KUBECONFIG=$KUBECONFIG_C1" Enter; sleep 0.3

  tmux send-keys -t "$C2" "zle_highlight=(default:none)" Enter; sleep 0.3
  tmux send-keys -t "$C2" "cd $CTX_DIR/cluster2 && clear" Enter; sleep 0.3
  tmux send-keys -t "$C2" "export KUBECONFIG=$KUBECONFIG_C2" Enter; sleep 0.3

  tmux select-pane -t "$HUB" -T "hub | OCM Control Plane"
  tmux select-pane -t "$C1"  -T "cluster1 | Managed Cluster"
  tmux select-pane -t "$C2"  -T "cluster2 | Managed Cluster"
  tmux select-pane -t "$HUB"
  sleep 0.2
}

# ─── Hub-only setup ──────────────────────────────────────────

# Hub pane -- run all setup before clear, then show only KUBECONFIG export
tmux send-keys -t "$HUB" "export REPO=$REPO DEMO_DIR=$DEMO_DIR" Enter; sleep 0.3
tmux send-keys -t "$HUB" "export KUBECONFIG_HUB=$KUBECONFIG_HUB KUBECONFIG_C1=$KUBECONFIG_C1 KUBECONFIG_C2=$KUBECONFIG_C2" Enter; sleep 0.3
tmux send-keys -t "$HUB" "zle_highlight=(default:none)" Enter; sleep 0.3
tmux send-keys -t "$HUB" "cd $CTX_DIR/hub && clear" Enter; sleep 0.3
tmux send-keys -t "$HUB" "export KUBECONFIG=$KUBECONFIG_HUB" Enter; sleep 0.3
tmux send-keys -t "$HUB" "" Enter; sleep 0.3
tmux select-pane -t "$HUB" -T "hub | OCM Control Plane"

# ─── Agenda ──────────────────────────────────────────────────

hub_silent "$SEP"
hub_silent "# Scaling Enterprise Federated AI with Flower and Open Cluster Management"
hub_silent "$SEP"
hub_silent "#"
hub_silent "#   1. Open Cluster Management Setup"
hub_silent "#"
hub_silent "#   2. Define SuperNode with OCM Addon"
hub_silent "#"
hub_silent "#   3. Schedule SuperNode with OCM Placement"
hub_silent "#"
hub_silent "#   4. Application Distribution via OCM Work API"
hub_silent "#"
read -rs

# ─── Section 1: Open Cluster Management Setup ────────────────

banner "Section 1/4  |  Open Cluster Management Setup"
split_panes

note "Creating 3 clusters in parallel -- hub (top), cluster1 (bottom-left), cluster2 (bottom-right)"
c1 "kind create cluster --name cluster1"
c2 "kind create cluster --name cluster2"
run "kind create cluster --name hub --config $DEMO_DIR/hub-kind.yaml"
# Wait for all 3 clusters to finish, then Enter to continue
wait_enter

# Populate kubeconfig files directly (invisible to panes)
kind get kubeconfig --name hub      > $KUBECONFIG_HUB
kind get kubeconfig --name cluster1 > $KUBECONFIG_C1
kind get kubeconfig --name cluster2 > $KUBECONFIG_C2

space
note "Initialize OCM hub"
run "clusteradm init --feature-gates=ManifestWorkReplicaSet=true --wait"
wait_enter

# Capture join command in this session
JOINCMD=$(KUBECONFIG=$KUBECONFIG_HUB clusteradm get token 2>/dev/null | grep clusteradm)
JOIN_C1="${JOINCMD//<cluster_name>/cluster1} --force-internal-endpoint-lookup --wait"
JOIN_C2="${JOINCMD//<cluster_name>/cluster2} --force-internal-endpoint-lookup --wait"

space
note "Join cluster1 to hub"
run_c1 "$JOIN_C1"
wait_enter

note "Join cluster2 to hub"
run_c2 "$JOIN_C2"
wait_enter

space
note "Accept both clusters on hub"
run "clusteradm accept --clusters cluster1,cluster2 --wait"
wait_enter

space
note "Hub -- OCM control plane components"
run "kubectl get pods -n open-cluster-management"
run "kubectl get managedclusters"

note "Klusterlet -- OCM agent on each managed cluster, connects back to hub"
c1 "kubectl get pods -n open-cluster-management-agent"
c2 "kubectl get pods -n open-cluster-management-agent"
wait_enter

recap "Hub + 2 managed clusters up, Klusterlet agents connected to hub"

# ─── Section 2: Define SuperNode with OCM Addon ──────────────

banner "Section 2/4  |  Define SuperNode with OCM Addon"

# Capture hub IP in test session -- invisible to panes
HUB_IP=$(KUBECONFIG=$KUBECONFIG_HUB kubectl get nodes \
  -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)

# Configure flwr CLI to connect to SuperLink with TLS (invisible)
mkdir -p ~/.flwr
cat > ~/.flwr/config.toml <<EOF
[superlink]
default = "ocm-deployment"

[superlink.ocm-deployment]
address = "${HUB_IP}:30093"
root-certificates = "${CTX_DIR}/hub/ca.crt"
EOF

run "export HUB_IP=\$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type==\"InternalIP\")].address}') && echo HUB_IP=\$HUB_IP"

space
note "Generate TLS certificates for SuperLink"
run "$REPO/flower-addon/hack/generate-certs.sh --hub-ip \$HUB_IP > /dev/null 2>&1 && echo 'Created: flower-tls-ca, flower-superlink-tls'"

space
note "Install flower-addon helm chart -- deploys SuperLink on hub + registers addon"
# Allow Helm to adopt the flower-system namespace created by generate-certs.sh (invisible)
KUBECONFIG=$KUBECONFIG_HUB kubectl label namespace flower-system app.kubernetes.io/managed-by=Helm --overwrite > /dev/null 2>&1
KUBECONFIG=$KUBECONFIG_HUB kubectl annotate namespace flower-system meta.helm.sh/release-name=flower-addon meta.helm.sh/release-namespace=default --overwrite > /dev/null 2>&1
run_ml \
  "helm install flower-addon $REPO/flower-addon/charts/flower-addon" \
  "  --set deploymentConfig.superlinkAddress=$HUB_IP" \
  "  --set tls.enabled=true" \
  "  --set addon.installStrategy=Placements" \
  "  --set placement.gpu.enabled=true" \
  "  --set placement.gpu.clusterSet=global"
wait_enter

run "kubectl wait --for=condition=available deployment/superlink -n flower-system --timeout=90s"
wait_enter

# Extract CA cert for flwr CLI (invisible)
KUBECONFIG=$KUBECONFIG_HUB kubectl get secret flower-tls-ca -n flower-system \
  -o jsonpath='{.data.ca\.crt}' | base64 -d > $CTX_DIR/hub/ca.crt
run "kubectl get pods -n flower-system"

space
note "AddonTemplate -- defines how SuperNode agent is installed on each Managed Cluster"
run "kubectl get addontemplate flower-addon -oyaml | bat -l yaml --paging=never --theme="GitHub""
wait_enter

space
note "ClusterManagementAddon -- registers addon globally; installStrategy=Placements (automatic via Placement)"
run "kubectl get clustermanagementaddon flower-addon -oyaml | bat -l yaml --paging=never --theme="GitHub""
wait_enter

recap "SuperLink running on hub, AddonTemplate + ClusterManagementAddon registered"

# ─── Section 3: Schedule SuperNode with OCM Placement ────────

banner "Section 3/4  |  Schedule SuperNode with OCM Placement"

run "kubectl get placement flower-addon-gpu-placement -n open-cluster-management -oyaml | bat -l yaml --paging=never --theme="GitHub""
wait_enter


c1 "watch kubectl get pods -n flower-addon"
c2 "watch kubectl get pods -n flower-addon"

space
run "kubectl label managedcluster cluster2 gpu=true"

note "cluster2 selected -- SuperNode installing... watch the bottom-right pane"
run "kubectl get managedclusteraddons -A"
wait_enter

space
note "Scale out: label cluster1 gpu=true -- SuperNode auto-installed there too"
run "kubectl label managedcluster cluster1 gpu=true"
run "kubectl get managedclusteraddons -A"
wait_enter

run "kubectl get managedclusteraddon flower-addon -n cluster1 -oyaml | bat -l yaml --paging=never --theme="GitHub""

space
note "Verify SuperNode is running on both clusters"
tmux send-keys -t "$C1" "C-c" ""; sleep 0.3
tmux send-keys -t "$C2" "C-c" ""; sleep 0.3
run_c1 "kubectl logs -n flower-addon -l app.kubernetes.io/component=supernode | head -10"
run_c2 "kubectl logs -n flower-addon -l app.kubernetes.io/component=supernode | head -10"

space
note "Verify SuperLink received connections from both SuperNodes"
run "kubectl logs -n flower-system deployment/superlink | head -20"
wait_enter

recap "SuperNode auto-installed on cluster1 + cluster2 via gpu=true label"

# ─── Section 4: Application Distribution via OCM Work API ────

banner "Section 4/4  |  Application Distribution via OCM Work API"

# Stop watch in cluster panes, switch to observing clientapp pod
tmux send-keys -t "$C1" "C-c" ""
tmux send-keys -t "$C2" "C-c" ""
sleep 0.3
c1 "watch kubectl get pods -n flower-addon"
c2 "watch kubectl get pods -n flower-addon"

# Deploy ServerApp on hub first
note "Deploy ServerApp on hub"
run "kubectl apply -f $DEMO_DIR/serverapp-hub.yaml"

space
# Show ClientApp Placement + ManifestWorkReplicaSet definition
run "bat -l yaml --paging=never --theme="GitHub" $DEMO_DIR/clientapp-with-data.yaml"
wait_enter

# Deploy ClientApp on managed clusters
run "kubectl apply -f $DEMO_DIR/clientapp-with-data.yaml"
run "kubectl label managedcluster cluster1 data=cifar10"

space
note "Scale out: label cluster2 with data=cifar10 -- ClientApp auto-distributed"
run "kubectl label managedcluster cluster2 data=cifar10"

space
run "kubectl get manifestworks -A"
run "kubectl get manifestworkreplicaset flower-superexec-clientapp -n flower-system -oyaml | bat -l yaml --paging=never --theme="GitHub""
wait_enter

# Wait for ClientApp pods to be ready, then check logs
tmux send-keys -t "$C1" "C-c" ""; sleep 0.3
tmux send-keys -t "$C2" "C-c" ""; sleep 0.3

space
note "Watch all pods until Running -- ServerApp on hub, ClientApp on cluster1 + cluster2"
run "watch kubectl get pods -n flower-system -l app.kubernetes.io/component=superexec-serverapp"
c1 "watch kubectl get pods -n flower-addon"
c2 "watch kubectl get pods -n flower-addon"
wait_enter

tmux send-keys -t "$HUB" "C-c" ""; sleep 0.3
tmux send-keys -t "$C1" "C-c" ""; sleep 0.3
tmux send-keys -t "$C2" "C-c" ""; sleep 0.3

space
note "Tail ClientApp logs on both clusters"
c1 "kubectl logs -n flower-addon -l app.kubernetes.io/component=superexec-clientapp -f"
c2 "kubectl logs -n flower-addon -l app.kubernetes.io/component=superexec-clientapp -f"

space
note "Submit FL training job from hub"
run "cd $REPO/flower-addon/cifar10 && flwr run . ocm-deployment --stream"

# Training complete -- stop all streaming logs
wait_enter
tmux send-keys -t "$HUB" "C-c" ""; sleep 0.3
tmux send-keys -t "$C1"  "C-c" ""; sleep 0.3
tmux send-keys -t "$C2"  "C-c" ""; sleep 0.3
hub_silent "cd $CTX_DIR/hub"

banner "Demo Complete"
hub_silent "#"
hub_silent "# 1. OCM hub + 2 managed clusters bootstrapped"
hub_silent "#"
hub_silent "# 2. SuperNode defined via AddonTemplate, scheduled by GPU label via Placement"
hub_silent "#"
hub_silent "# 3. ClientApp distributed to all selected clusters via ManifestWorkReplicaSet"
hub_silent "#"
hub_silent "# 4. Federated learning training running across cluster1 + cluster2"
hub_silent "#"
