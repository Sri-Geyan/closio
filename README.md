# Closio

Closio is a minimal, location-based social hub application designed to connect friends through shared hubs, real-time context nodes, bill splitting, event planning, and collaborative music jukebox sessions.

## Project Structure

This is a monorepo containing multiple applications and services:

- `apps/mobile`: The main cross-platform Flutter mobile application.
- `apps/backend`: The Node.js (Express & Prisma) backend providing REST APIs and WebSocket services for real-time interactions.
- `apps/ai_layer`: Python-based AI workers for location, venue suggestions, and data processing.
- `apps/web`: A web interface component for the ecosystem.

## Core Features
- **Hubs**: Private groups for friends to communicate and plan.
- **Context Nodes**: Real-time live location tracking and visualization on a map.
- **Bill Splitting**: Manage shared expenses and pending splits effortlessly within your hubs.
- **Jukebox**: Collaborative listening sessions where friends can queue and vote on songs.
- **WebRTC Voice Rooms**: Drop-in voice chat capabilities for hubs.

## Technologies Used
- **Frontend**: Flutter, Provider, Google Maps, WebRTC
- **Backend**: Node.js, Express, Socket.IO, Prisma ORM, PostgreSQL
- **Authentication**: Supabase Auth
- **AI/Workers**: Python, Redis

## Setup

1. **Backend**: Navigate to `apps/backend`, run `npm install`, and configure `.env` with your database and Supabase credentials. Use `npm run dev` to start the development server.
2. **Mobile App**: Navigate to `apps/mobile`, run `flutter pub get`, and use `flutter run` to launch on a simulator or device.
