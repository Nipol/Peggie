// NFT approve, pre-auction, phase
// NFT 정보 표출
// making - phase 0
// Strategy Highest Price, Average

// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.6.0;

import "./Library/SafeMath.sol";
import "./Interface/IERC721.sol";
import "./Interface/IERC721Metadata.sol";
import "./Interface/ERC721TokenReceiver.sol";
import {AbstractInitializer} from "./abstract/Initializer.sol";
import "./StandardToken.sol";

contract Cage is AbstractInitializer, ERC721TokenReceiver, StandardToken {
    using SafeMath for uint256;
    address nft;
    uint256 id;
    address token;
    address nftOwner;
    address house;

    uint256 public latestPrice;
    uint256 public period;

    // Inactive, 기간이 설정되지 않았을 때
    // Progressing, 기간이 설정되면 commit을 받을 수 있는 상태
    enum State {Inactive, Progressing, Finished, Deposited, Started, Ended}
    State public status;

    function initialize(
        address commitToken,
        address nftAddress,
        uint256 tokenId
    ) external initializer {
        string tname = string(
            abi.encodePacked(
                "Peggie ",
                IERC721Metadata(nftAddress).name(),
                string(tokenId)
            )
        );
        string tsymbol = string(
            abi.encodePacked(
                "p",
                IERC721Metadata(nftAddress).symbol(),
                string(tokenId)
            )
        );
        StandardToken.initialize("1", tname, tsymbol, 18);
        status = State.Inactive;
    }

    modifier onlyStaker() {
        require(nftOwner == msg.sender, "Cage/Your Not NFT Owner");
        _;
    }

    /// NFT를 예치해야 자산 평가단들이 Commit을 할 수 있도록… @TODO: 거버넌스가 Commit 할 수 있는 최대 기간을 period로 입력함.
    function stake(uint256 duration) external {
        require(
            IERC721(nft).safeTransferFrom(msg.sender, address(this), id),
            "Cage/Not-Approved"
        );
        nftOwner = msg.sender;
        status = State.Progressing;
        latestPrice = 0;
        // @TODO: Maximum duration from governance
        period = block.timestamp.add(duration);
    }

    /// 자산 평가단들이 지정된 토큰의 값만 입력해서 커밋함.계속 최대 금액만 입력할 수 있음.
    /// 커밋한 증거로, 커밋 금액과 동일한 토큰을 발행함.
    function commit(uint256 amount) external {
        require(status == State.Progressing, "Cage/NFT is not staked");
        require(amount > latestPrice, "Cage/lowest price");
        require(
            IERC20(token).transferFrom(msg.sender, address(this), amount),
            "Cage/not approved"
        );
        latestPrice = amount;
        // 토큰 생성
        mint(amount);
        // 토큰 전송
        transfer(msg.sender, amount);
        // 만약 토큰 소각을 하지 않으면,
    }

    /// 지정된 기간이 지나면 Commit 그만 받도록 함.
    function finish() external {
        require(
            status == State.Progressing && period <= block.timestamp,
            "Cage/NFT is not staked"
        );
        status = State.Finished;
    }

    /// commit 끝나면, 보험료 납부 지금은 5%
    function depositCover() external onlyStaker {
        require(status == State.Finished, "Cage/Pre-Auction is Not Ended");
        uint256 amount = coverPrice();
        require(IERC20(token).transferFrom(msg.sender, address(this), amount));
        status = State.Deposited;
    }

    /// NFT를 팔기 위한 자체 옥션 시작
    /// Auction 배포, NFT 옥션으로 전송
    function startAuction() external {
        require(status == State.Deposited, "Cage/Not Deposited");
        status = State.Started;
        // auction 배포
    }

    // Auction 에서 돈 받기 및 정산
    function closeAuction() external {
        // 배포된 옥션에서 close 호출
        status = State.Ended;
    }

    /// 총 커밋된 토큰의 수량
    function totalCommited() external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /// 실시간 보험료
    function coverPrice() external view returns (uint256) {
        // 5%
        return IERC20(token).balanceOf(address(this)).div(10000).mul(500);
    }

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes _data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
