#!/bin/bash

# Start AI Layer in the background on port 8001
echo "Starting AI Layer on port 8001..."
cd /app/ai_layer
uvicorn main:app --host 127.0.0.1 --port 8001 &
AI_PID=$!

# Start Node Backend
echo "Starting Node.js Backend..."
cd /app/backend
export AI_LAYER_URL="http://127.0.0.1:8001"
# Koyeb sets the PORT env variable automatically
npm start &
NODE_PID=$!

# Wait for any process to exit
wait -n
  
# Exit with status of process that exited first
exit $?
