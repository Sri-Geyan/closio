# Closio

Closio is a minimal, location-based social hub application designed to connect friends through shared hubs, real-time context nodes, bill splitting, collaborative event planning, and interactive experiences like shared music jukeboxes and food ordering.

## Project Structure

This is a monorepo containing multiple applications and services:

- `apps/mobile`: The main cross-platform Flutter mobile application.
- `apps/backend`: The Node.js (Express & Prisma) backend providing REST APIs and WebSocket services for real-time interactions.
- `apps/ai_layer`: Python-based AI workers for location, venue suggestions, and data processing.
- `apps/web`: A React/Vite web interface component for the ecosystem.

## Core Features

### 🏢 Hubs & Social Connectivity
- **Private Hubs**: Create invite-only groups for different circles of friends.
- **Hub Chat & Events**: Plan meetups and communicate securely within your hub ecosystem.

### 📍 Context Nodes (Real-Time Location)
- **Live Tracking**: Share your live location with Hub members on an interactive Google Map.
- **Contextual Awareness**: See when friends are moving, at a venue, or running using health data integrations.

### 💸 Shared Finances (Bill Splitting)
- **Expense Tracking**: Easily add bills to a hub event.
- **Equitable or Custom Splits**: Divide the cost equally among members or input custom amounts for each person.
- **Settlement Dashboard**: Track who owes who and settle debts natively.

### 🎵 Collaborative Jukebox
- **Shared Queue**: Hub members can search for songs (via iTunes API) and add them to a shared queue.
- **Voting System**: Upvote or downvote tracks to decide what plays next democratically.
- **Synced Playback**: The entire hub listens to the same playlist in sync.

### 🍔 Zomato Food Integration
- **Restaurant Discovery**: Search for nearby restaurants and venues directly in the app.
- **Shared Carts**: Browse Zomato menus and add items to a shared cart for group ordering.

### 🏃‍♂️ Sports & Health Tracking
- **Venue Discovery**: Find sports venues for your group to play at.
- **Health Syncing**: Integrates with Apple Health / Google Fit to share running metrics and post-sport recaps with your friends.

### 🎙️ WebRTC Voice Rooms
- **Drop-in Audio**: Jump into a live voice channel for your hub to chat while coordinating plans or just hanging out.

## Technologies Used
- **Frontend**: Flutter, Provider, Google Maps, WebRTC, React
- **Backend**: Node.js, Express, Socket.IO, Prisma ORM, PostgreSQL
- **Authentication**: Supabase Auth
- **AI/Workers**: Python, Redis

## Setup

1. **Backend**: Navigate to `apps/backend`, run `npm install`, and configure `.env` with your database and Supabase credentials. Use `npm run dev` to start the development server.
2. **Mobile App**: Navigate to `apps/mobile`, run `flutter pub get`, and use `flutter run` to launch on a simulator or device.
