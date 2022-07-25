// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Contract that enables a single call to call multiple methods on itself.
/// @author Modified from Solady (https://github.com/Vectorized/solady/blob/main/src/utils/Multicallable.sol)
abstract contract Multicallable {
    function multicall(bytes[] calldata data) public payable virtual returns (bytes[] memory results) {
        assembly {
            if data.length {
                results := mload(0x40) // point `results` to start of free memory
                mstore(results, data.length) // store `data.length` into `results`
                results := add(results, 0x20)

                // `shl` 5 is equivalent to multiplying by 0x20
                let end := shl(5, data.length)
                // copy the offsets from calldata into memory
                calldatacopy(results, data.offset, end)
                // pointer to the top of the memory (i.e., start of the free memory)
                let memPtr := add(results, end)
                end := add(results, end)

                for {} 1 {} {
                    // the offset of the current bytes in the calldata
                    let o := add(data.offset, mload(results))
                    
                    // copy the current bytes from calldata to the memory
                    calldatacopy(
                        memPtr,
                        add(o, 0x20), // the offset of the current bytes' bytes
                        calldataload(o) // the length of the current bytes
                    )
                    
                    if iszero(delegatecall(gas(), address(), memPtr, calldataload(o), 0x00, 0x00)) {
                        // bubble up the revert if the delegatecall reverts
                        returndatacopy(0x00, 0x00, returndatasize())
                        revert(0x00, returndatasize())
                    }
                    
                    // append the current `memPtr` into `results`
                    mstore(results, memPtr)
                    results := add(results, 0x20)
                    // append the `returndatasize()`, and the return data
                    mstore(memPtr, returndatasize())
                    returndatacopy(add(memPtr, 0x20), 0x00, returndatasize())
                    // advance the `memPtr` by `returndatasize() + 0x20`,
                    // rounded up to the next multiple of 32
                    memPtr := and(add(add(memPtr, returndatasize()), 0x3f), 0xffffffffffffffe0)

                    if iszero(lt(results, end)) { break }
                }
                
                // restore `results` and allocate memory for it
                results := mload(0x40)
                mstore(0x40, memPtr)
            }
        }
    }
}
