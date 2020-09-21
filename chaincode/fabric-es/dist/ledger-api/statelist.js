"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.StateList = void 0;
const util_1 = __importDefault(require("util"));
const lodash_1 = require("lodash");
const _1 = require(".");
class StateList {
    constructor(ctx, name) {
        this.ctx = ctx;
        this.name = name;
    }
    async getQueryResult(attributes, plainObject) {
        const promises = this.ctx.stub.getStateByPartialCompositeKey('entities', attributes);
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
        return plainObject ? result : Buffer.from(JSON.stringify(result));
    }
    async addState(commit) {
        await this.ctx.stub.putState(this.ctx.stub.createCompositeKey(this.name, _1.splitKey(commit.key)), _1.serialize(commit));
    }
    async getState(key) {
        let result;
        const data = await this.ctx.stub.getState(this.ctx.stub.createCompositeKey(this.name, _1.splitKey(key)));
        try {
            result = data.toString() ? JSON.parse(data.toString()) : Object.assign({});
        }
        catch (e) {
            console.error(e);
            throw new Error(util_1.default.format('fail to parse data, %j', e));
        }
        return result;
    }
    async deleteState(commit) {
        await this.ctx.stub.deleteState(this.ctx.stub.createCompositeKey(this.name, _1.splitKey(commit.key)));
    }
    async deleteStateByEnityId(attributes) {
        const promises = this.ctx.stub.getStateByPartialCompositeKey('entities', attributes);
        const result = {};
        try {
            for await (const res of promises) {
                const { key, commitId } = JSON.parse(res.value.toString());
                await this.ctx.stub.deleteState(this.ctx.stub.createCompositeKey('entities', _1.splitKey(key)));
                result[commitId] = {};
            }
        }
        catch (e) {
            console.error(e);
            throw new Error(util_1.default.format('fail to deleteStateByEnityId, %j', e));
        }
        return Buffer.from(JSON.stringify({
            status: 'SUCCESS',
            message: `${lodash_1.keys(result).length} record(s) deleted`,
            result
        }));
    }
}
exports.StateList = StateList;
