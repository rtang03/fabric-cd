"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MyContext = void 0;
const fabric_contract_api_1 = require("fabric-contract-api");
const ledger_api_1 = require("../ledger-api");
class MyContext extends fabric_contract_api_1.Context {
    constructor() {
        super();
        this.stateList = new ledger_api_1.StateList(this, 'entities');
    }
}
exports.MyContext = MyContext;
