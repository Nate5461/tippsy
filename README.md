# Tippsy
*A new way to share, review and interact for both the seasoned connoisseurs or new drinkers!*

## Features
- Secure login and account management
- Rate and review drinks and restaurants
- Geolocation-based restaurant drink and search

## Project layout
```
server/    Go + PostgreSQL API (active rewrite — drinks-only, see server/README.md)
backend/   Legacy Node.js + Express API (MongoDB) — kept until the iOS app migrates, then removed
ios/       SwiftUI app (Xcode project)
```

> The backend is being rewritten in Go + PostgreSQL under `server/`. The product is
> pivoting to a pure drink curation / review app (restaurants dropped). The legacy
> `backend/` still runs until the iOS app is pointed at the new API.

## Installation
- Install Node.js, then install backend dependencies:
```
cd backend
npm install
```
- Create a `backend/.env` file with at least:
```
MONGO_URI=<your MongoDB connection string>
PORT=3000
JWT_SECRET=<a long random string>
```
- Ensure Xcode is available for the iOS app.

## Running
- Start the API:
```
cd backend
node server.js
```
- Open `ios/Tippsy/Tippsy.xcodeproj` in Xcode and run the app in the simulator.
