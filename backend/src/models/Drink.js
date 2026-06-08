const mongoose = require('mongoose');

const drinkSchema = new mongoose.Schema({
    _id: mongoose.Schema.Types.ObjectId,
    name: { type: String, required: true },
    category: { type: String, required: true },
    recipe: {
        ingredients: [{ type: String }],
        instructions: { type: String },
    },
    reviews: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Review' }],
});

module.exports = mongoose.model('Drink', drinkSchema);
