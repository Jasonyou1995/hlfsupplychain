#!/bin/bash

# Supply Chain Platform - Quick Start
# Get up and running in under 3 minutes

set -e

echo "🚀 Supply Chain Platform - Quick Start"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "This will set up a development environment with:"
echo "• 2 organizations (Manufacturer, Supplier)"
echo "• 1 peer per organization" 
echo "• 1 orderer node"
echo "• API server on port 3000"
echo ""

# Check if user wants to proceed
read -p "Continue? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "👋 Setup cancelled"
    exit 0
fi

# Quick prerequisite check
echo "🔍 Checking prerequisites..."
command -v docker >/dev/null 2>&1 || { echo "❌ Docker required but not installed. Get it at https://docs.docker.com/get-docker/"; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "❌ Docker Compose required. Get it at https://docs.docker.com/compose/install/"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "❌ Node.js required. Get it at https://nodejs.org/"; exit 1; }
command -v go >/dev/null 2>&1 || { echo "❌ Go required. Get it at https://golang.org/dl/"; exit 1; }

if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker daemon not running. Please start Docker and try again."
    exit 1
fi

echo "✅ Prerequisites OK"

# Run the main deployment tool in dev mode
echo ""
echo "🏗️  Starting development deployment..."
echo "    (This will take 2-3 minutes)"
echo ""

if [ -f "src/deploy.js" ]; then
    chmod +x src/deploy.js
    node src/deploy.js --mode=dev --force
else
    echo "❌ src/deploy.js not found. Please run this from the project root directory."
    exit 1
fi

echo ""
echo "🎉 Quick start complete!"
echo ""
echo "📊 Your development environment is ready:"
echo "• API Server: http://localhost:3000"
echo "• Health Check: http://localhost:3000/health"
echo "• Test the API: curl http://localhost:3000/api/blockchain/products"
echo ""
echo "💡 Next steps:"
echo "• Check the README for API documentation"
echo "• Run integration tests: cd tests && ./integration-test.sh"
echo "• View logs: docker-compose -f network/docker-compose.yaml logs -f"
echo ""
echo "🛑 To stop: ./deploy.js --destroy" 