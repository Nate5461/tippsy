const mongoose = require('mongoose');

const restaurantSchema = new mongoose.Schema({
    _id: mongoose.Schema.Types.ObjectId,
    name: { type: String, required: true, unique: true }, // Ensure restaurant names are unique for easy lookup
    location: {
        type: {
            type: String,
            enum: ['Point'],
            required: true,
            default: 'Point',
        },
        coordinates: {
            type: [Number],
            required: true,
            default: [0, 0],
        },
    },
    drinks: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Drink' }],
    ratingsId: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Rating' }],
    reviews: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Review' }],
});

restaurantSchema.index({ location: '2dsphere' });

module.exports = mongoose.model('Restaurant', restaurantSchema);
