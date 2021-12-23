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
    using SafeMath for uint16;
    using SafeMath for uint256;

    struct _DateTime {
        uint16 year;
        uint8 month;
        uint8 day;
        uint8 hour;
        uint8 minute;
        uint8 second;
        uint8 weekday;
    }

    struct Lottery {
        uint8 month;
        uint16 year;
        mapping(address => uint) points; 
    }
    
    mapping (uint => uint) checkpoints;     //tokenId => timestamp
    mapping (uint => address) deposits;     //tokenId => address
    mapping (uint => Lottery) lotteries;

    IFungibleToken public fungibleToken;
    IERC721 public nonFungibleToken;
    uint public nftSupply;

    uint constant DAY_IN_SECONDS = 86400;
    uint constant DAILY_TOKEN_REWARD = 1;
    uint8 constant E1_MULTIPLIER = 2;
    uint8 constant E2_MULTIPLIER = 1;
    uint constant LEAP_YEAR_IN_SECONDS = 31622400;
    uint16 constant ORIGIN_YEAR = 1970;
    uint8 constant S1 = 1;
    uint8 constant S2 = 2;
    uint8 constant S3 = 4;
    uint8 constant S4 = 8;
    uint constant YEAR_IN_SECONDS = 31536000;
    
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

    function awardPoints(Lottery storage lt, address recipient, uint256 points) internal {
        lt.points[recipient] += points;
    }

    function awardToken(address recipient) internal {
        fungibleToken.mint(recipient, DAILY_TOKEN_REWARD * (uint256(10) ** 18));
    }

    function currentLottery() internal view returns (Lottery storage lt) {
        uint time = block.timestamp;
        _DateTime memory dt = parseTimestamp(time);

        uint index = dt.year.mul(100).add(dt.month);

        lt = lotteries[index];
        
        return lt;
    }

    function deposit(uint tokenId) external {
        require(msg.sender == nonFungibleToken.ownerOf(tokenId), "You are not the owner of this token");
        nonFungibleToken.transferFrom(msg.sender, address(this), tokenId);
        deposits[tokenId] = msg.sender;
        checkpoints[tokenId] = block.timestamp;
    }

    function getDaysInMonth(uint8 month, uint16 year) public pure returns (uint8) {
        if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
            return 31;
        }
        else if (month == 4 || month == 6 || month == 9 || month == 11) {
            return 30;
        }
        else if (isLeapYear(year)) {
            return 29;
        }
        else {
            return 28;
        }
    }

    function getYear(uint timestamp) public pure returns (uint16) {
        uint secondsAccountedFor = 0;
        uint16 year;
        uint numLeapYears;

        // Year
        year = uint16(ORIGIN_YEAR + timestamp / YEAR_IN_SECONDS);
        numLeapYears = leapYearsBefore(year) - leapYearsBefore(ORIGIN_YEAR);

        secondsAccountedFor += LEAP_YEAR_IN_SECONDS * numLeapYears;
        secondsAccountedFor += YEAR_IN_SECONDS * (year - ORIGIN_YEAR - numLeapYears);

        while (secondsAccountedFor > timestamp) {
            if (isLeapYear(uint16(year - 1))) {
                secondsAccountedFor -= LEAP_YEAR_IN_SECONDS;
            }
            else {
                secondsAccountedFor -= YEAR_IN_SECONDS;
            }
            year -= 1;
        }
        return year;
    }

    function isLeapYear(uint16 year) public pure returns (bool) {
        if (year % 4 != 0) {
                return false;
        }
        if (year % 100 != 0) {
                return true;
        }
        if (year % 400 != 0) {
                return false;
        }
        return true;
    }

    function leapYearsBefore(uint year) public pure returns (uint) {
        year -= 1;
        return year / 4 - year / 100 + year / 400;
    }

    function parseTimestamp(uint timestamp) internal pure returns (_DateTime memory dt) {
        uint secondsAccountedFor = 0;
        uint buf;
        uint8 i;

        // Year
        dt.year = getYear(timestamp);
        buf = leapYearsBefore(dt.year) - leapYearsBefore(ORIGIN_YEAR);

        secondsAccountedFor += LEAP_YEAR_IN_SECONDS * buf;
        secondsAccountedFor += YEAR_IN_SECONDS * (dt.year - ORIGIN_YEAR - buf);

        // Month
        uint secondsInMonth;
        for (i = 1; i <= 12; i++) {
            secondsInMonth = DAY_IN_SECONDS * getDaysInMonth(i, dt.year);
            if (secondsInMonth + secondsAccountedFor > timestamp) {
                dt.month = i;
                break;
            }
            secondsAccountedFor += secondsInMonth;
        }

        // Day
        for (i = 1; i <= getDaysInMonth(dt.month, dt.year); i++) {
            if (DAY_IN_SECONDS + secondsAccountedFor > timestamp) {
                dt.day = i;
                break;
            }
            secondsAccountedFor += DAY_IN_SECONDS;
        }
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
        Lottery storage lt = currentLottery();
        
        for (uint x = 0; x < nftSupply; x++) {
            if (deposits[x] != address(0)) {
                
                //confirm that staked longer than a day
                if (checkpoints[x] < block.timestamp.sub(DAY_IN_SECONDS)) {

                    //4 star - edition 1
                    for (uint s = 0; s < s4e1.length; s++) {
                        if (x == s4e1[s]) {
                            awardPoints(lt, deposits[x], E1_MULTIPLIER.mul(S4));
                            break;
                        }
                    }

                    //3 star - edition 1
                    for (uint s = 0; s < s3e1.length; s++) {
                        if (x == s3e1[s]) {
                            awardPoints(lt, deposits[x], E1_MULTIPLIER.mul(S3));
                            break;
                        }
                    }

                    //2 star - edition 1
                    for (uint s = 0; s < s2e1.length; s++) {
                        if (x == s2e1[s]) {
                            awardPoints(lt, deposits[x], E1_MULTIPLIER.mul(S2));
                            break;
                        }
                    }

                    //1 star - edition 1
                    for (uint s = 0; s < s1e1.length; s++) {
                        if (x == s1e1[s]) {
                            awardPoints(lt, deposits[x], E1_MULTIPLIER.mul(S1));
                            break;
                        }
                    }

                    //4 star - edition 2
                    for (uint s = 0; s < s4e2.length; s++) {
                        if (x == s4e2[s]) {
                            awardPoints(lt, deposits[x], E2_MULTIPLIER.mul(S4));
                            break;
                        }
                    }

                    //3 star - edition 2
                    for (uint s = 0; s < s3e2.length; s++) {
                        if (x == s3e2[s]) {
                            awardPoints(lt, deposits[x], E2_MULTIPLIER.mul(S3));
                            break;
                        }
                    }

                    //2 star - edition 2
                    for (uint s = 0; s < s2e2.length; s++) {
                        if (x == s2e2[s]) {
                            awardPoints(lt, deposits[x], E2_MULTIPLIER.mul(S2));
                            break;
                        }
                    }

                    //1 star - edition 2
                    for (uint s = 0; s < s1e2.length; s++) {
                        if (x == s1e2[s]) {
                            awardPoints(lt, deposits[x], E2_MULTIPLIER.mul(S1));
                            break;
                        }
                    }

                    awardToken(deposits[x]);
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