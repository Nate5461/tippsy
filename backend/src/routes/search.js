const express = require('express');
const Drink = require('../models/Drink');
const Restaurant = require('../models/Restaurant');
const router = express.Router();
const mongoose = require('mongoose');
errorHandler = require('../utils/errorhandler');
const User = require('../models/User');

router.get('/drinks', async (req, res) => {
    const { query } = req.query;

    try {
        let searchCriteria = {};
        if (query) {
            searchCriteria = {
                $or: [
                    { name: { $regex: query, $options: 'i' } },
                    { category: { $regex: query, $options: 'i' } },
                ],
            };
        }
        const drinks = await Drink.find(searchCriteria).populate('reviews');

        const formattedDrinks = drinks.map(drink => ({
            id: drink._id,
            name: drink.name,
            category: drink.category,
            recipe: {
                ingredients: drink.recipe.ingredients,
                instructions: drink.recipe.instructions || "",
            },
            reviews: drink.reviews,
            averageRating: drink.reviews.length > 0
                ? drink.reviews.reduce((acc, review) => acc + review.rating, 0) / drink.reviews.length
                : 0,
            totalReviews: drink.reviews.length,
        }));

        console.log(formattedDrinks);
        res.status(200).json(formattedDrinks);
    } catch (error) {
        errorHandler(error, req, res);
    }
});

// Search (query) for restaurants by name
router.get('/restaurants', async (req, res) => {
    const { query } = req.query;

    if (!query) {
        return res.status(400).json({ error: 'Query parameter is required' });
    }

    try {
        const restaurants = await Restaurant.find({ name: { $regex: query, $options: 'i' } });
        res.status(200).json(restaurants);
    } catch (error) {
        errorHandler(error, req, res);
    }
});

// Fetch all drinks
router.get('/allDrinks', async (req, res) => {
    try {
        const drinks = await Drink.find({}, 'name'); // Fetch only the 'name' field
        res.status(200).json(drinks);
    } catch (error) {
        errorHandler(error, req, res);
    }
});

// Fetch all restaurants
router.get('/allRestaurants', async (req, res) => {
    try {
        const restaurants = await Restaurant.find({}, 'name'); // Fetch only the 'name' field
        res.status(200).json(restaurants);
    } catch (error) {
        errorHandler(error, req, res);
    }
});

// Search User by Username
router.get('/users', async (req, res) => {
    const { username } = req.query;

    try {
        const query = username ? { username: { $regex: username, $options: 'i' } } : {};
        const users = await User.find(query)
            .populate('preferences.drink', 'name')
            .populate('preferences.restaurant', 'name')
            .populate('followers', 'username profile_picture')
            .populate('following', 'username profile_picture');

        const formattedUsers = users.map(user => ({
            id: user._id,
            username: user.username,
            email: user.email,
            profilePicture: user.profile_picture || "",
            preferences: {
                drink: user.preferences.drink.map(drink => drink.name),
                restaurant: user.preferences.restaurant.map(restaurant => restaurant.name),
            },
            followers: user.followers.map(follower => ({
                id: follower._id,
                username: follower.username,
                profilePicture: follower.profile_picture || "",
            })),
            following: user.following.map(followingUser => ({
                id: followingUser._id,
                username: followingUser.username,
                profilePicture: followingUser.profile_picture || "",
            })),
        }));
        
        console.log(formattedUsers);
        res.status(200).json(formattedUsers);
    } catch (error) {
        errorHandler(error, req, res);
    }
});



module.exports = router;
