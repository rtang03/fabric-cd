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
exports.PrivateData = void 0;
const util_1 = __importDefault(require("util"));
const fabric_contract_api_1 = require("fabric-contract-api");
const lodash_1 = require("lodash");
const ledger_api_1 = require("../ledger-api");
class MyContext extends fabric_contract_api_1.Context {
    constructor() {
        super();
        this.stateList = new ledger_api_1.PrivateStateList(this, 'entities');
    }
}
/**
 * see https://hyperledger-fabric.readthedocs.io/en/release-2.0/private-data-arch.html
 */
let PrivateData = /** @class */ (() => {
    let PrivateData = class PrivateData extends fabric_contract_api_1.Contract {
        constructor(context = new fabric_contract_api_1.Context()) {
            super('privatedata');
            this.context = context;
        }
        createContext() {
            return new MyContext();
        }
        async Init(context) {
            console.info('=========== START : Initialize PrivateData =========');
            console.info('============= END : Initialize PrivateData ===========');
            return 'Init Done';
        }
        /**
         * createCommit create commit for private data
         * @param context context for Chaincode stub
         * @param entityName entityName
         * @param id id or entityId
         * @param version version
         * @param commitId commitId
         */
        async createCommit(context, entityName, id, version, commitId) {
            if (!id || !version || !entityName || !commitId)
                throw new Error('createCommit: null argument: id, version, entityName, collection');
            const collection = `_implicit_org_${context.clientIdentity.getMSPID()}`;
            console.info(`Submitter: ${context.clientIdentity.getID()} - createCommit`);
            let transientMap;
            try {
                transientMap = context.stub.getTransient();
            }
            catch (e) {
                console.error(e);
                throw new Error(util_1.default.format('fail to get transient map: %j', e));
            }
            if (!transientMap)
                throw new Error('Error getting transient map');
            let events;
            let eventStr;
            let commit;
            try {
                eventStr = transientMap.get('eventstr').toString();
            }
            catch (e) {
                console.error(e);
                throw new Error(util_1.default.format('fail to get eventstr from transient map: %j', e));
            }
            try {
                events = JSON.parse(eventStr);
            }
            catch (e) {
                console.error(e);
                throw new Error(util_1.default.format('fail to parse transient data: %j', e));
            }
            // ensure transient data is correct shape
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
                throw new Error('transient data is not correctly formatted');
            console.info(`CommitId created: ${commit.commitId}`);
            // protect private data content with salt
            // @see https://www.npmjs.com/package/bcrypt
            // commit.hash = await hash(JSON.stringify(events), 8);
            // todo: because bcrypt.js is binary compilation fail, in Github Action, now disable it.
            commit.hash = '';
            await context.stateList.addState(collection, commit);
            return Buffer.from(JSON.stringify(ledger_api_1.toRecord(lodash_1.omit(commit, 'key', 'events'))));
        }
        /**
         * queryByEntityName query commits by entityName
         * @param context context for Chaincode stub
         * @param entityName entityName
         */
        async queryByEntityName(context, entityName) {
            if (!entityName)
                throw new Error('queryPrivateDataByEntityName problem: null argument');
            const collection = `_implicit_org_${context.clientIdentity.getMSPID()}`;
            console.info(`Submitter: ${context.clientIdentity.getID()} - queryByEntityName`);
            return await context.stateList.getQueryResult(collection, [JSON.stringify(entityName)]);
        }
        /**
         * queryByEntityId query commit by entityId
         * @param context context for Chaincode stub
         * @param entityName entityName
         * @param id entityId or id
         */
        async queryByEntityId(context, entityName, id) {
            if (!id || !entityName)
                throw new Error('queryPrivateDataByEntityId problem: null argument');
            const collection = `_implicit_org_${context.clientIdentity.getMSPID()}`;
            console.info(`Submitter: ${context.clientIdentity.getID()} - queryByEntityId`);
            return await context.stateList.getQueryResult(collection, [JSON.stringify(entityName), JSON.stringify(id)]);
        }
        /**
         * queryByEntityIdCommitId query commit by entityId and commitId
         * @param context context for Chaincode stub
         * @param entityName entityName
         * @param id entityId or id
         * @param commitId commitId
         */
        async queryByEntityIdCommitId(context, entityName, id, commitId) {
            if (!id || !entityName || !commitId)
                throw new Error('getPrivateData problem: null argument');
            console.info(`Submitter: ${context.clientIdentity.getID()} - queryByEntityIdCommitId`);
            const collection = `_implicit_org_${context.clientIdentity.getMSPID()}`;
            const key = ledger_api_1.makeKey([entityName, id, commitId]);
            const commit = await context.stateList.getState(collection, key);
            const result = {};
            if (commit === null || commit === void 0 ? void 0 : commit.commitId)
                result[commit.commitId] = lodash_1.omit(commit, 'key');
            return Buffer.from(JSON.stringify(result));
        }
        /**
         * deleteByEntityIdCommitId delete commit by EntityId and commitId
         * @param context
         * @param entityName entityName
         * @param id entityId or id
         * @param commitId commitId
         */
        async deleteByEntityIdCommitId(context, entityName, id, commitId) {
            if (!id || !entityName || !commitId)
                throw new Error('deletePrivateDataByEntityIdCommitId problem: null argument');
            console.info(`Submitter: ${context.clientIdentity.getID()} - deleteByEntityIdCommitId`);
            const collection = `_implicit_org_${context.clientIdentity.getMSPID()}`;
            const key = ledger_api_1.makeKey([entityName, id, commitId]);
            let commit;
            try {
                commit = await context.stateList.getState(collection, key);
            }
            catch (e) {
                console.error(e);
            }
            if (commit === null || commit === void 0 ? void 0 : commit.key) {
                await context.stateList.deleteState(collection, commit);
                return Buffer.from(JSON.stringify({
                    status: 'SUCCESS',
                    message: `Commit ${commit.commitId} is deleted`
                }));
            }
            else {
                throw new Error('commitId does not exist');
            }
        }
    };
    __decorate([
        fabric_contract_api_1.Transaction(),
        fabric_contract_api_1.Returns('string'),
        __metadata("design:type", Function),
        __metadata("design:paramtypes", [MyContext]),
        __metadata("design:returntype", Promise)
    ], PrivateData.prototype, "Init", null);
    __decorate([
        fabric_contract_api_1.Transaction(),
        fabric_contract_api_1.Returns('bytebuffer'),
        __metadata("design:type", Function),
        __metadata("design:paramtypes", [MyContext, String, String, String, String]),
        __metadata("design:returntype", Promise)
    ], PrivateData.prototype, "createCommit", null);
    __decorate([
        fabric_contract_api_1.Transaction(false),
        __metadata("design:type", Function),
        __metadata("design:paramtypes", [MyContext, String]),
        __metadata("design:returntype", Promise)
    ], PrivateData.prototype, "queryByEntityName", null);
    __decorate([
        fabric_contract_api_1.Transaction(false),
        __metadata("design:type", Function),
        __metadata("design:paramtypes", [MyContext, String, String]),
        __metadata("design:returntype", Promise)
    ], PrivateData.prototype, "queryByEntityId", null);
    __decorate([
        fabric_contract_api_1.Transaction(false),
        __metadata("design:type", Function),
        __metadata("design:paramtypes", [MyContext, String, String, String]),
        __metadata("design:returntype", Promise)
    ], PrivateData.prototype, "queryByEntityIdCommitId", null);
    __decorate([
        fabric_contract_api_1.Transaction(),
        __metadata("design:type", Function),
        __metadata("design:paramtypes", [MyContext, String, String, String]),
        __metadata("design:returntype", Promise)
    ], PrivateData.prototype, "deleteByEntityIdCommitId", null);
    PrivateData = __decorate([
        fabric_contract_api_1.Info({
            title: 'smart contract for privatedata',
            description: 'smart contract for privatedata'
        }),
        __metadata("design:paramtypes", [MyContext])
    ], PrivateData);
    return PrivateData;
})();
exports.PrivateData = PrivateData;
