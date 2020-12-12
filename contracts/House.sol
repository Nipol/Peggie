// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.6.0;

import "./Library/SafeMath.sol";
import "./Interface/IBurn.sol";
import "./Interface/IERC20.sol";
import "./Interface/IERC721.sol";
import "./Interface/ERC721TokenReceiver.sol";
import "./Interface/IHouse.sol";
import {AbstractInitializer} from "./abstract/Initializer.sol";

contract House is ERC721TokenReceiver, AbstractInitializer, IHouse {
    using SafeMath for uint256;

    address cage;
    address latestCommitter;
    uint256 latestprice;
    uint256 period;

    address lp;
    address token;
    address nft;
    uint256 tokenId;

    enum State {Active, Close}
    State public status;

    // 바로 시작됨
    function initialize(
        address lpToken,
        address commitToken,
        address delegatedNFT,
        uint256 Id,
        uint256 duration
    ) external override initializer {
        lp = lpToken;
        token = commitToken;
        nft = delegatedNFT;
        tokenId = Id;
        period = block.timestamp.add(duration);
        cage = msg.sender;
        latestCommitter = address(0);
    }

    //@TODO: percentage bidding
    //@TODO: adding last duration.
    function bid(uint256 amount) external {
        require(period > block.timestamp, "House/Bidding Time End");
        require(status == State.Active, "House/Auction Not started");
        require(amount > latestprice, "House/Amount is Not Highest");
        require(
            IERC20(token).transferFrom(msg.sender, address(this), amount),
            "House/Not Approved"
        );
        IERC20(token).transfer(latestCommitter, latestprice);
        latestCommitter = msg.sender;
        latestprice = amount;
    }

    function close() external override returns (uint256 result) {
        require(msg.sender == cage, "House/Caller is not Cage");
        require(period < block.timestamp, "House/Times up");
        require(status == State.Active, "House/Only Withdraw Mode");
        result = latestprice;
        // NFT 입찰자에게 전송
        IERC721(nft).transferFrom(address(this), latestCommitter, tokenId);
        // 입찰가 Cage로 전송 및 정산
        IERC20(token).transfer(msg.sender, result);
        status = State.Close;
    }

    // 하우스가 닫힌 이후에 LP를 소각하고 예치된 금액을 비율에 맞게 소각함.
    function withdraw(uint256 amount) external {
        require(status == State.Close, "House/is Not closed");
        uint256 total = IERC20(lp).totalSupply().mul(1e18);
        uint256 ratio = 1e18;
        if (total != amount) {
            // 1e18 = 1e36 / 1e18
            ratio = total.div(amount);
        }
        // 소각할 LP 받기
        require(
            IERC20(lp).transferFrom(msg.sender, address(this), amount),
            "House/Not Approved"
        );
        // 받은 LP 소각
        require(IBurn(lp).burn(amount), "House/Something Wrong");
        // House가 가지고 있는 모든 금액을 가져옴.
        uint256 balance = IERC20(token).balanceOf(address(this));
        // 모든 금액에서 ratio를 곱하고, ((1e18 * 1e18) / 1e18) = 1e18;
        uint256 withdrawable = balance.mul(ratio).div(1e18);
        // 토큰 전송
        IERC20(token).transfer(msg.sender, withdrawable);
    }

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes memory _data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
