const express = require('express');
const Review = require('../models/Review');
const Drink = require('../models/Drink');
const User = require('../models/User');
const router = express.Router();
const mongoose = require('mongoose');
const multer = require('multer');
const path = require('path');
errorHandler = require('../utils/errorhandler');

    

// Configure multer for file uploads
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        const uploadPath = path.join(__dirname, '../uploads'); // Use absolute path
        cb(null, uploadPath);
    },
    filename: (req, file, cb) => {
        cb(null, Date.now() + path.extname(file.originalname)); // Rename file to avoid conflicts
    },
});

const upload = multer({ storage });

// Create a new review with photo upload
router.post('/', upload.single('photo'), async (req, res) => {
    const { user_id, drink_id, restaurant_id, rating, comment, impairment_level } = req.body;
    const photoUrl = req.file ? `/uploads/${req.file.filename}` : null; // Get the file path if a file was uploaded

    try {
        const existingReview = await Review.findOne({ user_id, drink_id, restaurant_id, comment });
        if (existingReview) {
            return res.status(400).json({ message: 'Review already exists' });
        }

        const newReview = new Review({
            _id: new mongoose.Types.ObjectId(),
            user_id,
            drink_id,
            restaurant_id,
            rating,
            comment,
            impairment_level,
            photoUrl, // Save the photo URL in the review
        });

        await newReview.save();
        await User.updateOne({ _id: user_id }, { $push: { reviews: newReview._id } });

        if (drink_id) {
            await Drink.updateOne({ _id: drink_id }, { $push: { reviews: newReview._id } });
        }

        res.status(201).json({ message: 'Review added successfully!', photoUrl });
    } catch (error) {
        if (error.name === 'ValidationError') {
            res.status(400).json({ message: error.message });
        } else {
            console.error(error);
            res.status(500).json({ message: 'Internal server error' });
        }
    }
});


// Get most reviewed drinks (Top 6)
router.get('/mostReviewedDrinks', async (req, res) => {
    try {
        const drinks = await Drink.aggregate([
            {
                $lookup: {
                    from: 'reviews',
                    localField: '_id',
                    foreignField: 'drink_id',
                    as: 'reviews'
                }
            },
            {
                $addFields: {
                    totalReviews: { $size: '$reviews' }
                }
            },
            {
                $sort: { totalReviews: -1 }
            },
            {
                $limit: 5
            },
            {
                $project: {
                    _id: 1,
                    name: 1,
                    category: 1,
                    recipe: 1,
                    reviews: { $map: { input: '$reviews', as: 'review', in: '$$review._id' } },
                    totalReviews: 1
                }
            }
        ]);
        const formattedDrinks = drinks.map(drink => ({
            id: drink._id,
            name: drink.name,
            category: drink.category,
            recipe: drink.recipe,
            reviews: drink.reviews
        }));

        console.log(formattedDrinks);
        res.status(200).json(formattedDrinks);
    } catch (error) {
        errorHandler(error, req, res);
    }
});

// Fetch all reviews sorted by latest
router.get('/reviews', async (req, res) => {
    try {
        const reviews = await Review.find().sort({ createdAt: -1 }).populate('user_id', 'username');
        const response = reviews.map(review => ({
            id: review._id,
            drinkName: review.drink_id?.name, // Assuming drink_id is populated
            restaurantName: review.restaurant_id?.name, // Assuming restaurant_id is populated
            rating: review.rating,
            comment: review.comment,
            impairmentLevel: review.impairment_level,
            photoUrl: review.photoUrl // Ensure this is included
        }));
        console.log(response);
        res.status(200).json(response);
    } catch (error) {
        errorHandler(error, req, res);
    }
});

// Fetch reviews for a drink
router.get('/drink', async (req, res) => {
    const { drinkId } = req.query; // Optional query parameter
    const filter = drinkId ? { drink_id: drinkId } : { drink_id: { $ne: null } };

    try {
        const reviews = await Review.find(filter).populate('user_id', 'username');
        res.status(200).json(reviews);
    } catch (error) {
        errorHandler(error, req, res);
    }
});


// Fetch reviews for a restaurant
router.get('/restaurant/:restaurantId', async (req, res) => {
    try {
        const reviews = await Review.find({ restaurant_id: req.params.restaurantId }).populate('user_id', 'username');
        res.status(200).json(reviews);
    } catch (error) {
        errorHandler(error, req, res);
    }
});

//Fetch reviews for all restaurants
router.get('/restaurant', async (req, res) => {
    try {
        const reviews = await Review.find({ restaurant_id: { $ne: null } }).populate('user_id', 'username');
        res.status(200).json(reviews);
    } catch (error) {
        errorHandler(error, req, res);
    }
});

//Fetch 

module.exports = router;