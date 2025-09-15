FROM node:20-alpine

# Install system dependencies
RUN apk add --no-cache git curl tini && \
    npm install -g @anthropic-ai/claude-code && \
    npm cache clean --force

# Use built-in node user for security
USER node
WORKDIR /workspace

# Create Claude data directory
RUN mkdir -p /home/node/.claude

# Use tini as init system
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["claude", "--dangerously-skip-permissions"]