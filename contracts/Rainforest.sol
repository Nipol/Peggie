// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.6.0;

import "./Library/Authority.sol";
import "./Library/Create2Maker.sol";
import "./Interface/IERC173.sol";
import "./Interface/ICage.sol";
import "./Interface/IWETH.sol";
import "./Interface/IERC20.sol";
import "./Interface/ITokenFactory.sol";
import "./Interface/IERC721Metadata.sol";

contract Rainforest is Authority {
    address private tokenFactory;
    bytes32 private tokenTemplateKey;
    address public commitToken;
    address public cageTemplate;
    address public houseTemplate;
    address public WETH;

    // getCage(nft address, id) -> cage address
    mapping(address => mapping(uint256 => address)) public getCage;

    event DeployedCage(
        address indexed nft,
        uint256 indexed id,
        address indexed cage
    );

    constructor(
        address commit,
        address cage,
        address house,
        address weth,
        address tokenFac,
        bytes32 templateKey
    ) public {
        Authority.initialize(msg.sender);
        commitToken = commit;
        cageTemplate = cage;
        houseTemplate = house;
        WETH = weth;
        tokenFactory = tokenFac;
        tokenTemplateKey = templateKey;
    }

    function newCage(address nft, uint256 tokenId) external payable {
        IWETH(WETH).deposit{value: msg.value}();
        IERC20(WETH).approve(tokenFactory, uint256(-1));

        string memory tokenName =
            string(
                abi.encodePacked(
                    "Peggie ",
                    IERC721Metadata(nft).name(),
                    string(abi.encode(tokenId))
                )
            );
        string memory tokenSymbol =
            string(
                abi.encodePacked(
                    "p",
                    IERC721Metadata(nft).symbol(),
                    string(abi.encode(tokenId))
                )
            );

        // 토큰 발행
        address lp = ITokenFactory(tokenFactory).newToken(
            tokenTemplateKey,
            "1",
            tokenName,
            tokenSymbol,
            18
        );

        // 가치평가를 위한 케이지 생성
        address cage = _newCage(commitToken, nft, tokenId, houseTemplate, lp);
        // 가치평가에서 사용될 lp토큰의 오너쉽을 케이지로 이전
        IERC173(lp).transferOwnership(cage);

        // 케이지 배포됨
        emit DeployedCage(nft, tokenId, cage);
    }

    function _newCage(
        address token,
        address nft,
        uint256 id,
        address house,
        address lp
    ) internal returns (address result) {
        bytes memory initializationCalldata =
            abi.encodeWithSelector(
                ICage(cageTemplate).initialize.selector,
                token,
                nft,
                id,
                house,
                lp
            );

        bytes memory create2Code =
            abi.encodePacked(
                type(Create2Maker).creationCode,
                abi.encode(address(cageTemplate), initializationCalldata)
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
