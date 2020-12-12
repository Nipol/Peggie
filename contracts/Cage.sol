// NFT approve, pre-auction, phase
// NFT 정보 표출
// making - phase 0
// Strategy Highest Price, Average

// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.6.0;

import "./Library/SafeMath.sol";
import "./Library/Create2Maker.sol";
import "./Interface/IMint.sol";
import "./Interface/IERC20.sol";
import "./Interface/IERC173.sol";
import "./Interface/IERC721.sol";
import "./Interface/IERC721Metadata.sol";
import "./Interface/ERC721TokenReceiver.sol";
import "./Interface/IHouse.sol";
import {AbstractInitializer} from "./abstract/Initializer.sol";

contract Cage is AbstractInitializer, ERC721TokenReceiver {
    using SafeMath for uint256;

    address public token;
    address public nft;
    uint256 public id;
    address public lptoken;
    address public nftOwner;
    address public house;
    address public houseTemplate;

    uint256 public latestPrice;
    uint256 public period;

    // Inactive, 기간이 설정되지 않았을 때
    // Progressing, 기간이 설정되면 commit을 받을 수 있는 상태
    enum State {Inactive, Progressing, Finished, Deposited, Ended}
    State public status;

    event DeployedHouse(address cage, address house);

    // 토큰 rainforest에서 만들어 줄 예정.
    function initialize(
        address commitToken,
        address nftAddress,
        uint256 tokenId,
        address template,
        address lp
    ) external initializer {
        token = commitToken;
        nft = nftAddress;
        id = tokenId;
        houseTemplate = template;
        lptoken = lp;
        status = State.Inactive;
    }

    modifier onlyStaker() {
        require(nftOwner == msg.sender, "Cage/Your Not NFT Owner");
        _;
    }

    // NFT를 예치해야 자산 평가단들이 Commit을 할 수 있도록…
    // @TODO: 거버넌스가 Commit 할 수 있는 최대 기간을 period로 입력함.
    function stake(uint256 duration) external {
        IERC721(nft).safeTransferFrom(msg.sender, address(this), id);
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
        // 토큰 생성 및 전송
        IMint(lptoken).mintTo(amount, msg.sender);
    }

    /// 지정된 기간이 지나면 Commit 그만 받도록 설정,
    function finish() external {
        require(
            status == State.Progressing && period <= block.timestamp,
            "Cage/NFT is not staked"
        );
        status = State.Finished;
    }

    /// commit 끝나 Finished 상태가 되면, 보험금을 납부할 수 있게되며
    /// 보험금을 납부 하자마자, 옥션이 시작되도록 함
    function depositCover(uint256 duration) external onlyStaker {
        require(status == State.Finished, "Cage/Pre-Auction is Not Ended");
        // 계산된 보험료 좀 더 합리적인 방식으로 계산할 필요가 있음.
        // 보험료 가져오기
        uint256 amount = this.coverPrice();
        // 보험료를 Cage로 가져옴
        require(IERC20(token).transferFrom(msg.sender, address(this), amount));
        // 옥션 배포
        house = _newHouse(duration);
        // 배포된 옥션에 NFT 전송
        IERC721(nft).transferFrom(address(this), house, id);
        // 옥션으로 LP 토큰의 권한 전송
        IERC173(lptoken).transferOwnership(house);
        status = State.Deposited;
        emit DeployedHouse(address(this), house);
    }

    // Auction 에서 돈 받기 및 정산
    function closeHouse() external {
        // 배포된 하우스에서 close 호출
        // 이때, 낙찰 금액도 Cage로 전송됨.
        uint256 finalPrice = IHouse(house).close();

        // 낙찰 가격이 Latest Price보다 높거나 같은 경우
        // 낙찰 가격을 그대로 전송한다.
        // 낙찰 가격이 latest price보다 낮은 경우
        // 마지막 커밋된 금액을 전송한다.
        if (finalPrice >= latestPrice) {
            IERC20(token).transfer(nftOwner, finalPrice);
        } else {
            IERC20(token).transfer(nftOwner, latestPrice);
        }
        // 이후에 남은 모든 토큰 금액을 House로 전송하여 House에서 잔여 자산을 나눠서 Claim할 수 있도록 함.
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(house, balance);
        status = State.Inactive;
        house = address(0);
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
        bytes memory _data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function _newHouse(uint256 duration) internal returns (address result) {
        bytes memory initializationCalldata =
            abi.encodeWithSelector(
                IHouse(houseTemplate).initialize.selector,
                token,
                nft,
                id,
                duration
            );

        bytes memory create2Code =
            abi.encodePacked(
                type(Create2Maker).creationCode,
                abi.encode(address(houseTemplate), initializationCalldata)
            );

        (bytes32 salt, ) = _getSaltAndTarget(create2Code);

        // solhint-disable-next-line no-inline-assembly
        assembly {
            let encoded_data := add(0x20, create2Code) // load initialization code.
            let encoded_size := mload(create2Code) // load the init code's length.
            result := create2(
                // call `CREATE2` w/ 4 arguments.
                0, // forward any supplied endowment.
                encoded_data, // pass in initialization code.
                encoded_size, // pass in init code's length.
                salt // pass in the salt value.
            )

            // pass along failure message from failed contract deployment and revert.
            if iszero(result) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function _getSaltAndTarget(bytes memory initCode)
        private
        view
        returns (bytes32 salt, address target)
    {
        // get the keccak256 hash of the init code for address derivation.
        bytes32 initCodeHash = keccak256(initCode);

        // set the initial nonce to be provided when constructing the salt.
        uint256 nonce = 0;

        // declare variable for code size of derived address.
        bool exist;

        while (true) {
            // derive `CREATE2` salt using `msg.sender` and nonce.
            salt = keccak256(abi.encodePacked(msg.sender, nonce));

            target = address( // derive the target deployment address.
                uint160( // downcast to match the address type.
                    uint256( // cast to uint to truncate upper digits.
                        keccak256( // compute CREATE2 hash using 4 inputs.
                            abi.encodePacked( // pack all inputs to the hash together.
                                bytes1(0xff), // pass in the control character.
                                address(this), // pass in the address of this contract.
                                salt, // pass in the salt from above.
                                initCodeHash // pass in hash of contract creation code.
                            )
                        )
                    )
                )
            );

            // determine if a contract is already deployed to the target address.
            // solhint-disable-next-line no-inline-assembly
            assembly {
                exist := gt(extcodesize(target), 0)
            }

            // exit the loop if no contract is deployed to the target address.
            if (!exist) {
                break;
            }

            // otherwise, increment the nonce and derive a new salt.
            nonce++;
        }
    }
}
