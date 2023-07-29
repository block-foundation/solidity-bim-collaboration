// SPDX-License-Identifier: Apache-2.0


// Copyright 2023 Stichting Block Foundation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";

describe("CollaborativeBIM", function () {
    let CollaborativeBIM: Contract;
    let collaborativeBIM: Contract;
    let admin: Signer, user1: Signer, user2: Signer;
    const MODEL_UPDATER_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MODEL_UPDATER_ROLE"));

    beforeEach(async function () {
        CollaborativeBIM = await ethers.getContractFactory("CollaborativeBIM");
        [admin, user1, user2, _] = await ethers.getSigners();
        collaborativeBIM = await CollaborativeBIM.connect(admin).deploy();
        await collaborativeBIM.deployed();

        // Grant the MODEL_UPDATER_ROLE to user1
        await collaborativeBIM.grantRole(MODEL_UPDATER_ROLE, await user1.getAddress());
    });

    it("Should create and complete a new model", async function () {
        await collaborativeBIM.connect(user1).createModel("Model1", "URL1");
        const model = await collaborativeBIM.getModel(0);
        expect(model.name).to.equal("Model1");
        expect(model.url).to.equal("URL1");
        expect(model.isComplete).to.equal(false);
        expect(model.author).to.equal(await user1.getAddress());

        await collaborativeBIM.connect(admin).completeModel(0);
        const updatedModel = await collaborativeBIM.getModel(0);
        expect(updatedModel.isComplete).to.equal(true);
    });

    it("Should propose a change to a model", async function () {
        await collaborativeBIM.connect(user1).createModel("Model1", "URL1");
        await collaborativeBIM.connect(user1).proposeChange(0, "Model1-changed", "URL1-changed");
        const proposedChanges = await collaborativeBIM.proposedChanges(0);
        expect(proposedChanges[0].name).to.equal("Model1-changed");
        expect(proposedChanges[0].url).to.equal("URL1-changed");
        expect(proposedChanges[0].proposer).to.equal(await user1.getAddress());
    });

    it("Should vote and approve a proposed change", async function () {
        await collaborativeBIM.connect(user1).createModel("Model1", "URL1");
        await collaborativeBIM.connect(user1).proposeChange(0, "Model1-changed", "URL1-changed");
        await collaborativeBIM.connect(user1).voteChange(0, 0);
        const proposedChangesBefore = await collaborativeBIM.proposedChanges(0);
        expect(proposedChangesBefore[0].voteCount).to.equal(1);

        await collaborativeBIM.connect(admin).approveChange(0, 0);
        const proposedChangesAfter = await collaborativeBIM.proposedChanges(0);
        expect(proposedChangesAfter[0].isApproved).to.equal(true);

        const updatedModel = await collaborativeBIM.getModel(0);
        expect(updatedModel.name).to.equal("Model1-changed");
        expect(updatedModel.url).to.equal("URL1-changed");
    });

    it("Should fail to approve a proposed change without enough votes", async function () {
        await collaborativeBIM.connect(user1).createModel("Model1", "URL1");
        await collaborativeBIM.connect(user1).proposeChange(0, "Model1-changed", "URL1-changed");
        await expect(collaborativeBIM.connect(admin).approveChange(0, 0))
            .to.be.revertedWith("Not enough votes");
    });
});
