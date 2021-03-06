/**
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

pragma solidity ^0.6.0;

interface IManagerInit {
    function initialize(
        address ownerAddress,
        address tokenAddress,
        uint256 minimum,
        uint256 burning
    ) external;
}
