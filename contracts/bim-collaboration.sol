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


pragma solidity ^0.8.19;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract CollaborativeBIM is ERC721, AccessControl {

    struct BIMModel {
        string name;
        string url;
        bool isComplete;
        address author;
    }

    struct ProposedChange {
        uint256 modelId;
        string name;
        string url;
        address proposer;
        bool isApproved;
        mapping(address => bool) votes;
        uint256 voteCount;
    }

    bytes32 public constant MODEL_UPDATER_ROLE = keccak256("MODEL_UPDATER_ROLE");

    mapping(uint256 => BIMModel) public bimModels;
    mapping(uint256 => ProposedChange[]) public proposedChanges;

    uint256 public modelCounter;

    event ModelCreated(uint256 modelId, string name, string url, address author);
    event ModelCompleted(uint256 modelId);
    event ChangeProposed(uint256 modelId, uint256 changeId, string name, string url, address proposer);
    event ChangeApproved(uint256 modelId, uint256 changeId);
    event VoteCast(address voter, uint256 modelId, uint256 changeId);

    constructor() ERC721("CollaborativeBIM", "BIM") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function createModel(string memory _name, string memory _url) public {
        require(hasRole(MODEL_UPDATER_ROLE, msg.sender), "Caller is not a model updater");

        bimModels[modelCounter] = BIMModel({
            name: _name,
            url: _url,
            isComplete: false,
            author: msg.sender
        });

        _mint(msg.sender, modelCounter);

        emit ModelCreated(modelCounter, _name, _url, msg.sender);

        modelCounter++;
    }

    function completeModel(uint256 _modelId) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_exists(_modelId), "ERC721: operator query for nonexistent token");

        BIMModel storage model = bimModels[_modelId];
        model.isComplete = true;

        emit ModelCompleted(_modelId);
    }

    function getModel(uint256 _modelId) public view returns (string memory name, string memory url, bool isComplete, address author) {
        require(_exists(_modelId), "ERC721: operator query for nonexistent token");

        BIMModel storage model = bimModels[_modelId];

        return (model.name, model.url, model.isComplete, model.author);
    }

    function proposeChange(uint256 _modelId, string memory _name, string memory _url) public {
        require(_exists(_modelId), "ERC721: operator query for nonexistent token");

        ProposedChange memory change = ProposedChange({
            modelId: _modelId,
            name: _name,
            url: _url,
            proposer: msg.sender,
            isApproved: false,
            voteCount: 0
        });

        proposedChanges[_modelId].push(change);

        emit ChangeProposed(_modelId, proposedChanges[_modelId].length - 1, _name, _url, msg.sender);
    }

    function voteChange(uint256 _modelId, uint256 _changeId) public {
        require(_exists(_modelId), "ERC721: operator query for nonexistent token");
        require(_isApprovedOrOwner(msg.sender, _modelId), "Caller is not owner nor approved");

        ProposedChange storage change = proposedChanges[_modelId][_changeId];
        require(!change.votes[msg.sender], "Caller has already voted");

        change.votes[msg.sender] = true;
        change.voteCount++;

        emit VoteCast(msg.sender, _modelId, _changeId);
    }

    function approveChange(uint256 _modelId, uint256 _changeId) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_exists(_modelId), "ERC721: operator query for nonexistent token");

        ProposedChange storage change = proposedChanges[_modelId][_changeId];
        require(change.voteCount > totalSupply() / 2, "Not enough votes");

        change.isApproved = true;

        BIMModel storage model = bimModels[_modelId];
        model.name = change.name;
        model.url = change.url;

        emit ChangeApproved(_modelId, _changeId);
    }
}
