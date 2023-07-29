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


import { ethers } from "hardhat";


/**
 * This function deploys the CollaborativeBIM contract to the chosen network.
 * @returns {Promise<void>}
 */
async function main(): Promise<void> {

    // Retrieve contract factory.
    // This uses the ethers.js library and the getContractFactory method from hardhat to create a ContractFactory for the CollaborativeBIM contract.
    const CollaborativeBIM = await ethers.getContractFactory("CollaborativeBIM");

    // Deploy contract.
    // The deploy method of the ContractFactory will start the deployment and return a Contract.
    // This Contract object represents the contract that will be deployed when the transaction it emitted gets included in a block.
    const collaborativeBIM = await CollaborativeBIM.deploy();
    
    // Wait for contract to be mined.
    // The deployed method of a Contract will wait until the transaction that deployed the contract gets mined and returns the same contract.
    await collaborativeBIM.deployed();

    // Log the address of the deployed contract.
    console.log("CollaborativeBIM contract deployed to:", collaborativeBIM.address);
  
}

// Call the main function and handle possible exceptions.
main()
    .then(() => process.exit(0)) // Exits the process after successful execution.
    .catch((error) => {
        console.error(error); // Log any errors that occurred.
        process.exit(1); // Exit the process with a non-zero status code to indicate that an error occurred.
    });
