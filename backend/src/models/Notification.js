const mongoose = require('mongoose');
const Drink = require('./Drink');

const notificationSchema = new mongoose.Schema({
    _id: mongoose.Schema.Types.ObjectId,
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    //might be best to remove the triggeredBy field and just use the userId field !!!!! (idk yet - to be discussed)
    triggeredBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    activityType: { type: String, required: true },
    drinkId: { type: mongoose.Schema.Types.ObjectId, ref: 'Drink', required: false },
    restaurantId: { type: mongoose.Schema.Types.ObjectId, ref: 'Restaurant', required: false },
    timestamp: { type: Date, default: Date.now },
    status: { type: Enumerator, default: 'unread' },
});

module.exports = mongoose.model('Restaurant', notificationSchema);