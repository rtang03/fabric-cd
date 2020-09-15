"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.toString = exports.parseResult = void 0;
exports.parseResult = input => JSON.parse(Buffer.from(JSON.parse(input)).toString());
exports.toString = input => JSON.stringify(input).replace(/"/g, '\\"');
