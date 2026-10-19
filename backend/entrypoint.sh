#!/bin/sh
set -e

# 1. Run migrations so database schema is always up to date
echo "Applying database migrations..."
alembic upgrade head

# 2. Start the web server
echo "Starting Uvicorn server..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
