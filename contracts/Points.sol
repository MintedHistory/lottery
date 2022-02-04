// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/safemath.sol";
import "./IFungibleToken.sol";

interface ILottery {
    function checkpoints(uint256) external view returns (uint256);

    function deposits(uint256) external view returns (address);

    function tokensStaked(address staker)
        external
        view
        returns (uint256[] memory);
    
    function nftSupply() external view returns (uint);
}

contract Points is Ownable {
    struct _DateTime {
        uint16 year;
        uint8 month;
        uint8 day;
        uint8 hour;
        uint8 minute;
        uint8 second;
        uint8 weekday;
    }

    struct Leaderboard {
      address holder;
      uint tokenId;
      uint points;
    }

    using SafeMath for uint8;
    using SafeMath for uint16;
    using SafeMath for uint256;

    ILottery public lotteryContract;
    IFungibleToken public tokenContract;

    uint256[] public s4e1;
    uint256[] public s3e1;
    uint256[] public s2e1;
    uint256[] public s1e1;
    uint256[] public s4e2;
    uint256[] public s3e2;
    uint256[] public s2e2;
    uint256[] public s1e2;

    uint256 constant DAY_IN_SECONDS = 86400;
    uint8 constant E1_MULTIPLIER = 2;
    uint8 constant E2_MULTIPLIER = 1;
    uint256 constant LEAP_YEAR_IN_SECONDS = 31622400;
    uint16 constant ORIGIN_YEAR = 1970;
    uint8 constant S1 = 1;
    uint8 constant S2 = 2;
    uint8 constant S3 = 4;
    uint8 constant S4 = 8;
    uint256 constant YEAR_IN_SECONDS = 31536000;

    mapping(uint256 => uint256) public checkpointsRedeemed;
    mapping(uint16 => mapping (uint8 => address)) public winners;

    constructor(address _lotteryContract, address _tokenContract) {
        lotteryContract = ILottery(_lotteryContract);
        tokenContract = IFungibleToken(_tokenContract);
    }

    function fundLottery() payable external {

    }

    function getLeaderboard(uint16 year, uint8 month) public view returns (Leaderboard[] memory) {
      uint startOfMonth = firstDayOfMonth(year, month);
      month++;
      if (month > 12) year++;
      uint endOfMonth = firstDayOfMonth(year, month);
      uint staked = 0;
      for (uint y = 0; y < lotteryContract.nftSupply(); y++) {
        if (lotteryContract.deposits(y) != address(0)) {
          staked++;
        }
      }

      Leaderboard[] memory results = new Leaderboard[](staked);

      staked = 0;
      for (uint x = 0; x < lotteryContract.nftSupply(); x++) {
        if (lotteryContract.deposits(x) != address(0)) {
          uint timestamp = block.timestamp;
          if (timestamp > endOfMonth) {
            timestamp = endOfMonth;
          }
          uint daysVested;
          if (lotteryContract.checkpoints(x) > startOfMonth) {
            daysVested = (timestamp - lotteryContract.checkpoints(x)).div(DAY_IN_SECONDS);
          } else {
            daysVested = (timestamp - startOfMonth).div(DAY_IN_SECONDS);
          }
          
          //4 star - edition 1
          for (uint s = 0; s < s4e1.length; s++) {
            if (x == s4e1[s]) {
              results[staked] = Leaderboard(lotteryContract.deposits(x), x, E1_MULTIPLIER.mul(S4).mul(daysVested));
              staked++;
              break;
            }
          }

          //3 star - edition 1
          for (uint s = 0; s < s3e1.length; s++) {
            if (x == s3e1[s]) {
              results[staked] = Leaderboard(lotteryContract.deposits(x), x, E1_MULTIPLIER.mul(S3).mul(daysVested));
              staked++;
              break;
            }
          }

          //2 star - edition 1
          for (uint s = 0; s < s2e1.length; s++) {
            if (x == s2e1[s]) {
              results[staked] = Leaderboard(lotteryContract.deposits(x), x, E1_MULTIPLIER.mul(S2).mul(daysVested));
              staked++;
              break;
            }
          }

          //1 star - edition 1
          for (uint s = 0; s < s1e1.length; s++) {
            if (x == s1e1[s]) {
              results[staked] = Leaderboard(lotteryContract.deposits(x), x, E1_MULTIPLIER.mul(S1).mul(daysVested));
              staked++;
              break;
            }
          }

          //4 star - edition 2
          for (uint s = 0; s < s4e2.length; s++) {
            if (x == s4e2[s]) {
              results[staked] = Leaderboard(lotteryContract.deposits(x), x, E2_MULTIPLIER.mul(S4).mul(daysVested));
              staked++;
              break;
            }
          }

          //3 star - edition 2
          for (uint s = 0; s < s3e2.length; s++) {
            if (x == s3e2[s]) {
              results[staked] = Leaderboard(lotteryContract.deposits(x), x, E2_MULTIPLIER.mul(S3).mul(daysVested));
              staked++;
              break;
            }
          }

          //2 star - edition 2
          for (uint s = 0; s < s2e2.length; s++) {
            if (x == s2e2[s]) {
              results[staked] = Leaderboard(lotteryContract.deposits(x), x, E2_MULTIPLIER.mul(S2).mul(daysVested));
              staked++;
              break;
            }
          }

          //1 star - edition 2
          for (uint s = 0; s < s1e2.length; s++) {
            if (x == s1e2[s]) {
              results[staked] = Leaderboard(lotteryContract.deposits(x), x, E2_MULTIPLIER.mul(S1).mul(daysVested));
              staked++;
              break;
            }
          }
        }
      }

      return results;
    }

    function getRedeemable(uint256 tokenId) public view returns (uint256) {
        address holder = lotteryContract.deposits(tokenId);
        require(holder != address(0), "This token has not been staked");
        uint256 lastRedeemed = checkpointsRedeemed[tokenId];
        uint256 lastStaked = lotteryContract.checkpoints(tokenId);
        if (lastStaked > lastRedeemed) {
            lastRedeemed = lastStaked;
        }
        uint256 timeDifference = block.timestamp.sub(lastRedeemed);

        return timeDifference.div(DAY_IN_SECONDS);
    }

    function random(uint max) public view returns (uint) {
        return uint(blockhash(block.number - 1)) % max;
    }

    function redeem(uint256 tokenId) external {
        address holder = lotteryContract.deposits(tokenId);
        require(holder == msg.sender, "You are not the owner of this token");
        uint256 eligible = getRedeemable(tokenId);
        tokenContract.mint(msg.sender, eligible * (uint256(10)**18));
        checkpointsRedeemed[tokenId] = block.timestamp;
    }

    function redeemLottery() external {
      _DateTime memory timeNow = parseTimestamp(block.timestamp);
      uint8 month = timeNow.month;
      uint16 year = timeNow.year;
      month--;
      if (month == 0) {
        month = 12;
        year--;
      }

      require(msg.sender == winners[year][month], "You are not the winner of the last lottery");

      payable(msg.sender).transfer(address(this).balance);
    }

    function redeemLotteryAdmin() external onlyOwner {
      payable(msg.sender).transfer(address(this).balance);
    }

    function set4e1(uint256[] memory values) external onlyOwner {
        for (uint256 x = 0; x < values.length; x++) {
            s4e1.push(values[x]);
        }
    }

    function set3e1(uint256[] memory values) external onlyOwner {
        for (uint256 x = 0; x < values.length; x++) {
            s3e1.push(values[x]);
        }
    }

    function set2e1(uint256[] memory values) external onlyOwner {
        for (uint256 x = 0; x < values.length; x++) {
            s2e1.push(values[x]);
        }
    }

    function set1e1(uint256[] memory values) external onlyOwner {
        for (uint256 x = 0; x < values.length; x++) {
            s1e1.push(values[x]);
        }
    }

    function set4e2(uint256[] memory values) external onlyOwner {
        for (uint256 x = 0; x < values.length; x++) {
            s4e2.push(values[x]);
        }
    }

    function set3e2(uint256[] memory values) external onlyOwner {
        for (uint256 x = 0; x < values.length; x++) {
            s3e2.push(values[x]);
        }
    }

    function set2e2(uint256[] memory values) external onlyOwner {
        for (uint256 x = 0; x < values.length; x++) {
            s2e2.push(values[x]);
        }
    }

    function set1e2(uint256[] memory values) external onlyOwner {
        for (uint256 x = 0; x < values.length; x++) {
            s1e2.push(values[x]);
        }
    }

    //date functions
    function getYear(uint256 timestamp) public pure returns (uint16) {
        uint256 secondsAccountedFor = 0;
        uint16 year;
        uint256 numLeapYears;

        // Year
        year = uint16(ORIGIN_YEAR + timestamp / YEAR_IN_SECONDS);
        numLeapYears = leapYearsBefore(year) - leapYearsBefore(ORIGIN_YEAR);

        secondsAccountedFor += LEAP_YEAR_IN_SECONDS * numLeapYears;
        secondsAccountedFor +=
            YEAR_IN_SECONDS *
            (year - ORIGIN_YEAR - numLeapYears);

        while (secondsAccountedFor > timestamp) {
            if (isLeapYear(uint16(year - 1))) {
                secondsAccountedFor -= LEAP_YEAR_IN_SECONDS;
            } else {
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

    function leapYearsBefore(uint256 year) public pure returns (uint256) {
        year -= 1;
        return year / 4 - year / 100 + year / 400;
    }

    function firstDayOfMonth(uint year, uint month) public pure returns (uint) {
      int _year = int(year);
      int _month = int(month);
      int _day = 1;

      int __days = _day
          - 32075
          + 1461 * (_year + 4800 + (_month - 14) / 12) / 4
          + 367 * (_month - 2 - (_month - 14) / 12 * 12) / 12
          - 3 * ((_year + 4900 + (_month - 14) / 12) / 100) / 4
        - 2440588; //offset constant from 1970/1/1

      return uint(__days) * DAY_IN_SECONDS;
    }

    function getDaysInMonth(uint8 month, uint16 year)
        public
        pure
        returns (uint8)
    {
        if (
            month == 1 ||
            month == 3 ||
            month == 5 ||
            month == 7 ||
            month == 8 ||
            month == 10 ||
            month == 12
        ) {
            return 31;
        } else if (month == 4 || month == 6 || month == 9 || month == 11) {
            return 30;
        } else if (isLeapYear(year)) {
            return 29;
        } else {
            return 28;
        }
    }

    function getHour(uint timestamp) public pure returns (uint8) {
      return uint8((timestamp / 60 / 60) % 24);
    }

    function getMinute(uint timestamp) public pure returns (uint8) {
      return uint8((timestamp / 60) % 60);
    }

    function getSecond(uint timestamp) public pure returns (uint8) {
      return uint8(timestamp % 60);
    }

    function parseTimestamp(uint256 timestamp)
        internal
        pure
        returns (_DateTime memory dt)
    {
        uint256 secondsAccountedFor = 0;
        uint256 buf;
        uint8 i;

        // Year
        dt.year = getYear(timestamp);
        buf = leapYearsBefore(dt.year) - leapYearsBefore(ORIGIN_YEAR);

        secondsAccountedFor += LEAP_YEAR_IN_SECONDS * buf;
        secondsAccountedFor += YEAR_IN_SECONDS * (dt.year - ORIGIN_YEAR - buf);

        // Month
        uint256 secondsInMonth;
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

        // Hour
        dt.hour = getHour(timestamp);

        // Minute
        dt.minute = getMinute(timestamp);

        // Second
        dt.second = getSecond(timestamp);
    }

    function setWinner(uint16 year, uint8 month, address winner) public onlyOwner {
      winners[year][month] = winner;
    }
}
