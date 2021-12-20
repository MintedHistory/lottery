// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/safemath.sol";

contract LotteryStake is Ownable {
    using SafeMath for uint256;

    IERC20 public fungibleToken;
    IERC721 public nonFungibleToken;
    bool _initialized;

    struct Staker {
        uint256[] tokenIds;
    }

    mapping (address => Staker) stakers;
    mapping (uint256 => address) public tokenOwner;

    event Staked(address owner, uint256 amount);
    event Unstaked(address owner, uint256 amount);

    function initialize(
        IERC20 _fungibleToken,
        IERC721 _nonFungibleToken) external onlyOwner {
        require(!_initialized, "Already initialized");
        _initialized = true;
        fungibleToken = _fungibleToken;
        nonFungibleToken = _nonFungibleToken;
    }

    function _stake(
        address _user,
        uint256 _tokenId
    )
        internal
    {
        Staker storage staker = stakers[_user];

        staker.tokenIds.push(_tokenId);
        tokenOwner[_tokenId] = _user;
        nonFungibleToken.safeTransferFrom(
            _user,
            address(this),
            _tokenId
        );

        emit Staked(_user, _tokenId);
    }
}