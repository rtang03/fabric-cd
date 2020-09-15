"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Commit = void 0;
const index_1 = require("./index");
class Commit {
    constructor(option) {
        this.key = index_1.makeKey([option.entityName, option.id, option.commitId]);
        this.id = option.id;
        this.entityName = option.entityName;
        this.version = option.version;
        this.commitId = option.commitId;
        this.entityId = option.entityId;
        this.mspId = option.mspId;
        this.events = option.events;
        if (option.hash)
            this.hash = option.hash;
        if (option.isFirst === true || option.isFirst === false)
            this.isFirst = option.isFirst;
        if (option.isLast === true || option.isLast === false)
            this.isLast = option.isLast;
    }
}
exports.Commit = Commit;
