# Tippsy
*A new way to share, review and interact for both the seasoned connoisseurs or new drinkers!*

## Features
- Secure login and account management
- Rate and review drinks and restaurants
- Geolocation-based restaurant drink and search

## Project layout
```
backend/   Node.js + Express API (MongoDB via Mongoose)
ios/       SwiftUI app (Xcode project)
```

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
