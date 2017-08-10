#!/bin/sh

set -e

if [ "$#" != 1 ]; then
    echo "Expected one argument"
    exit 1
fi

CLUSTER_CONF_DIR=$(pwd)/cluster-config

# Variables for master and minion nodes.
MINIONS_SIZE=${MINIONS_SIZE:-3}
DASHBOARD_CPUS=${DASHBOARD_CPUS:-1}
MASTER_CPUS=${MASTER_CPUS:-1}
MINION_CPUS=${MINION_CPUS:-1}
DASHBOARD_MEMORY=${DASHBOARD_MEMORY:-2048}
MASTER_MEMORY=${MASTER_MEMORY:-2048}
MINION_MEMORY=${MINION_MEMORY:-2048}
FLAVOUR=${FLAVOUR:-"caasp"}
STAGING=${STAGING:-"release"}
DASHBOARD_HOST=${DASHBOARD_HOST:-}
SKIP_DASHBOARD=${SKIP_DASHBOARD:-"false"}
SKIP_ORCHESTRATION=${SKIP_ORCHESTRATION:-"false"}
DOCKER_REGISTRY=${DOCKER_REGISTRY:-}

## Image Updates
# Log warning if there is a new image
CHECK_LATEST_IMAGE=${CHECK_LATEST_IMAGE:-"true"}
# Prompt to download new image
PROMPT_LATEST_IMAGE=${PROMPT_LATEST_IMAGE:-"false"}
# Always download latest image if available
LATEST_IMAGE=${LATEST_IMAGE:-"true"}
# Always download image, no matter what is stored locally
FORCE_IMAGE_REFRESH=${FORCE_IMAGE_REFRESH:-"false"}
# Set additional wget flags (e.g. verbosity)
WGET_FLAGS=${WGET_FLAGS:-""}

[ "$SKIP_DASHBOARD" != "false" ] && SKIP_DASHBOARD="true"
[ "$SKIP_ORCHESTRATION" != "false" ] && SKIP_ORCHESTRATION="true"
[ "$CHECK_LATEST_IMAGE" != "false" ] && CHECK_LATEST_IMAGE="true"
[ "$PROMPT_LATEST_IMAGE" != "false" ] && PROMPT_LATEST_IMAGE="true"
[ "$LATEST_IMAGE" != "false" ] && LATEST_IMAGE="true"
[ "$FORCE_IMAGE_REFRESH" != "false" ] && FORCE_IMAGE_REFRESH="true"

SSH_DEFAULT_ARGS="-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"

# Fix ssh directory/keys permissions (git ignores some permission changes)
chmod 700 ssh
chmod 644 ssh/id_docker.pub
chmod 600 ssh/id_docker

# If PREFIX is set we use that as a prefix else if the project is like
# "k8s-terraform-stable", then the prefix is `stable`.
# Otherwise, we stick to the current username.
prefix="$(echo "${PWD##*/}" | awk -F- '{ print $3; }')"
if [ ! -z ${PREFIX+x} ]; then
  prefix="$PREFIX"
elif [ "$prefix" = "" ]; then
  prefix="$USER"
fi

# Select the correct CaaSP base URL
if [ "$FLAVOUR" == "caasp" ]; then
    if [ "$STAGING" == "release" ]; then
        CAASP_IMAGE_BASE_URL="http://download.suse.de/ibs/SUSE:/SLE-12-SP2:/Update:/Products:/CASP10/images/"
    elif [ "$STAGING" == "staging_a" ]; then
        CAASP_IMAGE_BASE_URL="http://download.suse.de/ibs/SUSE:/SLE-12-SP2:/Update:/Products:/CASP10:/Staging:/A/images/"
    elif [ "$STAGING" == "staging_b" ]; then
        CAASP_IMAGE_BASE_URL="http://download.suse.de/ibs/SUSE:/SLE-12-SP2:/Update:/Products:/CASP10:/Staging:/B/images/"
    elif [ "$STAGING" == "devel" ]; then
        CAASP_IMAGE_BASE_URL="http://download.suse.de/ibs/Devel:/CASP:/1.0:/ControllerNode/images/"
    else
        echo "[+] ERROR: Unknown CaaSP image: ${STAGING}"
        exit 1
    fi
fi

if [ "$1" == "apply" ]; then
    # Get the salt directory, which is a separate repo.
    SALT_PATH="${SALT_PATH:-$PWD/../salt}"
    if ! [ -d "$SALT_PATH" ]; then
        echo "[+] Downloading kubic-project/salt to '$SALT_PATH'"
        git clone https://github.com/kubic-project/salt "$SALT_PATH"
    else
        echo "[*] Already downloaded kubic-project/salt at '$SALT_PATH'"
    fi

    if [ "$FLAVOUR" == "opensuse" ]; then
        IMAGE_PATH="${IMAGE_PATH:-$PWD/Base-openSUSE-Leap-42.2.x86_64-cloud_ext4.qcow2}"
    elif [ "$FLAVOUR" == "caasp" ]; then
        IMAGE_PATH="${IMAGE_PATH:-$PWD/SUSE-CaaS-Platform-1.0-KVM-and-Xen.${STAGING}.x86_64.qcow2}"
    fi

    NEED_UPDATE=false

    if $CHECK_LATEST_IMAGE; then

        # Get the SHA of the latest file
        if [ "$FLAVOUR" == "opensuse" ]; then
            echo "[+] Downloading openSUSE qcow2 VM image sha to '$IMAGE_PATH.sha256.remote'"
            wget $WGET_FLAGS -O "$IMAGE_PATH.sha256.remote" -N "http://download.opensuse.org/repositories/Virtualization:/containers:/images:/KVM:/Leap:/42.2/images/Base-openSUSE-Leap-42.2.x86_64-cloud_ext4.qcow2.sha256"
        elif [ "$FLAVOUR" == "caasp" ]; then
            echo "[+] Downloading SUSE CaaSP qcow2 VM image sha to '$IMAGE_PATH.sha256.remote'"
            wget $WGET_FLAGS -r -l1 -nd -N $CAASP_IMAGE_BASE_URL -P /tmp/CaaSP -A "SUSE-CaaS-Platform-1.0-KVM-and-Xen.x86_64-*qcow2.sha256"
            find /tmp/CaaSP -name "SUSE-CaaS-Platform-1.0-KVM-and-Xen.x86_64*qcow2.sha256" -prune -exec mv {} $IMAGE_PATH.sha256.remote ';'
        fi

        LOCAL_SHA="$IMAGE_PATH.sha256"
        REMOTE_SHA="$IMAGE_PATH.sha256.remote"

        # Compare the current local SHA to the remote one
        cmp --silent $LOCAL_SHA $REMOTE_SHA && NEED_UPDATE=false || NEED_UPDATE=true

    fi

    if $PROMPT_LATEST_IMAGE && $NEED_UPDATE; then

        if which notify-send >/dev/null; then
            notify-send "There is a new $FLAVOUR image available - should we update?"
        fi
        echo "[*] There is a new $FLAVOUR image available - should we update?"
        read -e -i "y" -p "Do you want to update image? [Y/n] " yn
        case $yn in
            [Yy]* ) NEED_UPDATE=true;;
            [Nn]* ) NEED_UPDATE=false;;
            * ) echo "Please answer yes (y) or no (n).";;
        esac

    elif $NEED_UPDATE && $CHECK_LATEST_IMAGE && [[ "$LATEST_IMAGE" == "false" ]]; then
        if which notify-send >/dev/null; then
            notify-send "There is a new $FLAVOUR image available."
        fi
        echo "[*] There is a new $FLAVOUR image available."
        NEED_UPDATE=false
    fi

    if ! [ -f "$IMAGE_PATH" ] || [ "$LATEST_IMAGE" == "true" ]; then
        if $NEED_UPDATE || $FORCE_IMAGE_REFRESH; then 
            if [ "$FLAVOUR" == "opensuse" ]; then
                echo "[+] Downloading openSUSE qcow2 VM image to '$IMAGE_PATH'"
                wget $WGET_FLAGS -O "$IMAGE_PATH" -N "http://download.opensuse.org/repositories/Virtualization:/containers:/images:/KVM:/Leap:/42.2/images/Base-openSUSE-Leap-42.2.x86_64-cloud_ext4.qcow2"
                wget $WGET_FLAGS -O "$IMAGE_PATH.sha256" -N "http://download.opensuse.org/repositories/Virtualization:/containers:/images:/KVM:/Leap:/42.2/images/Base-openSUSE-Leap-42.2.x86_64-cloud_ext4.qcow2.sha256"
            elif [ "$FLAVOUR" == "caasp" ]; then
                echo "[+] Downloading SUSE CaaSP qcow2 VM image to '$IMAGE_PATH'"
                wget $WGET_FLAGS -r -l1 -nd -N $CAASP_IMAGE_BASE_URL -P /tmp/CaaSP -A "SUSE-CaaS-Platform-1.0-KVM-and-Xen.x86_64-*qcow2"
                wget $WGET_FLAGS -r -l1 -nd -N $CAASP_IMAGE_BASE_URL -P /tmp/CaaSP -A "SUSE-CaaS-Platform-1.0-KVM-and-Xen.x86_64-*qcow2.sha256"
                find /tmp/CaaSP -name "SUSE-CaaS-Platform-1.0-KVM-and-Xen.x86_64*qcow2" -prune -exec mv {} $IMAGE_PATH ';'
                find /tmp/CaaSP -name "SUSE-CaaS-Platform-1.0-KVM-and-Xen.x86_64*qcow2.sha256" -prune -exec mv {} $IMAGE_PATH.sha256 ';'
            fi
        fi
    else
        if [ "$FLAVOUR" == "opensuse" ]; then
            echo "[*] Already downloaded openSUSE qcow2 VM image to '$IMAGE_PATH'"
        elif [ "$FLAVOUR" == "caasp" ]; then
            echo "[*] Already downloaded SUSE CaaSP qcow2 VM image to '$IMAGE_PATH'"
        fi
    fi

    # Make sure that libvirt is started.
    # While this probably shouldn't be in this script, meh.
    sudo systemctl start libvirtd.service virtlogd.socket virtlockd.socket || :
fi

# Select the profile file depending on the flavour.
if [ "$FLAVOUR" == "caasp" ]; then
    profile="libvirt-caasp.profile"
else
    profile="libvirt-obs.profile"
fi

if [ "$SKIP_DASHBOARD" != "false" ] && [ -z $DASHBOARD_HOST ]; then
    default_interface=$(awk '$2 == 00000000 { print $1 }' /proc/net/route)
    DASHBOARD_HOST=$(ip addr show $default_interface | awk '$1 == "inet" {print $2}' | cut -f1 -d/)
    echo "Defaulting DASHBOARD_HOST to $DASHBOARD_HOST"
fi

[ -n "$TF_DEBUG" ] && export TF_LOG=debug
[ -n "$FORCE" ] && force="--force"
[ -n "$NO_COLOR" ] && no_color="--no-color"

# Go kubes go!
./k8s-setup \
    --verbose \
    $force \
    $no_color \
    -F $profile \
    -V salt_dir="$SALT_PATH" \
    -V cluster_prefix=$prefix \
    -V skip_dashboard=$SKIP_DASHBOARD \
    -V kube_minions_size=$MINIONS_SIZE \
    -V dashboard_cpus=$DASHBOARD_CPUS \
    -V dashboard_memory=$DASHBOARD_MEMORY \
    -V master_cpus=$MASTER_CPUS \
    -V master_memory=$MASTER_MEMORY \
    -V minion_cpus=$MINION_CPUS \
    -V minion_memory=$MINION_MEMORY \
    -V volume_source="$IMAGE_PATH" \
    -V dashboard_host=$DASHBOARD_HOST \
    -V skip_role_assignments=$SKIP_ORCHESTRATION \
    -V docker_reg=$DOCKER_REGISTRY \
    $1

if [ "$1" != "apply" ]; then
    exit $?
fi
if command -v jq; then
    echo "Generating environment.json file"
    environment=$(cat terraform.tfstate | \
        jq ".modules[].resources[] "`
            `"| select(.type==\"libvirt_domain\") | .primary | .attributes | "`
                `"{fqdn: .metadata | split(\",\") | .[0], "`
                `"ipv4: .[\"network_interface.0.addresses.0\"],"`
                `"addresses: {publicIpv4: .[\"network_interface.0.addresses.0\"], privateIpv4: .[\"network_interface.0.addresses.0\"]},"`
                `"id: .metadata | split(\",\") | .[1] | tonumber,"`
                `"role: (if (.metadata | split(\",\") | .[1] | tonumber) == 0 then \"master\" else \"worker\" end)}" \
            | jq -s . | jq "{minions: .}")

    for node in $(echo "$environment" | jq -r '.minions[] | select(.["minion_id"]? == null) | [.ipv4] | join(" ")'); do
        machine_id=$(ssh root@$node -i ssh/id_docker  -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no cat /etc/machine-id)
        environment=$(echo "$environment" | jq ".minions | map(if (.ipv4 == \"$node\") then . + {\"minionID\": \"$machine_id\"} else . end) | {minions: .}")
    done
    environment=$(echo "$environment" | jq " . + {dashboardHost: \"$DASHBOARD_HOST\", kubernetesHost: .minions[] | select(.role==\"master\") | .ipv4}")
    environment=$(echo "$environment" | jq " . + {sshKey: \"`pwd`/ssh/id_docker\", sshUser: \"root\"}")
    echo "$environment" | tee environment.json
else
    echo "jq is not installed - please install jq to generate the environment.json file"
fi

if which notify-send >/dev/null; then
    notify-send "The infrastructure is up, running Salt!"
else
    echo "The infrastructure is up, running Salt!"
fi


if [ $SKIP_ORCHESTRATION == "false" ] && [ $SKIP_DASHBOARD == "false" ]; then
    ssh -i ssh/id_docker \
        $SSH_DEFAULT_ARGS \
        root@`terraform output ip_dashboard` \
        bash /tmp/provision/admin/provision.sh --finish

    mkdir -p "$CLUSTER_CONF_DIR"
    scp -i ssh/id_docker \
        $SSH_DEFAULT_ARGS \
        root@`terraform output ip_dashboard`:admin.tar "$CLUSTER_CONF_DIR/"

    tar xvpf $CLUSTER_CONF_DIR/admin.tar -C "$CLUSTER_CONF_DIR"

    echo "Everything is fine, enjoy your cluster!"

    if [ -z "$(which kubectl)" ]; then
        echo "Install the kubernetes-client package and then run " \
             "\"export KUBECONFIG=$CLUSTER_CONF_DIR/kubeconfig\" to use this cluster."
    else
        echo "Execute the following to use this cluster: export KUBECONFIG=$CLUSTER_CONF_DIR/kubeconfig"
    fi
else
    local_ip=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')
    echo "Cluster is up, but roles are unassigned and no orchestration was launched"
    echo "  Please, start the dashboard locally"
    echo "  You can now visit http://$local_ip:3000 and bootstrap the cluster with the dashboard"
fi
