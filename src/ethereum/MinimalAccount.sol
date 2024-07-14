// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAccount} from "../../lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "../../lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {MessageHashUtils} from "../../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "../../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED,SIG_VALIDATION_SUCCESS} from "../../lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "../../lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

// entrypoint is this contract
contract MinimalAccount is IAccount,Ownable {
    IEntryPoint private immutable i_entryPoint;
    
    constructor(address entrypoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entrypoint);
    }

    receive() external payable{}

    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    error MinimalAccount__CallFailed(bytes);

/*////////////////////////////////////////////////////////////////////////////*/
/*                              MODIFIERS                                     */
/*////////////////////////////////////////////////////////////////////////////*/

    modifier requireFromEntryPoint() {
        if(msg.sender != address(i_entryPoint)){
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }

    modifier requireFromEntryPointOrOwner() {
        if(msg.sender != address(i_entryPoint) && msg.sender != owner()){
            revert MinimalAccount__NotFromEntryPointOrOwner();
        }
        _;
    }


/*////////////////////////////////////////////////////////////////////////////*/
/*                              EXTERNAL FUNCTIONS                             */
/*////////////////////////////////////////////////////////////////////////////*/

    function execute(address dest,uint256 value,bytes calldata functionData) external requireFromEntryPointOrOwner {
        (bool success, bytes memory result) = dest.call{value: value}(functionData);
        if(!success) {
            revert MinimalAccount__CallFailed(result);
        } 
        
    }

    
    function validateUserOp(PackedUserOperation calldata userOp,bytes32 userOpHash,uint256 missingAccountFunds) 
        external returns (uint256 validationData) {
            // A signature is valid, if it's the MinimalAccount owner whoever deploys it
            validationData = _validateSignature(userOp, userOpHash);
            _payPrefund(missingAccountFunds);
    }

/*////////////////////////////////////////////////////////////////////////////*/
/*                              INTERNAL FUNCTIONS                             */
/*////////////////////////////////////////////////////////////////////////////*/

    // EIP-191 version of the signed hash
    function _validateSignature(PackedUserOperation calldata userOp,bytes32 userOpHash) internal view returns (uint256 validationData) {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;   // 1
        }
        return SIG_VALIDATION_SUCCESS;      // 0
        
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        if(missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds,gas: type(uint256).max}("");
            (success);
        }
    }


    /*////////////////////////////////////////////////////////////////////////////*/
    /*                                    GETTERS                                  */
    /*////////////////////////////////////////////////////////////////////////////*/

    function getEntryPoint() external view returns (address) {
        return (address(i_entryPoint));
    }
}
