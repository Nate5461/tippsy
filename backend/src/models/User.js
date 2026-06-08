const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
    _id: mongoose.Schema.Types.ObjectId,
    username: { type: String, required: true, unique: true },
    email: { type: String, required: true, unique: true },
    password_hash: { type: String, required: true },
    //The profile picture of the user (image file)
    profile_picture: { type: String, required: false },
    location: { type: String },
    followers: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    following: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    preferences: {
        drink: { type: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Drink' }], default: [] },
        restaurant: { type: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Restaurant' }], default: [] },
    },
    reviews: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Review' }],
});

module.exports = mongoose.model('User', userSchema);
