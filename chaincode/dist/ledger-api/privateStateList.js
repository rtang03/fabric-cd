"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PrivateStateList = void 0;
const util_1 = __importDefault(require("util"));
const lodash_1 = require("lodash");
const _1 = require(".");
class PrivateStateList {
    constructor(ctx, name) {
        this.ctx = ctx;
        this.name = name;
    }
    async getQueryResult(collection, attributes) {
        const promises = this.ctx.stub.getPrivateDataByPartialCompositeKey(collection, 'entities', attributes);
        const result = {};
        try {
            for await (const res of promises) {
                const commit = JSON.parse(res.value.toString());
                result[commit.commitId] = lodash_1.omit(commit, 'key');
            }
        }
        catch (e) {
            console.error(e);
            throw new Error(util_1.default.format('fail to getQueryResult, %j', e));
        }
        return Buffer.from(JSON.stringify(result));
    }
    async addState(collection, commit) {
        await this.ctx.stub.putPrivateData(collection, this.ctx.stub.createCompositeKey(this.name, _1.splitKey(commit.key)), _1.serialize(commit));
    }
    async getState(collection, key) {
        let result;
        const data = await this.ctx.stub.getPrivateData(collection, this.ctx.stub.createCompositeKey(this.name, _1.splitKey(key)));
        try {
            result = data.toString() ? JSON.parse(data.toString()) : Object.assign({});
        }
        catch (e) {
            console.error(e);
            throw new Error(util_1.default.format('fail to parse data, %j', e));
        }
        return result;
    }
    async deleteState(collection, { key }) {
        await this.ctx.stub.deletePrivateData(collection, this.ctx.stub.createCompositeKey(this.name, _1.splitKey(key)));
    }
}
exports.PrivateStateList = PrivateStateList;
