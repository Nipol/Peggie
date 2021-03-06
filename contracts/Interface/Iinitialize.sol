// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.6.0;

interface Iinitialize {
    function initialize(
        string calldata contractVersion,
        string calldata tokenName,
        string calldata tokenSymbol,
        uint8 tokenDecimals
    ) external;
}
