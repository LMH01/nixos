ARG DEBIAN_BASE=debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2
FROM ${DEBIAN_BASE}

ARG HERMES_UID=10000
ARG HERMES_GID=10000

LABEL org.lmh01.hermes-agent.preserve="true"

ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/home/hermes \
    PATH=/usr/local/bin:/home/hermes/.local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      docker-cli \
      docker-compose \
      docker-buildx \
      git \
      gosu \
      less \
      openssh-client \
      sudo \
      tini \
      tmux \
      tzdata \
      xz-utils \
      build-essential \
      pkg-config \
      libatomic1 \
      libasound2t64 \
      libatk-bridge2.0-0t64 \
      libatk1.0-0t64 \
      libatspi2.0-0t64 \
      libcairo2 \
      libcups2t64 \
      libdbus-1-3 \
      libgbm1 \
      libglib2.0-0t64 \
      libnspr4 \
      libnss3 \
      libpango-1.0-0 \
      libx11-6 \
      libxcb1 \
      libxcomposite1 \
      libxdamage1 \
      libxext6 \
      libxfixes3 \
      libxkbcommon0 \
      libxrandr2 \
      python3 \
      python3-dev \
      python3-venv \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd --gid "${HERMES_GID}" hermes \
 && useradd --uid "${HERMES_UID}" --gid hermes --create-home --shell /bin/bash hermes \
 && printf 'hermes ALL=(ALL:ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/hermes \
 && chmod 0440 /etc/sudoers.d/hermes \
 && printf 'export PATH="/usr/local/bin:$HOME/.local/bin:$PATH"\n' > /etc/profile.d/hermes-path.sh \
 && mkdir -p /opt/hermes \
 && chown hermes:hermes /opt/hermes

COPY entrypoint.sh /usr/local/sbin/hermes-container-entrypoint
RUN chmod 0755 /usr/local/sbin/hermes-container-entrypoint

ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/sbin/hermes-container-entrypoint"]
CMD ["gateway"]
