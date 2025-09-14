#!/bin/bash
set -e

# Ensure data and logs directories exist and have correct permissions
mkdir -p /app/data /app/logs
chown -R discovery:discovery /app/data /app/logs

# Switch to discovery user and run the application
exec gosu discovery "$@"
