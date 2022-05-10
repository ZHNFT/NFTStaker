// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract NFTeeStaker is ERC20, ReentrancyGuard {

    IERC721 nftContract;

    uint256 constant SECONDS_PER_DAY = 24 * 60 * 60;
    /// 1000 NFT tokens == 1000 * 10**18
    uint256 constant BASE_YIELD_RATE = 1000 ether;

    struct Staker {
        /// The number of the NFT tokens for 24 hours
        uint256 currentYield;
        /// The total number of the unclaimed NFT tokens
        uint256 reward;
        /// Last time when the reward were calculated on-chain
        uint256 lastCheckpoint;
    }

    mapping(address => Staker) public stakers;
    mapping(uint256 => address) public tokenOwners;

    constructor(address _nftContract, string memory name, string memory symbol) ERC20(name, symbol) {
        nftContract = IERC721(_nftContract);
    }

    function stake(uint256[] memory tokenIds) public {
        Staker storage user = stakers[msg.sender];
        uint256 yield = user.currentYield;
        uint256 length = tokenIds.length;

        for (uint256 i = 0; i < length; i++) {
            require(nftContract.ownerOf(tokenIds[i]) == msg.sender, "Not the owner");

            nftContract.safeTransferFrom(msg.sender, address(this), tokenIds[i]);
            tokenOwners[tokenIds[i]] = msg.sender;
            yield += BASE_YIELD_RATE;

        }

        accumulate(msg.sender);
        user.currentYield = yield;
        
    }

    function unstake(uint256[] memory tokenIds) public {
        Staker storage user = stakers[msg.sender];
        uint256 yield = user.currentYield;
        uint256 length = tokenIds.length;

        for (uint256 i = 0; i < length; i++) {
            require(tokenOwners[i] == msg.sender, "Not the original owner");
            require(nftContract.ownerOf(tokenIds[i]) == address(this), "Not staked");

            tokenOwners[tokenIds[i]] = address(0);

            if (yield != 0) {
                yield -= BASE_YIELD_RATE;
            }

            nftContract.safeTransferFrom(address(this), msg.sender, tokenIds[i]);

        }

        accumulate(msg.sender);
        user.currentYield = yield;
    }

    function claim() public nonReentrant {
        Staker storage user = stakers[msg.sender];
        accumulate(msg.sender);
        _mint(msg.sender, user.reward);
        user.reward = 0;
    }

    function accumulate(address staker) internal {
        stakers[staker].reward += getReward(staker);
        stakers[staker].lastCheckpoint = block.timestamp;
    }

    function getReward(address staker) public view returns (uint256) {
        Staker memory user = stakers[staker];

        if (user.lastCheckpoint == 0) {
            return 0;
        }
        return ((block.timestamp - user.lastCheckpoint) * user.currentYield / SECONDS_PER_DAY);
    }

    /// Return very specific four bytes
    /// Let the ERC721 smart contract know it is safe to transfer ERC721 tokens to the smart contract
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return bytes4(keccak256("onERC721Received(address, address, uint256, bytes)"));
    }

}
