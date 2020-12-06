// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.6.0;

import "./Interface/IERC20.sol";
import "./Interface/IERC721.sol";
import "./Interface/ERC721TokenReceiver.sol";
import {AbstractInitializer} from "./abstract/Initializer.sol";

contract House is ERC721TokenReceiver, AbstractInitializer {
    address cage;
    address latestCommitter;
    uint256 price;
    uint256 period;

    address token;
    address nft;
    uint256 tokenId;

    enum State {Inactive, Active}
    State public status;

    function initialize(
        address commitToken,
        address delegatedNFT,
        uint256 Id,
        uint256 duration
    ) external initializer {
        cage = msg.sender;
        token = commitERC20;
        nft = delegatedNFT;
        tokenId = Id;
        period = block.timestamp.add(duration);
        latestCommitter = address(0);
    }

    function bid(uint256 amount) external {
        require(period > block.timestamp, "House/Bidding Time End");
        require(status == State.Active, "House/Auction Not started");
        require(amount > price, "House/Price is Not Highest");
        require(
            IERC20(token).transferFrom(msg.sender, address(this), amount),
            "House/Not Approved"
        );
        IERC20(token).transfer(latestCommitter, price);
        latestCommitter = msg.sender;
        price = amount;
    }

    function close() external returns (uint256 result) {
        require(msg.sender == cage, "House/Caller is not Cage");
        require(period < block.timestamp, "House/Times up");
        require(status == State.Active, "House/Auction Not started");
        status = State.Inactive;
        result = price;
        IERC721(nft).transferFrom(address(this), latestCommitter, tokenId);
        IERC20(token).transfer(cage, price);
        period = 0;
        price = 0;
    }

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes _data
    ) external override returns (bytes4) {
        // 옥션이 이미 시작 중인지 확인
        require(status == State.Inactive, "House/Already Auction start");
        // 옥션 시작
        status = State.Active;
        return this.onERC721Received.selector;
    }
}
