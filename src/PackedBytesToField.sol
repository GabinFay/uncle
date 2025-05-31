// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Extension for abi.encodePacked(...).hashToField()
library PackedBytesToField {
    uint256 internal constant SNARK_SCALAR_FIELD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    
    /**
     * @dev Hashes the input data using keccak256 and then maps it to the SNARK scalar field.
     * @param data The data to hash.
     * @return The field element representation of the hash.
     */
    function hashToField(bytes memory data) internal pure returns (uint256) {
        return uint256(keccak256(data)) % SNARK_SCALAR_FIELD;
    }
} 