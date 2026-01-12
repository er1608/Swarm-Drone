FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN apt-get update && apt-get install -y \
    sudo \
    apt-utils \
    git \
    nano \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    ninja-build \
    build-essential \
    software-properties-common \
    lsb-release \
    gnupg \
    curl \
    wget \
    vim \
    && rm -rf /var/lib/apt/lists/*

ENV PX4_DIR=root/Khoa
WORKDIR $PX4_DIR

RUN git clone https://github.com/er1608/Swarm-Drone.git \
    --recursive \
    --progress \
    --verbose

RUN git clone https://github.com/PX4/PX4-Autopilot.git \
    --recursive \
    --progress \
    --verbose
RUN bash ./PX4-Autopilot/Tools/setup/ubuntu.sh

COPY /Scripts/autostart.sh autostart.sh
RUN chmod +x autostart.sh
RUN sed -i 's/\r$//' autostart.sh

CMD ["./autostart.sh"]
