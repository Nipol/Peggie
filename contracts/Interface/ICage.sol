// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.6.0;

interface ICage {
    function initialize(
        address commitToken,
        address nftAddress,
        uint256 tokenId,
        address template,
        address lp
    ) external;
}
