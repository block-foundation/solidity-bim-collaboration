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


/// @title Collaborative BIM models management on blockchain
/// @notice This contract allows for creating, updating, and voting on 
/// BIM models
contract CollaborativeBIM is ERC721, AccessControl {


    // State variables
    // ========================================================================

    /// @notice Hashed value representing the "Model Updater Role".
    /// @dev This constant is used for role-based access control in the contract.
    /// The actual role is hashed from the string "MODEL_UPDATER_ROLE" using the keccak256 function. 
    /// The value of this constant is used to manage permissions in the contract, specifically to control who can create and update models.
    /// In the context of this contract, a Model Updater is someone who has been granted permission to create and update BIM models.
    bytes32 public constant MODEL_UPDATER_ROLE = keccak256("MODEL_UPDATER_ROLE");

    /// @notice Counter for the unique IDs assigned to each BIM model in the contract.
    /// @dev This counter is used to assign a unique identifier to each new BIM model that is created.
    /// The value of modelCounter is incremented each time a new model is created, ensuring that each model has a unique ID.
    /// This is especially important because the model ID is used as the key to retrieve specific models from the mapping of all models.
    uint256 public modelCounter;



    // Structs
    // ========================================================================

    /// @dev The BIMModel struct represents a BIM (Building Information Modeling) model in the blockchain.
    /// @notice This struct contains information about a BIM model.
    /// @param name The name of the BIM model. This could be any string that uniquely identifies or describes the model.
    /// @param url The URL where the actual BIM model is hosted. This allows users to access and view the model.
    /// @param isComplete A boolean flag indicating whether the BIM model is complete or still under development.
    /// @param author The Ethereum address of the user who originally created the BIM model. This is used for access control and attribution purposes.
    struct BIMModel {
        string name;
        string url;
        bool isComplete;
        address author;
    }

    /// @dev The ProposedChange struct is used to track and manage changes proposed by users to a BIM model.
    /// @notice This struct contains information about a proposed change to a BIM model.
    /// @param modelId The unique identifier of the BIM model that this change proposal is associated with.
    /// @param name The proposed new name for the BIM model. 
    /// @param url The proposed new URL where the updated BIM model will be hosted.
    /// @param proposer The Ethereum address of the user who proposed this change.
    /// @param isApproved A boolean flag indicating whether the proposed change has been approved by the required majority of users.
    /// @param votes A mapping to track the votes for this proposed change. The addresses of users who voted for the change map to 'true'.
    /// @param voteCount The total count of votes in favor of the proposed change. This is used to determine whether the change has enough support to be approved.
    struct ProposedChange {
        uint256 modelId;
        string name;
        string url;
        address proposer;
        bool isApproved;
        mapping(address => bool) votes;
        uint256 voteCount;
    }


    // Constructor
    // ========================================================================

    /// @notice The constructor function that initializes the ERC721 contract with the given name and symbol
    /// It sets up the default admin role to the address that deploys the contract.
    /// @dev The constructor is called at the time of contract deployment. Here, it sets the name of the ERC721 token to "CollaborativeBIM" and its symbol to "BIM".
    /// This function also assigns the default admin role to the account that deploys the contract. This admin role is crucial for permissions management, and allows the initial account to manage roles for other accounts in the future.
    constructor() ERC721("CollaborativeBIM", "BIM") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }


    // Mappings
    // ========================================================================

    /// @notice A mapping to store all BIMModels by their unique identifiers
    /// Each model ID is mapped to a BIMModel structure containing all relevant
    /// details about the model.  This includes the name of the model, its URL,
    /// completion status, and the author's Ethereum address.
    /// The modelId is also the ERC721 token ID associated with the model, which allows for ownership tracking and transferability.
    /// This structure allows for efficient lookup of models by their IDs.
    mapping(uint256 => BIMModel) public bimModels;

    /// @notice A mapping that connects each BIM model to an array of proposed changes
    /// This data structure is used to keep track of all changes proposed by collaborators for a specific BIM model.
    /// The model's unique identifier (modelId) is used as the key to retrieve an array of ProposedChange structures.
    /// Each ProposedChange structure holds all the information regarding a proposed change: 
    /// its identifier, name, url, the Ethereum address of the proposer, its approval status and votes received.
    /// Using this structure, it is possible to retrieve all proposed changes associated with a specific model efficiently.
    mapping(uint256 => ProposedChange[]) public proposedChanges;



    // Events
    // ========================================================================

    /// @notice Event emitted when a new BIM model is created
    /// @param modelId The ID of the model
    /// @param name The name of the model
    /// @param url The URL where the model is stored
    /// @param author The address of the author of the model
    event ModelCreated(
        uint256 modelId,
        string name,
        string url,
        address author
    );

    /// @notice Event emitted when a BIM model is marked as completed
    /// @param modelId The ID of the model that was completed
    event ModelCompleted(
        uint256 modelId
    );

    /// @notice Event emitted when a change is proposed for a BIM model
    /// @param modelId The ID of the model proposed for change
    /// @param changeId The ID of the proposed change
    /// @param name The new proposed name of the model
    /// @param url The new proposed URL where the model will be stored
    /// @param proposer The address of the proposer of the change
    event ChangeProposed(
        uint256 modelId,
        uint256 changeId,
        string name,
        string url,
        address proposer
    );

    /// @notice Event emitted when a proposed change for a BIM model is approved
    /// @param modelId The ID of the model for which a change was approved
    /// @param changeId The ID of the change that was approved
    event ChangeApproved(
        uint256 modelId,
        uint256 changeId
    );

    /// @notice Event emitted when a vote is cast for a proposed change
    /// @param voter The address of the voter
    /// @param modelId The ID of the model for which a change was proposed
    /// @param changeId The ID of the proposed change that was voted on
    event VoteCast(
        address voter,
        uint256 modelId,
        uint256 changeId
    );


    // Methods
    // ========================================================================
    /// @notice This function allows for the creation of a new BIM (Building Information Modeling) model.
    /// @dev This function creates a new BIM model and mints an ERC721 token associated with it. 
    /// It increments the modelCounter each time a new model is created to ensure unique IDs for all models. 
    /// The newly created model is stored in the bimModels mapping, with the modelCounter as the key.
    /// Only an address with the MODEL_UPDATER_ROLE can call this function.
    /// After the BIM model is created, a 'ModelCreated' event is emitted.
    /// @param _name The name of the new BIM model.
    /// @param _url The URL where the new BIM model is located.
    /// @requires Caller must have MODEL_UPDATER_ROLE.
    /// @emit ModelCreated This event is emitted with the modelCounter (modelId), name, url, and the address of the model author.
    function createModel(
        string memory _name,
        string memory _url
    ) public {
        require(
            hasRole(MODEL_UPDATER_ROLE, msg.sender),
            "Caller is not a model updater"
        );

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


    /// @notice This function marks a BIM (Building Information Modeling) model as complete.
    /// @dev This function sets the `isComplete` attribute of the BIMModel struct instance to `true`.
    /// It requires the caller to have the DEFAULT_ADMIN_ROLE, typically assigned to the contract deployer. 
    /// A 'ModelCompleted' event is emitted after the model is marked as complete.
    /// @param _modelId The unique identifier of the BIM model to be marked as complete. This ID must exist in the bimModels mapping.
    /// @requires The caller must have DEFAULT_ADMIN_ROLE and the BIM model with the given modelId must exist.
    /// @emit ModelCompleted This event is emitted with the modelId of the completed model.
    function completeModel(
        uint256 _modelId
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            _exists(_modelId),
            "ERC721: operator query for nonexistent token"
        );

        BIMModel storage model = bimModels[_modelId];
        model.isComplete = true;

        emit ModelCompleted(_modelId);
    }

    /// @notice This function returns the details of a BIM (Building Information Modeling) model.
    /// @dev This function fetches the details of a BIM model by its ID from the bimModels mapping.
    /// It requires the modelId to exist in the mapping. 
    /// @param _modelId The unique identifier of the BIM model to be fetched.
    /// @return name The name of the BIM model.
    /// @return url The URL where the BIM model is located.
    /// @return isComplete Flag indicating whether the BIM model is complete.
    /// @return author The address of the BIM model's author.
    /// @requires The BIM model with the given modelId must exist.
    function getModel(
        uint256 _modelId
    ) public view returns (
        string memory name,
        string memory url,
        bool isComplete,
        address author
    ) {
        require(
            _exists(_modelId),
            "ERC721: operator query for nonexistent token"
        );

        BIMModel storage model = bimModels[_modelId];

        return (model.name, model.url, model.isComplete, model.author);
    }

    /// @notice This function allows a user to propose a change to an existing BIM model.
    /// @dev This function creates a new ProposedChange struct instance and adds it to the proposedChanges mapping. 
    /// A 'ChangeProposed' event is emitted after the change is proposed.
    /// The proposed change will contain the new name and URL of the model.
    /// @param _modelId The unique identifier of the BIM model to be changed.
    /// @param _name The new name proposed for the BIM model.
    /// @param _url The new URL proposed for the BIM model.
    /// @requires The BIM model with the given modelId must exist.
    /// @emit ChangeProposed This event is emitted with the modelId, changeId (derived from the array length - 1), new name, new url, and the address of the proposer.
    function proposeChange(
        uint256 _modelId,
        string memory _name,
        string memory _url
    ) public {
        require(
            _exists(_modelId),
            "ERC721: operator query for nonexistent token"
        );

        ProposedChange memory change = ProposedChange({
            modelId: _modelId,
            name: _name,
            url: _url,
            proposer: msg.sender,
            isApproved: false,
            voteCount: 0
        });

        proposedChanges[_modelId].push(change);

        emit ChangeProposed(
            _modelId, proposedChanges[_modelId].length - 1,
            _name,
            _url, msg.sender
        );
    }
    /// @notice This function allows a model owner or an approved account to vote on a proposed change.
    /// @dev This function enables voting on a proposed change by first verifying that the model ID exists,
    /// and the caller is either the owner or an approved account.
    /// Each account can only vote once on a proposed change.
    /// @param _modelId The unique identifier of the BIM model where the change is proposed.
    /// @param _changeId The unique identifier of the proposed change to vote on.
    /// @requires The BIM model with the given modelId must exist.
    /// @requires The caller must be the owner or an approved account.
    /// @requires The caller has not already voted on this change.
    /// @emit VoteCast This event is emitted with the address of the voter, the modelId and the changeId.
    function voteChange(
        uint256 _modelId,
        uint256 _changeId
    ) public {
        require(
            _exists(_modelId),
            "ERC721: operator query for nonexistent token"
        );
        require(
            _isApprovedOrOwner(msg.sender, _modelId),
            "Caller is not owner nor approved"
        );

        ProposedChange storage change = proposedChanges[_modelId][_changeId];
        require(!change.votes[msg.sender], "Caller has already voted");

        change.votes[msg.sender] = true;
        change.voteCount++;

        emit VoteCast(msg.sender, _modelId, _changeId);
    }

    /// @notice This function allows an admin to approve a proposed change if it received more than half of total votes.
    /// @dev This function approves a proposed change by first verifying that the model ID exists,
    /// and the proposed change received more than half of total votes.
    /// It then applies the change to the BIM model by updating the model's name and URL.
    /// @param _modelId The unique identifier of the BIM model where the change is proposed.
    /// @param _changeId The unique identifier of the proposed change to be approved.
    /// @requires The BIM model with the given modelId must exist.
    /// @requires The proposed change must have received more than half of total votes.
    /// @emit ChangeApproved This event is emitted with the modelId and the changeId.
    function approveChange(
        uint256 _modelId,
        uint256 _changeId
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            _exists(_modelId),
            "ERC721: operator query for nonexistent token"
        );

        ProposedChange storage change = proposedChanges[_modelId][_changeId];
        require(change.voteCount > totalSupply() / 2, "Not enough votes");

        change.isApproved = true;

        BIMModel storage model = bimModels[_modelId];
        model.name = change.name;
        model.url = change.url;

        emit ChangeApproved(_modelId, _changeId);
    }


}
