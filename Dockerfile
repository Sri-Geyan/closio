FROM python:3.11-slim

# Install Node.js
RUN apt-get update && apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean

WORKDIR /app

# Install Python dependencies
COPY apps/ai_layer/requirements.txt ./ai_layer/
RUN pip install --no-cache-dir -r ai_layer/requirements.txt

# Install Node dependencies and build
COPY apps/backend/package*.json ./backend/
WORKDIR /app/backend
RUN npm install
COPY apps/backend/ .
RUN npx prisma generate
RUN npm run build

# Copy AI layer code
WORKDIR /app
COPY apps/ai_layer/ ./ai_layer/

# Copy start script
COPY start.sh .
RUN chmod +x start.sh

# The port Koyeb expects (we'll expose 3000 by default, but Koyeb can inject PORT)
ENV PORT=3000
EXPOSE $PORT

CMD ["./start.sh"]
