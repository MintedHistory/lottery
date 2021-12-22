// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/safemath.sol";

interface IFungibleToken is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract LotteryStake is Ownable {
    
    using SafeMath for uint8;
    using SafeMath for uint256;

    struct Lottery {
        uint8 month;
        uint16 year;
        mapping(address => uint) points; 
    }
    
    mapping (uint => uint) checkpoints;     //tokenId => timestamp
    mapping (uint => address) deposits;     //tokenId => address

    IFungibleToken public fungibleToken;
    IERC721 public nonFungibleToken;
    uint public nftSupply;

    uint constant DAY = 86400;
    uint constant DAILY_TOKEN_REWARD = 1;

    uint8 constant E1_MULTIPLIER = 2;
    uint8 constant E2_MULTIPLIER = 1;
    uint8 constant S1 = 1;
    uint8 constant S2 = 2;
    uint8 constant S3 = 4;
    uint8 constant S4 = 8;
    
    constructor(
        address _fungibleToken,
        address _nonFungibleToken,
        uint _nftSupply
    )   
    {
        fungibleToken = IFungibleToken(_fungibleToken);
        nonFungibleToken = IERC721(_nonFungibleToken);
        nftSupply = _nftSupply;
    }

    function awardPoints(address recipient, uint256 points) internal {
        
    }

    function awardToken(address recipient) internal {
        fungibleToken.mint(recipient, DAILY_TOKEN_REWARD * (uint256(10) ** 18));
    }

    function deposit(uint tokenId) external {
        require(msg.sender == nonFungibleToken.ownerOf(tokenId), "You are not the owner of this token");
        nonFungibleToken.transferFrom(msg.sender, address(this), tokenId);
        deposits[tokenId] = msg.sender;
        checkpoints[tokenId] = block.timestamp;
    }

    function reward(
        uint[] memory s4e1, 
        uint[] memory s3e1, 
        uint[] memory s2e1,
        uint[] memory s1e1,
        uint[] memory s4e2, 
        uint[] memory s3e2, 
        uint[] memory s2e2,
        uint[] memory s1e2
    ) external onlyOwner {
            for (uint x = 0; x < nftSupply; x++) {
                if (deposits[x] != address(0)) {
                    
                    //confirm that staked longer than a day
                    if (checkpoints[x] < block.timestamp.sub(DAY)) {

                        //4 star - edition 1
                        for (uint s = 0; s < s4e1.length; s++) {
                            if (x == s4e1[s]) {
                                awardPoints(deposits[x], E1_MULTIPLIER.mul(S4));
                                awardToken(deposits[x]);
                                break;
                            }
                        }

                        //3 star - edition 1
                        for (uint s = 0; s < s3e1.length; s++) {
                            if (x == s3e1[s]) {
                                awardPoints(deposits[x], E1_MULTIPLIER.mul(S3));
                                awardToken(deposits[x]);
                                break;
                            }
                        }

                        //2 star - edition 1
                        for (uint s = 0; s < s2e1.length; s++) {
                            if (x == s2e1[s]) {
                                awardPoints(deposits[x], E1_MULTIPLIER.mul(S2));
                                awardToken(deposits[x]);
                                break;
                            }
                        }

                        //1 star - edition 1
                        for (uint s = 0; s < s1e1.length; s++) {
                            if (x == s1e1[s]) {
                                awardPoints(deposits[x], E1_MULTIPLIER.mul(S1));
                                awardToken(deposits[x]);
                                break;
                            }
                        }

                        //4 star - edition 2
                        for (uint s = 0; s < s4e2.length; s++) {
                            if (x == s4e2[s]) {
                                awardPoints(deposits[x], E2_MULTIPLIER.mul(S4));
                                awardToken(deposits[x]);
                                break;
                            }
                        }

                        //3 star - edition 2
                        for (uint s = 0; s < s3e2.length; s++) {
                            if (x == s3e2[s]) {
                                awardPoints(deposits[x], E2_MULTIPLIER.mul(S3));
                                awardToken(deposits[x]);
                                break;
                            }
                        }

                        //2 star - edition 2
                        for (uint s = 0; s < s2e2.length; s++) {
                            if (x == s2e2[s]) {
                                awardPoints(deposits[x], E2_MULTIPLIER.mul(S2));
                                awardToken(deposits[x]);
                                break;
                            }
                        }

                        //1 star - edition 2
                        for (uint s = 0; s < s1e2.length; s++) {
                            if (x == s1e2[s]) {
                                awardPoints(deposits[x], E2_MULTIPLIER.mul(S1));
                                awardToken(deposits[x]);
                                break;
                            }
                        }
                    }
                }
            }
    }

    function withdraw(uint tokenId) external {
        require(deposits[tokenId] == msg.sender, "You did not stake this token");
        nonFungibleToken.transferFrom(address(this), msg.sender, tokenId);
        delete deposits[tokenId];
        delete checkpoints[tokenId];
        //** Remove user points from latest lottery */
    }
}