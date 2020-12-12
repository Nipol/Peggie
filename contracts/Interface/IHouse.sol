// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.6.0;

interface IHouse {
    function initialize(
        address lpToken,
        address commitToken,
        address delegatedNFT,
        uint256 Id,
        uint256 duration
    ) external;

    function close() external returns (uint256 result);
}
