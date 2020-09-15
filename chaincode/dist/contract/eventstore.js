"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.EventStore = void 0;
const util_1 = __importDefault(require("util"));
const fabric_contract_api_1 = require("fabric-contract-api");
const lodash_1 = require("lodash");
const ledger_api_1 = require("../ledger-api");
const myContext_1 = require("./myContext");
let EventStore = /** @class */ (() => {
    let EventStore = class EventStore extends fabric_contract_api_1.Contract {
        constructor(context = new fabric_contract_api_1.Context()) {
            super('eventstore');
            this.context = context;
        }
        createContext() {
            return new myContext_1.MyContext();
        }
        async Init(context) {
            console.info('=== START : Initialize eventstore ===');
            // const commits: Commit[] = [];
            // commits.push(
            //   createInstance({
            //     id: 'ent_dev_1001',
            //     entityName: 'dev_entity',
            //     version: '0',
            //     mspId: 'x',
            //     events: [{ type: 'User Created', payload: { name: 'April' } }],
            //     commitId: '12345a'
            //   })
            // );
            // commits.push(
            //   createInstance({
            //     id: 'ent_dev_1001',
            //     entityName: 'dev_entity',
            //     version: '0',
            //     mspId: 'x',
            //     events: [{ type: 'User Created', payload: { name: 'May' } }],
            //     commitId: '12345b'
            //   })
            // );
            // for (const commit of commits) {
            //   await context.stateList.addState(commit);
            // }
            console.info('=== END : Initialize eventstore ===');
            return 'Init Done';
        }
        async createCommit(context, entityName, id, version, eventStr, commitId) {
            if (!id || !entityName || !eventStr || !commitId || version === undefined)
                throw new Error('createCommit problem: null argument');
            let events;
            let commit;
            try {
                events = JSON.parse(eventStr);
            }
            catch (e) {
                console.error(e);
                throw new Error(util_1.default.format('fail to parse eventStr: %j', e));
            }
            if (ledger_api_1.isEventArray(events)) {
                commit = ledger_api_1.createInstance({
                    id,
                    version,
                    entityName,
                    mspId: context.stub.getCreator().mspid,
                    events,
                    commitId
                });
            }
            else
                throw new Error('eventStr is not correctly formatted');
            // ///////////////////////////////////////////////////////////////////
            // Add the concept 'lifeCycle' to BaseEvent (../ledger-api/commit.ts)
            // lifeCycle == 0 - NORMAL event, no restriction
            // lifeCycle == 1 - BEGIN event, can only appear once at the begining of the event stream of an entity
            // lifeCycle == 2 - END event, can only appear once at the end of the event stream of an entity
            const lcBgn = events.findIndex(item => item.lifeCycle && (item.lifeCycle === 1));
            const lcEnd = events.findIndex(item => item.lifeCycle && (item.lifeCycle === 2));
            if ((lcBgn >= 0) || (lcEnd >= 0)) {
                if ((lcBgn >= 0) && (lcEnd >= 0) && (lcBgn >= lcEnd)) {
                    // Both BEGIN and END events found in the stream, but in incorrect order (entity END before BEGIN)
                    throw new Error(`Cannot end ${id} before starting`);
                }
                const rslt = await context.stateList.getQueryResult([JSON.stringify(entityName), JSON.stringify(id)]);
                if (lcBgn >= 0) {
                    if (rslt && (rslt.toString('utf8').includes(`"id":"${id}"`))) {
                        // Attempt to BEGIN an entity with the same {id}
                        throw new Error(`Lifecycle of ${id} already started`);
                    }
                }
                if (lcEnd >= 0) {
                    if (!rslt || (!rslt.toString('utf8').includes(`"id":"${id}"`))) {
                        // Attempt to END an non-existing entity
                        throw new Error(`Lifecycle of ${id} not started yet`);
                    }
                    else if (rslt.toString('utf8').includes('"lifeCycle":2')) {
                        // Attempt to END an already ended entity
                        throw new Error(`Lifecycle of ${id} already ended`);
                    }
                }
            }
            // ///////////////////////////////////////////////////////////////////*/
            await context.stateList.addState(commit);
            console.info(`Submitter: ${context.clientIdentity.getID()} - createCommit`);
            const evt = lodash_1.omit(commit, 'key');
            evt.entityId = evt.id;
            context.stub.setEvent('createCommit', Buffer.from(JSON.stringify(evt)));
            return Buffer.from(JSON.stringify(ledger_api_1.toRecord(lodash_1.omit(commit, 'key', 'events'))));
        }
        async queryByEntityName(context, entityName) {
            if (!entityName)
                throw new Error('queryByEntityName problem: null argument');
            console.info(`Submitter: ${context.clientIdentity.getID()} - queryByEntityName`);
            return context.stateList.getQueryResult([JSON.stringify(entityName)]);
        }
        async queryByEntityId(context, entityName, id) {
            if (!id || !entityName)
                throw new Error('queryByEntityId problem: null argument');
            console.info(`Submitter: ${context.clientIdentity.getID()} - queryByEntityId`);
            return context.stateList.getQueryResult([JSON.stringify(entityName), JSON.stringify(id)]);
        }
        async queryByEntityIdCommitId(context, entityName, id, commitId) {
            if (!id || !entityName || !commitId)
                throw new Error('queryByEntityIdCommitId problem: null argument');
            console.info(`Submitter: ${context.clientIdentity.getID()} - queryByEntityIdCommitId`);
            const key = ledger_api_1.makeKey([entityName, id, commitId]);
            const commit = await context.stateList.getState(key);
            const result = {};
            if (commit === null || commit === void 0 ? void 0 : commit.commitId)
                result[commit.commitId] = lodash_1.omit(commit, 'key');
            return Buffer.from(JSON.stringify(result));
        }
        async deleteByEntityIdCommitId(context, entityName, id, commitId) {
            if (!id || !entityName || !commitId)
                throw new Error('deleteEntityByCommitId problem: null argument');
            console.info(`Submitter: ${context.clientIdentity.getID()} - deleteByEntityIdCommitId`);
            const key = ledger_api_1.makeKey([entityName, id, commitId]);
            const commit = await context.stateList.getState(key);
            if (commit === null || commit === void 0 ? void 0 : commit.key) {
                await context.stateList.deleteState(commit);
                return getSuccessMessage(`Commit ${commit.commitId} is deleted`);
            }
            else
                return getSuccessMessage('commitId does not exist');
        }
        async deleteByEntityId(context, entityName, id) {
            if (!id || !entityName)
                throw new Error('deleteByEntityId problem: null argument');
            console.info(`Submitter: ${context.clientIdentity.getID()} - deleteByEntityId`);
            return context.stateList.deleteStateByEnityId([JSON.stringify(entityName), JSON.stringify(id)]);
        }
    };
    __decorate([
        fabric_contract_api_1.Transaction(),
        fabric_contract_api_1.Returns('string'),
        __metadata("design:type", Function),
        __metadata("design:paramtypes", [myContext_1.MyContext]),
        __metadata("design:returntype", Promise)
    ], EventStore.prototype, "Init", null);
    __decorate([
        fabric_contract_api_1.Transaction(),
        fabric_contract_api_1.Returns('buffer'),
        __metadata("design:type", Function),
        __metadata("design:paramtypes", [myContext_1.MyContext, String, String, String, String, String]),
        __metadata("design:returntype", Promise)
    ], EventStore.prototype, "createCommit", null);
    __decorate([
        fabric_contract_api_1.Transaction(false),
        __metadata("design:type", Function),
        __metadata("design:paramtypes", [myContext_1.MyContext, String]),
        __metadata("design:returntype", Promise)
    ], EventStore.prototype, "queryByEntityName", null);
    __decorate([
        fabric_contract_api_1.Transaction(false),
        __metadata("design:type", Function),
        __metadata("design:paramtypes", [myContext_1.MyContext, String, String]),
        __metadata("design:returntype", Promise)
    ], EventStore.prototype, "queryByEntityId", null);
    __decorate([
        fabric_contract_api_1.Transaction(false),
        __metadata("design:type", Function),
        __metadata("design:paramtypes", [myContext_1.MyContext, String, String, String]),
        __metadata("design:returntype", Promise)
    ], EventStore.prototype, "queryByEntityIdCommitId", null);
    __decorate([
        fabric_contract_api_1.Transaction(),
        __metadata("design:type", Function),
        __metadata("design:paramtypes", [myContext_1.MyContext, String, String, String]),
        __metadata("design:returntype", Promise)
    ], EventStore.prototype, "deleteByEntityIdCommitId", null);
    __decorate([
        fabric_contract_api_1.Transaction(),
        __metadata("design:type", Function),
        __metadata("design:paramtypes", [myContext_1.MyContext, String, String]),
        __metadata("design:returntype", Promise)
    ], EventStore.prototype, "deleteByEntityId", null);
    EventStore = __decorate([
        fabric_contract_api_1.Info({
            title: 'smart contract for eventstore',
            description: 'smart contract for eventstore'
        }),
        __metadata("design:paramtypes", [myContext_1.MyContext])
    ], EventStore);
    return EventStore;
})();
exports.EventStore = EventStore;
const getErrorMessage = method => Buffer.from(JSON.stringify({
    status: 'ERROR',
    message: `${method} fails`
}));
const getSuccessMessage = message => Buffer.from(JSON.stringify({
    status: 'SUCCESS',
    message
}));
