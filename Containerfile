FROM debian:trixie-slim

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    rakudo \
    jq \
    yq \
    gawk \
    bats \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash claude

# Install claude code via official installer (as claude user)
USER claude
RUN curl -fsSL https://claude.ai/install.sh | bash

# Create workspace mount point
USER root
RUN mkdir -p /workspace && chown claude:claude /workspace
RUN mkdir -p /home/claude/.claude && chown -R claude:claude /home/claude/.claude

USER claude
ENV PATH="/home/claude/.local/bin:${PATH}"
WORKDIR /workspace

ENTRYPOINT ["claude", "--dangerously-skip-permissions"]
