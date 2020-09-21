"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.isEventArray = exports.createInstance = exports.createCommitId = exports.toRecord = exports.serialize = exports.makeKey = exports.splitKey = void 0;
const lodash_1 = require("lodash");
const commit_1 = require("./commit");
exports.splitKey = (key) => key.split('~');
exports.makeKey = (keyParts) => keyParts.map(part => JSON.stringify(part)).join('~');
exports.serialize = object => Buffer.from(JSON.stringify(object));
exports.toRecord = (commit) => lodash_1.assign({}, { [commit.commitId]: commit });
exports.createCommitId = () => `${new Date(Date.now()).toISOString().replace(/[^0-9]/g, '')}`;
exports.createInstance = (option) => new commit_1.Commit({
    id: option.id,
    entityName: option.entityName,
    commitId: option.commitId,
    version: parseInt(option.version, 10),
    mspId: option.mspId,
    events: option.events,
    entityId: option.id
});
// type guard for transient data
exports.isEventArray = (value) => Array.isArray(value) && value.every(item => typeof item.type === 'string');
