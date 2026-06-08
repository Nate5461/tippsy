const mongoose = require('mongoose');

const reviewSchema = new mongoose.Schema({
    _id: mongoose.Schema.Types.ObjectId,
    user_id: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    drink_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Drink', required: false },
    restaurant_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Restaurant', required: false },
    rating: { type: Number, required: true, min: 1, max: 5 },
    comment: { type: String },
    timestamp: { type: Date, default: Date.now },
    impairment_level: { type: Number, min: 1, max: 5 },
    photoUrl: { type: String, required: false }, // Add this line for the photo URL
}, {
    validate: {
        validator: function (doc) {
            return doc.drink_id || doc.restaurant_id;
        },
        message: 'Either drink_id or restaurant_id must be provided, but not both as empty.',
    },
});

module.exports = mongoose.model('Review', reviewSchema);