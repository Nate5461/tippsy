const express = require('express');
const app = express();
const mongoose = require('mongoose');
const bodyParser = require('body-parser');
require('dotenv').config();
const cors = require('cors');
const errorHandler = require('./src/utils/errorhandler'); // Import error handler
const path = require('path');
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(cors());

// Serve static files from the 'uploads' directory
app.use('/uploads', express.static(path.join(__dirname, 'src', 'uploads'))); 

// Routes
app.get('/', (req, res) => res.send('TIPPSY API is running!'));

// Import routes
const authRoutes = require('./src/routes/auth');
const reviewRoutes = require('./src/routes/reviews');
const searchRoutes = require('./src/routes/search');
const userRoutes = require('./src/routes/users');
const restaurantRoutes = require('./src/routes/restaurants');

// Use routes
app.use('/auth', authRoutes);
app.use('/reviews', reviewRoutes);
app.use('/search', searchRoutes);
app.use('/users', userRoutes);
app.use('/restaurants', restaurantRoutes); 

// Increase payload limit
app.use(bodyParser.json({ limit: '10mb' }));
app.use(bodyParser.urlencoded({ limit: '10mb', extended: true }));

// Connect to MongoDB
mongoose.connect(process.env.MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(() => console.log('MongoDB Connected'))
  .catch(err => console.error(err));

// Error-handling middleware (must be placed after routes)
app.use(errorHandler);

// Start the server
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
