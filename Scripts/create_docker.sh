#!/bin/bash

docker_network="drones_network"
network_prefix=""

create_network(){
    local subnet="$1"
    shift

    if ! docker network ls --format '{{.Name}}' | grep -q "^${docker_network}$"; then
        echo "Creating docker network: ${docker_network}"
        docker network create --subnet "$subnet" "${docker_network}"
    else
        echo "Docker network ${docker_network} already exists"
    fi

    network_prefix=$(echo "$subnet" | cut -d'.' -f1-3)
}

create_docker(){
    local id="$1"
    shift

    local ip="${network_prefix}.${id}"

    if ! docker run --name "instance_$id" --network "$docker_network" --ip "$ip" -d px4-gazebo:latest bash; then
        echo "Failed to create docker instance $id"
        return 1
    else
        echo "Docker instance $id created with IP $ip"
    fis

}

main() {
  local instances="$1"
  shift

  echo "Running docker instance script"
  echo "Number of instances: $instances"

  for [[ $# -gt 0 ]]; do
    case "$1" in 
        -subnet)
            local subnet="$2"
            shift 2
            ;;
    esac
  done

  create_network "$subnet"

  for i in $(seq 1 to $instances); do
    if ! create_docker "$i"; then 
        echo "Failed to create docker instance $i"
        exit 1
    fi
  done

}

main "$@"
