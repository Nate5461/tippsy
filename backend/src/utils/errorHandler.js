const errorHandler = (err, req, res, next) => {
    console.error(err.stack); // Log the full error stack for debugging

    res.status(err.status || 500).json({
        error: true,
        message: err.message || 'Internal Server Error',
    });
};

module.exports = errorHandler;