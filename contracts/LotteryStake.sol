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

    struct Points {
        uint8 month;
        address participant;
        uint points;
        uint16 year;
    }

    struct Lottery {
        bool drawExecuted;
        address drawWinner;
        uint8 month;
        uint16 year;
    }

    mapping (uint => uint) public checkpoints;     //tokenId => timestamp
    mapping (uint => address) public deposits;     //tokenId => address
    mapping (uint => Lottery) public lotteries;
    Points[] public lotteryPoints;
    
    address[] tickets;

    IFungibleToken public fungibleToken;
    IERC721 public nonFungibleToken;
    uint public nftSupply;
    uint public secondsBeforeEarning;
    bool public stakingPaused;
    uint public stakedTokens;

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
    
    function initialize(
        address _fungibleToken,
        address _nonFungibleToken,
        uint _nftSupply,
        uint _secondsBeforeEarning
    ) onlyOwner external   
    {
        fungibleToken = IFungibleToken(_fungibleToken);
        nonFungibleToken = IERC721(_nonFungibleToken);
        nftSupply = _nftSupply;
        secondsBeforeEarning = _secondsBeforeEarning;
        stakingPaused = true;
    }

    function awardPoints(Lottery storage lt, address recipient, uint256 points) internal {
        Points storage val = lotteryPoints.push();
        val.month = lt.month;
        val.participant = recipient;
        val.points = points;
        val.year = lt.year;
    }

    function awardToken(address recipient) internal {
        fungibleToken.mint(recipient, DAILY_TOKEN_REWARD * (uint256(10) ** 18));
    }

    function bonusPoints(address recipient, uint points) external onlyOwner {
        Lottery storage lt = currentLottery();
        awardPoints(lt, recipient, points);
    }

    function currentLottery() internal returns (Lottery storage lt) {
        uint time = block.timestamp;
        _DateTime memory dt = parseTimestamp(time);

        uint index = dt.year.mul(100).add(dt.month);

        lt = lotteries[index];
        lt.year = dt.year;
        lt.month = dt.month;
        
        return lt;
    }

    function changeNftSupply(uint supply) external onlyOwner {
        nftSupply = supply;
    }

    function deposit(uint tokenId) external {
        require(stakingPaused == false, "Staking is currently paused");
        require(msg.sender == nonFungibleToken.ownerOf(tokenId), "You are not the owner of this token");
        nonFungibleToken.transferFrom(msg.sender, address(this), tokenId);
        deposits[tokenId] = msg.sender;
        checkpoints[tokenId] = block.timestamp;
        stakedTokens++;
    }

    function fundLottery() payable external {

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

    function getLotteryPoints(uint16 year, uint8 month) public view returns (Points[] memory) {
        uint count = 0;

        for (uint x = 0; x < lotteryPoints.length; x++) {
            if (lotteryPoints[x].month == month && lotteryPoints[x].year == year) {
                count++;
            }
        }
        
        Points[] memory points = new Points[](count);
        uint y = 0;

        for (uint x = 0; x < lotteryPoints.length; x++) {
            if (lotteryPoints[x].month == month && lotteryPoints[x].year == year) {
                points[y] = lotteryPoints[x];
                y++;
            }
        }

        return points;
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

    function payContractBalance(address payable winner) internal {
        winner.transfer(address(this).balance);
    }

    function random(uint max) public view returns (uint) {
        return uint(blockhash(block.number - 1)) % max;
    }

    function randomDraw(uint8 month, uint16 year) external onlyOwner returns (address) {
        uint index = year.mul(100).add(month);

        Lottery storage lt = lotteries[index];
        require(!lt.drawExecuted, "This lottery has already been drawn");
        delete tickets;

        for (uint x = 0; x < lotteryPoints.length; x++) {
            if (lotteryPoints[x].month == month && lotteryPoints[x].year == year) {
                for (uint y = 0; y < lotteryPoints[x].points; y++) {
                    tickets.push(lotteryPoints[x].participant);
                }
            }
        }

        uint selectedNumber = random(tickets.length - 1);

        lt.drawExecuted = true;
        lt.drawWinner = tickets[selectedNumber];

        delete tickets;

        //pay the winner
        payContractBalance(payable(lt.drawWinner));

        return lt.drawWinner;
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
                //if (checkpoints[x] <= block.timestamp.sub(secondsBeforeEarning)) {

                    //4 star - edition 1
                    for (uint s = 0; s < s4e1.length; s++) {
                        if (x == s4e1[s]) {
                            awardPoints(lt, deposits[x], E1_MULTIPLIER.mul(S4));
                            awardToken(deposits[x]);
                            break;
                        }
                    }

                    //3 star - edition 1
                    for (uint s = 0; s < s3e1.length; s++) {
                        if (x == s3e1[s]) {
                            awardPoints(lt, deposits[x], E1_MULTIPLIER.mul(S3));
                            awardToken(deposits[x]);
                            break;
                        }
                    }

                    //2 star - edition 1
                    for (uint s = 0; s < s2e1.length; s++) {
                        if (x == s2e1[s]) {
                            awardPoints(lt, deposits[x], E1_MULTIPLIER.mul(S2));
                            awardToken(deposits[x]);
                            break;
                        }
                    }

                    //1 star - edition 1
                    for (uint s = 0; s < s1e1.length; s++) {
                        if (x == s1e1[s]) {
                            awardPoints(lt, deposits[x], E1_MULTIPLIER.mul(S1));
                            awardToken(deposits[x]);
                            break;
                        }
                    }

                    //4 star - edition 2
                    for (uint s = 0; s < s4e2.length; s++) {
                        if (x == s4e2[s]) {
                            awardPoints(lt, deposits[x], E2_MULTIPLIER.mul(S4));
                            awardToken(deposits[x]);
                            break;
                        }
                    }

                    //3 star - edition 2
                    for (uint s = 0; s < s3e2.length; s++) {
                        if (x == s3e2[s]) {
                            awardPoints(lt, deposits[x], E2_MULTIPLIER.mul(S3));
                            awardToken(deposits[x]);
                            break;
                        }
                    }

                    //2 star - edition 2
                    for (uint s = 0; s < s2e2.length; s++) {
                        if (x == s2e2[s]) {
                            awardPoints(lt, deposits[x], E2_MULTIPLIER.mul(S2));
                            awardToken(deposits[x]);
                            break;
                        }
                    }

                    //1 star - edition 2
                    for (uint s = 0; s < s1e2.length; s++) {
                        if (x == s1e2[s]) {
                            awardPoints(lt, deposits[x], E2_MULTIPLIER.mul(S1));
                            awardToken(deposits[x]);
                            break;
                        }
                    }
                //}
            }
        }
    }

    function stakingPause() external onlyOwner {
        require(stakingPaused == false, "Staking is already paused");
        stakingPaused = true;
    }

    function stakingStart() external onlyOwner {
        require(stakingPaused == true, "Staking has already started");
        stakingPaused = false;
    }

    function tokensStaked(address staker) external view returns (uint[] memory) {
        uint[] memory results = new uint[](tokensCountStaked(staker));
        uint index = 0;
        for (uint x = 0; x < nftSupply; x++) {
            if (deposits[x] == staker) {
                results[index] = x;
                index++;
            }
        }

        return results;
    }

    function tokensCountStaked(address staker) internal view returns (uint) {
        uint result = 0;
        for (uint x = 0; x < nftSupply; x++) {
            if (deposits[x] == staker) {
                result++;
            }
        }
        return result;
    }

    function withdraw(uint tokenId) external {
        require(deposits[tokenId] == msg.sender, "You did not stake this token");
        nonFungibleToken.transferFrom(address(this), msg.sender, tokenId);
        delete deposits[tokenId];
        delete checkpoints[tokenId];
        stakedTokens--;
    }
}