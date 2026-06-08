const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
    _id: mongoose.Schema.Types.ObjectId,
    senderId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    recipientId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    content: { type: String, required: true },
    timestamp: { type: Date, default: Date.now },
    //Enumerator (for status of message, e.g. unread, read, deleted)
    status: {type: Enumerator, default: 'unread'}
});

module.exports = mongoose.model('Restaurant', messageSchema);