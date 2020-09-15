"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getLogger = void 0;
const winston_1 = require("winston");
const { combine, timestamp, label, json } = winston_1.format;
exports.getLogger = (name, sendToConsole = true) => {
    let transportArray = [
        new winston_1.transports.File({ filename: `./logs/all.log` }),
        new winston_1.transports.File({
            filename: `./logs/error.log`,
            level: 'error'
        }),
        new winston_1.transports.File({
            filename: `./logs/debug.log`,
            level: 'debug'
        }),
        new winston_1.transports.File({
            filename: `./logs/warn.log`,
            level: 'warn'
        })
    ];
    if (sendToConsole)
        transportArray = [new winston_1.transports.Console(), ...transportArray];
    return winston_1.createLogger({
        level: 'info',
        exitOnError: false,
        format: combine(label({ label: name }), timestamp(), json()),
        transports: transportArray
    });
};
