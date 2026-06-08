const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const router = express.Router();
const mongoose = require('mongoose');
errorHandler = require('../utils/errorhandler');

// Register a new user
router.post('/register', async (req, res) => {
    console.log(req.body);  //debug

    const { username, email, password } = req.body;

    try {
        // Check if user exists
        const existingUser = await User.findOne({ email });
        if (existingUser) return res.status(400).json({ message: 'User already exists' });

        // Hash password
        const hashedPassword = await bcrypt.hash(password, 10);

        // Create new user
        const newUser = new User({
            _id: new mongoose.Types.ObjectId(),
            username,
            email,
            password_hash: hashedPassword,
        });

        //save new user in users collection of tippsy database
        await newUser.save();
        res.status(201).json({ message: 'User registered successfully!', user: { id: newUser._id, username: newUser.username } });
    } catch (error) {
        errorHandler(error, req, res, next);
    }
});

// Login a user
router.post('/login', async (req, res) => {
    console.log(req.body);  //debug

    const { email, password } = req.body;

    try {
        const user = await User.findOne({ email });
        if (!user) return res.status(404).json({ message: 'User not found' });

        const isMatch = await bcrypt.compare(password, user.password_hash);
        if (!isMatch) return res.status(400).json({ message: 'Invalid credentials' });

        const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '1h' });
        res.status(200).json({ token, user: { id: user._id, username: user.username } });
    } catch (error) {
        errorHandler(error, req, res, next);
    }
});

module.exports = router;
