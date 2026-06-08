const express = require('express');
const User = require('../models/User');
const Review = require('../models/Review');
const Drink = require('../models/Drink');
const Restaurant = require('../models/Restaurant');
const router = express.Router();
const mongoose = require('mongoose');
const baseUrl = "http://localhost:3000"; 

// Show users with the most followers (Top 5)
router.get('/topUsers', async (req, res) => {
    try {
        const users = await User.find()
            .sort({ followers: -1 })
            .limit(5)
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
        console.error(error.message);
        res.status(500).json({ message: 'Error fetching top users', error: error.message });
    }
});

// Fetch user profile
router.get('/:userId', async (req, res) => {
    try {
        const user = await User.findById(req.params.userId)
            .populate('preferences.drink', 'name')
            .populate('preferences.restaurant', 'name')
            .populate('followers', 'username profile_picture')
            .populate('following', 'username profile_picture');
        
        const reviews = await Review.find({ user_id: req.params.userId })
            .populate('drink_id', 'name')
            .populate('restaurant_id', 'name');

        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        res.status(200).json({
            user: {
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
                    profilePicture: follower.profile_picture,
                })),
                following: user.following.map(followingUser => ({
                    id: followingUser._id,
                    username: followingUser.username,
                    profilePicture: followingUser.profile_picture,
                })),
            },
            reviews: reviews.map(review => ({
                id: review._id,
                drinkName: review.drink_id?.name || null,
                restaurantName: review.restaurant_id?.name || null,
                rating: review.rating,
                comment: review.comment,
                impairment_level: review.impairment_level,
                photoUrl: review.photoUrl ? `${baseUrl}${review.photoUrl}` : null,
            })),
        });
    } catch (error) {
        res.status(500).json({ message: 'Error fetching profile', error: error.message });
    }
});

// Fetch reviews from users the logged-in user is following
router.get('/:userId/following/reviews', async (req, res) => {
    const { userId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(userId)) {
        return res.status(400).json({ message: 'Invalid user ID' });
    }

    try {
        const user = await User.findById(userId).populate('following');
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        const reviews = await Review.find({ user_id: { $in: user.following } })
            .populate('drink_id', 'name')
            .populate('restaurant_id', 'name');

        res.status(200).json(reviews.map(review => ({
            id: review._id,
            drinkName: review.drink_id?.name || null,
            restaurantName: review.restaurant_id?.name || null,
            rating: review.rating,
            comment: review.comment,
            impairment_level: review.impairment_level,
            photoUrl: review.photoUrl ? `${baseUrl}${review.photoUrl}` : null,
            userId: review.user_id, // Include the user ID who posted the review
        })));
    } catch (error) {
        console.error(error.message);
        res.status(500).json({ message: 'Error fetching reviews from followed users', error: error.message });
    }
});

// Fetch the list of users the logged-in user is following
router.get('/:userId/following', async (req, res) => {
    const { userId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(userId)) {
        return res.status(400).json({ message: 'Invalid user ID' });
    }

    try {
        const user = await User.findById(userId).populate('following', 'username profile_picture');
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        // Map the following users to the Follower structure
        const followingUsers = user.following.map(followingUser => ({
            id: followingUser._id,
            username: followingUser.username,
            profilePicture: followingUser.profile_picture,
        }));

        res.status(200).json(followingUsers);
    } catch (error) {
        console.error(error.message);
        res.status(500).json({ message: 'Error fetching following list', error: error.message });
    }
});

// Update user profile
router.put('/:userId', async (req, res) => {
    const { username, profile_picture, preferences } = req.body;

    try {
        const drinkIds = await Promise.all(preferences.drink.map(async (drinkName) => {
            const drink = await Drink.findOne({ name: drinkName });
            if (!drink) throw new Error(`Drink '${drinkName}' not found`);
            return drink._id;
        }));

        const restaurantIds = await Promise.all(preferences.restaurant.map(async (restaurantName) => {
            const restaurant = await Restaurant.findOne({ name: restaurantName });
            if (!restaurant) throw new Error(`Restaurant '${restaurantName}' not found`);
            return restaurant._id;
        }));

        const updatedUser = await User.findByIdAndUpdate(
            req.params.userId,
            {
                username,
                profile_picture,
                preferences: { drink: drinkIds, restaurant: restaurantIds },
            },
            { new: true }
        ).populate('preferences.drink', 'name')
         .populate('preferences.restaurant', 'name');

        res.status(200).json({
            id: updatedUser._id,
            username: updatedUser.username,
            profilePicture: updatedUser.profile_picture,
            preferences: {
                drink: updatedUser.preferences.drink.map((drink) => drink.name),
                restaurant: updatedUser.preferences.restaurant.map((restaurant) => restaurant.name),
            },
        });
    } catch (error) {
        console.error(error.message);
        res.status(500).json({ message: 'Error updating profile', error: error.message });
    }
});

// Follow a user
router.post('/:userId/follow', async (req, res) => {
    const { userId } = req.params;
    const { followUserId } = req.body;

    if (!mongoose.Types.ObjectId.isValid(userId) || !mongoose.Types.ObjectId.isValid(followUserId)) {
        return res.status(400).json({ message: 'Invalid user ID' });
    }

    try {
        const user = await User.findById(userId);
        const followUser = await User.findById(followUserId);

        if (!user || !followUser) {
            return res.status(404).json({ message: 'User not found' });
        }

        if (user.following.includes(followUserId)) {
            return res.status(400).json({ message: 'Already following this user' });
        }

        user.following.push(followUserId);
        followUser.followers.push(userId);

        await user.save();
        await followUser.save();

        res.status(200).json({ message: 'Successfully followed the user' });
    } catch (error) {
        console.error(error.message);
        res.status(500).json({ message: 'Error following user', error: error.message });
    }
});

// Unfollow a user
router.post('/:userId/unfollow', async (req, res) => {
    const { userId } = req.params;
    const { unfollowUserId } = req.body;

    if (!mongoose.Types.ObjectId.isValid(userId) || !mongoose.Types.ObjectId.isValid(unfollowUserId)) {
        return res.status(400).json({ message: 'Invalid user ID' });
    }

    try {
        const user = await User.findById(userId);
        const unfollowUser = await User.findById(unfollowUserId);

        if (!user || !unfollowUser) {
            return res.status(404).json({ message: 'User not found' });
        }

        if (!user.following.includes(unfollowUserId)) {
            return res.status(400).json({ message: 'Not following this user' });
        }

        user.following = user.following.filter(id => id.toString() !== unfollowUserId);
        unfollowUser.followers = unfollowUser.followers.filter(id => id.toString() !== userId);

        await user.save();
        await unfollowUser.save();

        res.status(200).json({ message: 'Successfully unfollowed the user' });
    } catch (error) {
        console.error(error.message);
        res.status(500).json({ message: 'Error unfollowing user', error: error.message });
    }
});

// Show all followers of a user
router.get('/:userId/followers', async (req, res) => {
    const { userId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(userId)) {
        return res.status(400).json({ message: 'Invalid user ID' });
    }

    try {
        const user = await User.findById(userId).populate('followers', 'username profile_picture');

        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        res.status(200).json(user.followers);
    } catch (error) {
        console.error(error.message);
        res.status(500).json({ message: 'Error fetching followers', error: error.message });
    }
});

module.exports = router;