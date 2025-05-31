// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/UserRegistry.sol";
import "../src/SocialVouching.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./mocks/MockERC20.sol"; // Assuming a mock ERC20 for testing

contract SocialVouchingTest is Test {
    UserRegistry public userRegistry;
    SocialVouching public socialVouching;
    MockERC20 public mockToken;

    address owner = address(this); // Test contract is owner of UserRegistry AND MockToken
    address userRegistryOwner = address(this);
    address borrower = vm.addr(1);
    address voucher1 = vm.addr(2);
    address voucher2 = vm.addr(3);
    address maliciousActor = vm.addr(4);
    address loanContractMockAddress = vm.addr(10); // Mock address for LoanContract

    bytes32 borrowerNullifier = keccak256(abi.encodePacked("borrowerN"));
    bytes32 voucher1Nullifier = keccak256(abi.encodePacked("voucher1N"));
    bytes32 voucher2Nullifier = keccak256(abi.encodePacked("voucher2N"));

    function setUp() public {
        userRegistry = new UserRegistry();
        socialVouching = new SocialVouching(address(userRegistry));
        mockToken = new MockERC20("Mock Token", "MTK", 18); // Owner of mockToken is address(this)

        // Set the loanContractAddress in SocialVouching as the owner of SocialVouching
        vm.prank(owner); // owner of SocialVouching is address(this) from constructor
        socialVouching.setLoanContractAddress(loanContractMockAddress);

        vm.prank(userRegistryOwner);
        userRegistry.registerOrUpdateUser(borrower, borrowerNullifier);
        vm.prank(userRegistryOwner);
        userRegistry.registerOrUpdateUser(voucher1, voucher1Nullifier);
        vm.prank(userRegistryOwner);
        userRegistry.registerOrUpdateUser(voucher2, voucher2Nullifier);

        // Mint tokens as owner of MockToken (this contract)
        mockToken.mint(voucher1, 1000 * 1e18);
        mockToken.mint(voucher2, 1000 * 1e18);
    }

    // --- Test addVouch --- 
    function test_AddVouch_Success() public {
        uint256 vouchAmount = 100 * 1e18;
        vm.startPrank(voucher1);
        mockToken.approve(address(socialVouching), vouchAmount);
        socialVouching.addVouch(borrower, vouchAmount, address(mockToken));
        vm.stopPrank();

        SocialVouching.Vouch memory vouch = socialVouching.getVouchDetails(borrower, voucher1);
        assertTrue(vouch.active, "Vouch should be active");
        assertEq(vouch.voucher, voucher1, "Voucher address mismatch");
        assertEq(vouch.tokenAddress, address(mockToken), "Token address mismatch");
        assertEq(vouch.amountStaked, vouchAmount, "Amount staked mismatch");
        assertEq(socialVouching.getTotalVouchedAmountForBorrower(borrower), vouchAmount, "Total vouched amount mismatch");
        assertEq(mockToken.balanceOf(address(socialVouching)), vouchAmount, "Contract token balance mismatch");
    }

    function test_RevertIf_AddVouch_SelfVouch() public {
        // Mint tokens to borrower first, as owner of mockToken
        mockToken.mint(borrower, 200 * 1e18);
        vm.startPrank(borrower);
        mockToken.approve(address(socialVouching), 100 * 1e18);
        vm.expectRevert(bytes("SocialVouching: Cannot vouch for oneself"));
        socialVouching.addVouch(borrower, 100 * 1e18, address(mockToken));
        vm.stopPrank();
    }

    function test_RevertIf_AddVouch_ZeroAmount() public {
        vm.startPrank(voucher1);
        mockToken.approve(address(socialVouching), 0);
        vm.expectRevert(bytes("SocialVouching: Stake amount must be positive"));
        socialVouching.addVouch(borrower, 0, address(mockToken));
        vm.stopPrank();
    }

    function test_RevertIf_AddVouch_InvalidTokenAddress() public {
        vm.startPrank(voucher1);
        vm.expectRevert(bytes("SocialVouching: Invalid token address"));
        socialVouching.addVouch(borrower, 100 * 1e18, address(0));
        vm.stopPrank();
    }

    function test_RevertIf_AddVouch_VoucherNotVerified() public {
        // Mint tokens to maliciousActor as owner of mockToken (this contract)
        mockToken.mint(maliciousActor, 200 * 1e18);
        
        vm.startPrank(maliciousActor); // maliciousActor is not registered in UserRegistry
        mockToken.approve(address(socialVouching), 100 * 1e18);
        vm.expectRevert(bytes("SocialVouching: User not World ID verified"));
        socialVouching.addVouch(borrower, 100 * 1e18, address(mockToken));
        vm.stopPrank();
    }

    function test_RevertIf_AddVouch_BorrowerNotVerified() public {
        vm.startPrank(voucher1);
        mockToken.approve(address(socialVouching), 100 * 1e18);
        vm.expectRevert(bytes("SocialVouching: User not World ID verified"));
        socialVouching.addVouch(maliciousActor, 100 * 1e18, address(mockToken));
        vm.stopPrank();
    }

    function test_RevertIf_AddVouch_AlreadyActive() public {
        uint256 vouchAmount = 100 * 1e18;
        vm.startPrank(voucher1);
        mockToken.approve(address(socialVouching), vouchAmount * 2);
        socialVouching.addVouch(borrower, vouchAmount, address(mockToken));
        vm.expectRevert(bytes("SocialVouching: Vouch already active for this pair"));
        socialVouching.addVouch(borrower, vouchAmount, address(mockToken));
        vm.stopPrank();
    }
    
    // --- Test removeVouch --- 
    function test_RemoveVouch_Success() public {
        uint256 vouchAmount = 100 * 1e18;
        vm.startPrank(voucher1);
        mockToken.approve(address(socialVouching), vouchAmount);
        socialVouching.addVouch(borrower, vouchAmount, address(mockToken));
        socialVouching.removeVouch(borrower);
        vm.stopPrank();

        SocialVouching.Vouch memory vouch = socialVouching.getVouchDetails(borrower, voucher1);
        assertFalse(vouch.active, "Vouch should be inactive");
        assertEq(vouch.amountStaked, 0, "Amount staked should be zero");
        assertEq(socialVouching.getTotalVouchedAmountForBorrower(borrower), 0, "Total vouched amount should be zero");
        assertEq(mockToken.balanceOf(address(socialVouching)), 0, "Contract token balance should be zero");
        assertEq(mockToken.balanceOf(voucher1), 1000 * 1e18, "Voucher token balance mismatch after removal");
    }

    function test_RevertIf_RemoveVouch_NoActiveVouch() public {
        vm.startPrank(voucher1);
        vm.expectRevert(bytes("SocialVouching: No active vouch to remove"));
        socialVouching.removeVouch(borrower);
        vm.stopPrank();
    }

    function test_RevertIf_RemoveVouch_NotVoucher() public {
        uint256 vouchAmount = 100 * 1e18;
        vm.startPrank(voucher1);
        mockToken.approve(address(socialVouching), vouchAmount);
        socialVouching.addVouch(borrower, vouchAmount, address(mockToken));
        vm.stopPrank();

        vm.startPrank(voucher2);
        vm.expectRevert(bytes("SocialVouching: No active vouch to remove"));
        socialVouching.removeVouch(borrower);
        vm.stopPrank();
    }

    // --- Test slashVouch --- (Assuming only callable by a trusted contract, here LoanContract, mocked by `owner` for now)
    function test_SlashVouch_Success() public {
        uint256 vouchAmount = 100 * 1e18;
        uint256 slashAmount = 50 * 1e18;
        address recipient = vm.addr(5);

        vm.startPrank(voucher1);
        mockToken.approve(address(socialVouching), vouchAmount);
        socialVouching.addVouch(borrower, vouchAmount, address(mockToken));
        vm.stopPrank();

        vm.startPrank(loanContractMockAddress); // Call from mock loan contract
        socialVouching.slashVouch(borrower, voucher1, slashAmount, recipient);
        vm.stopPrank();

        SocialVouching.Vouch memory vouch = socialVouching.getVouchDetails(borrower, voucher1);
        assertTrue(vouch.active, "Vouch should still be active");
        assertEq(vouch.amountStaked, vouchAmount - slashAmount, "Amount staked after slash mismatch");
        assertEq(socialVouching.getTotalVouchedAmountForBorrower(borrower), vouchAmount - slashAmount, "Total vouched amount after slash mismatch");
        assertEq(mockToken.balanceOf(address(socialVouching)), vouchAmount - slashAmount, "Contract token balance after slash mismatch");
        assertEq(mockToken.balanceOf(recipient), slashAmount, "Recipient token balance after slash mismatch");
    }

    function test_SlashVouch_FullSlash() public {
        uint256 vouchAmount = 100 * 1e18;
        address recipient = vm.addr(5);

        vm.startPrank(voucher1);
        mockToken.approve(address(socialVouching), vouchAmount);
        socialVouching.addVouch(borrower, vouchAmount, address(mockToken));
        vm.stopPrank();

        vm.startPrank(loanContractMockAddress); // Call from mock loan contract
        socialVouching.slashVouch(borrower, voucher1, vouchAmount, recipient);
        vm.stopPrank();

        SocialVouching.Vouch memory vouch = socialVouching.getVouchDetails(borrower, voucher1);
        assertFalse(vouch.active, "Vouch should be inactive after full slash");
        assertEq(vouch.amountStaked, 0, "Amount staked should be zero after full slash");
        assertEq(mockToken.balanceOf(recipient), vouchAmount, "Recipient token balance after full slash mismatch");
    }

    function test_RevertIf_SlashVouch_NoActiveVouch() public {
        vm.startPrank(loanContractMockAddress); // Call from mock loan contract
        vm.expectRevert(bytes("SocialVouching: No active vouch to slash"));
        socialVouching.slashVouch(borrower, voucher1, 50 * 1e18, owner); 
        vm.stopPrank();
    }

    function test_RevertIf_SlashVouch_AmountExceedsStake() public {
        uint256 vouchAmount = 100 * 1e18;
        vm.startPrank(voucher1);
        mockToken.approve(address(socialVouching), vouchAmount);
        socialVouching.addVouch(borrower, vouchAmount, address(mockToken));
        vm.stopPrank();

        vm.startPrank(loanContractMockAddress); // Call from mock loan contract
        vm.expectRevert(bytes("SocialVouching: Slash amount exceeds staked amount"));
        socialVouching.slashVouch(borrower, voucher1, vouchAmount + 1, owner); 
        vm.stopPrank();
    }

    function test_RevertIf_SlashVouch_NotLoanContract() public {
        uint256 vouchAmount = 100 * 1e18;
        vm.startPrank(voucher1);
        mockToken.approve(address(socialVouching), vouchAmount);
        socialVouching.addVouch(borrower, vouchAmount, address(mockToken));
        vm.stopPrank();

        vm.startPrank(maliciousActor); // Call from a non-loan contract address
        vm.expectRevert(bytes("SocialVouching: Caller is not the LoanContract"));
        socialVouching.slashVouch(borrower, voucher1, 50 * 1e18, owner);
        vm.stopPrank();
    }

    // --- Test rewardVoucher --- (Placeholder, just check event emission for now)
    function test_RewardVoucher_EmitsEvent_CalledByLoanContract() public { // Renamed for clarity
        uint256 vouchAmount = 100 * 1e18;
        vm.startPrank(voucher1);
        mockToken.approve(address(socialVouching), vouchAmount);
        socialVouching.addVouch(borrower, vouchAmount, address(mockToken));
        vm.stopPrank();

        vm.startPrank(loanContractMockAddress); // Call from mock loan contract
        vm.expectEmit(true, true, true, true);
        emit SocialVouching.VouchRewarded(borrower, voucher1, 5 * 1e18);
        socialVouching.rewardVoucher(borrower, voucher1, 5 * 1e18, address(mockToken));
        vm.stopPrank();
    }

    function test_RevertIf_RewardVoucher_NotLoanContract() public {
        uint256 vouchAmount = 100 * 1e18;
        vm.startPrank(voucher1);
        mockToken.approve(address(socialVouching), vouchAmount);
        socialVouching.addVouch(borrower, vouchAmount, address(mockToken));
        vm.stopPrank();

        vm.startPrank(maliciousActor); // Call from a non-loan contract address
        vm.expectRevert(bytes("SocialVouching: Caller is not the LoanContract"));
        socialVouching.rewardVoucher(borrower, voucher1, 5 * 1e18, address(mockToken));
        vm.stopPrank();
    }

    // --- View functions ---
    function test_GetVouchDetails_Test() public { // Renamed to avoid conflict
        uint256 vouchAmount = 77 * 1e18;
        vm.startPrank(voucher1);
        mockToken.approve(address(socialVouching), vouchAmount);
        socialVouching.addVouch(borrower, vouchAmount, address(mockToken));
        vm.stopPrank();

        SocialVouching.Vouch memory vouch = socialVouching.getVouchDetails(borrower, voucher1);
        assertTrue(vouch.active);
        assertEq(vouch.voucher, voucher1);
        assertEq(vouch.tokenAddress, address(mockToken));
        assertEq(vouch.amountStaked, vouchAmount);
    }

    function test_GetTotalVouchedAmountForBorrower() public {
        uint256 vouchAmount1 = 100 * 1e18;
        uint256 vouchAmount2 = 50 * 1e18;

        vm.startPrank(voucher1);
        mockToken.approve(address(socialVouching), vouchAmount1);
        socialVouching.addVouch(borrower, vouchAmount1, address(mockToken));
        vm.stopPrank();

        assertEq(socialVouching.getTotalVouchedAmountForBorrower(borrower), vouchAmount1);
        
        vm.startPrank(voucher2);
        mockToken.approve(address(socialVouching), vouchAmount2);
        socialVouching.addVouch(borrower, vouchAmount2, address(mockToken));
        vm.stopPrank();

        assertEq(socialVouching.getTotalVouchedAmountForBorrower(borrower), vouchAmount1 + vouchAmount2);
    }
} 