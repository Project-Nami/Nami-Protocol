// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IBatcherAccountProxy} from "contracts/batcher/interfaces/IBatcherAccountProxy.sol";
import {
    Funding,
    IBatcherAccountProxyFactory,
    NFTFunding
} from "contracts/batcher/interfaces/IBatcherAccountProxyFactory.sol";
import {AddressLib} from "contracts/batcher/libraries/AddressLib.sol";
import {IWETH} from "contracts/interfaces/token/IWETH.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/// @dev Deployed on Hub & Spoke chains
contract BatcherAccountProxy is IBatcherAccountProxy, IERC721Receiver {
    using AddressLib for address;

    // ═══════════════════════════════════════════════════════════════════════════
    /// Immutables
    // ═══════════════════════════════════════════════════════════════════════════
    address public immutable wrappedNative;
    address public immutable owner;

    // ═══════════════════════════════════════════════════════════════════════════
    /// Constructor
    // ═══════════════════════════════════════════════════════════════════════════

    constructor(address _wrappedNative, address _owner) {
        wrappedNative = _wrappedNative;
        owner = _owner;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INIT
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Factory-only entry that delegatecalls `init.initialize()` in this
    ///         proxy's storage context. Gated on `factory.isInitAuthorized()` so
    ///         a user routing this call via `factory.execute` cannot reach the
    ///         delegatecall.
    function runInit(address init) external {
        if (msg.sender != owner) revert UnauthorizedCall();
        if (!IBatcherAccountProxyFactory(owner).isInitAuthorized()) revert UnauthorizedCall();
        Address.functionDelegateCall(init, abi.encodeWithSignature("initialize()"));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MULTICALL
    // ═══════════════════════════════════════════════════════════════════════════

    function multicall(bytes[] calldata data)
        public
        payable
        onlyUserOrOwner
        returns (bool[] memory successes, bytes[] memory results)
    {
        return multicall(data, new bool[](data.length));
    }

    /// @notice Execute multiple calls with optional revert control per call
    /// @param data Array of encoded function calls
    /// @param allowRevert Array of booleans indicating if each call is allowed to revert
    function multicall(bytes[] calldata data, bool[] memory allowRevert)
        public
        payable
        onlyUserOrOwner
        returns (bool[] memory successes, bytes[] memory results)
    {
        uint256 len = data.length;
        if (len != allowRevert.length) revert LengthMismatch();

        successes = new bool[](len);
        results = new bytes[](len);

        unchecked {
            for (uint256 i = 0; i < len; i++) {
                (bool success, bytes memory result) = address(this).delegatecall(data[i]);
                if (!success && !allowRevert[i]) {
                    require(result.length > 0);
                    assembly ("memory-safe") {
                        revert(add(32, result), mload(result))
                    }
                }
                successes[i] = success;
                results[i] = result;
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TOKEN OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Pull tokens from the user to this contract
    /// @param token Token to pull
    /// @param amount Amount to pull
    function pull(address token, uint256 amount) external payable onlyUserOrOwner {
        SafeTransferLib.safeTransferFrom(token, user(), address(this), amount);
    }

    /// @notice Pulls from the user through the factory allowance, so this clone never needs one.
    /// @param funding Tokens and amounts to move from the user into this contract
    function pullViaFactory(Funding[] calldata funding) external payable onlyUserOrOwner {
        IBatcherAccountProxyFactory(owner).pullFor(funding);
    }

    /// @notice Apply an EIP-2612 permit signed by the user, with this proxy as spender
    /// @param token Token to permit
    /// @param value Allowance amount
    /// @param deadline Permit deadline (unix seconds)
    /// @param v Signature v
    /// @param r Signature r
    /// @param s Signature s
    function permit(address token, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        payable
        onlyUserOrOwner
    {
        IERC20Permit(token).permit(user(), address(this), value, deadline, v, r, s);
    }

    /// @notice Sweep entire balance of a token to recipient
    /// @param token Token to sweep
    /// @param minAmount Minimum amount expected (slippage protection)
    function sweep(address token, uint256 minAmount) external payable onlyUserOrOwner {
        uint256 balance = token.resolveBalance();
        if (balance < minAmount) revert MinAmountViolated(balance, minAmount);

        if (balance > 0) {
            address u = user();
            if (token == address(0)) {
                SafeTransferLib.safeTransferETH(u, balance);
            } else {
                SafeTransferLib.safeTransfer(token, u, balance);
            }
        }
    }

    /// @notice Transfer specific amount to recipient
    /// @param token Token to transfer (address(0) for native ETH)
    /// @param amount Amount to transfer (use CONTRACT_BALANCE for entire balance)
    /// @dev When token == address(0), the user must be able to receive native ETH. Contract users
    ///      without a payable receive path should wrap via wrapNative(CONTRACT_BALANCE) and
    ///      push the resulting WETH instead.
    function push(address token, uint256 amount) external payable onlyUserOrOwner {
        amount = token.resolveAmount(amount);
        if (amount > 0) {
            address u = user();
            if (token == address(0)) {
                SafeTransferLib.safeTransferETH(u, amount);
            } else {
                SafeTransferLib.safeTransfer(token, u, amount);
            }
        }
    }

    /// @notice Pull NFT from user to this contract.
    /// @param token NFT contract
    /// @param tokenId tokenId to pull
    function pullNFT(address token, uint256 tokenId) external payable onlyUserOrOwner {
        IERC721(token).transferFrom(user(), address(this), tokenId);
    }

    /// @notice Pulls NFTs from the user through the factory approval, so this clone never needs one.
    /// @param funding Collections and token ids to move from the user into this contract
    function pullNFTViaFactory(NFTFunding[] calldata funding) external payable onlyUserOrOwner {
        IBatcherAccountProxyFactory(owner).pullNFTFor(funding);
    }

    /// @notice Transfer NFT to user
    /// @param token Token to transfer
    /// @param tokenId tokend ID to be transferred
    function pushNFT(address token, uint256 tokenId) external payable onlyUserOrOwner {
        IERC721(token).transferFrom(address(this), user(), tokenId);
    }

    /// @notice Transfer NFT to user to a given receiver
    /// @param token Token to transfer
    /// @param tokenId tokend ID to be transferred
    /// @param to Receiver address
    /// @dev Escape hatch for NFTs when user() is not an ERC721Receiver-compliant.
    function pushNFT(address token, uint256 tokenId, address to) external payable onlyUserOrOwner {
        to = to == address(0) ? user() : to;
        IERC721(token).transferFrom(address(this), to, tokenId);
    }

    /// @notice Wrap ETH to WETH
    /// @param amount Amount to wrap from this proxy's ETH balance
    function wrapNative(uint256 amount) external payable onlyUserOrOwner {
        amount = address(0).resolveAmount(amount);
        if (amount > 0) {
            IWETH(wrappedNative).deposit{value: amount}();
        }
    }

    /// @notice Unwrap WETH to ETH and send to recipient
    /// @param amount Amount to unwrap (use CONTRACT_BALANCE for entire balance)
    /// @dev Contract users that cannot receive native ETH should ensure a payable receive path before
    ///      pushing. ETH stranded in the proxy can be recovered by re-wrapping via wrapNative(CONTRACT_BALANCE)
    ///      and then push(wrappedNative, ...).
    function unwrapNative(uint256 amount) external payable onlyUserOrOwner {
        amount = wrappedNative.resolveAmount(amount);
        if (amount > 0) {
            IWETH(wrappedNative).withdraw(amount);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INTERNAL
    // ═══════════════════════════════════════════════════════════════════════════

    modifier onlyUserOrOwner() {
        if (msg.sender != owner && msg.sender != user()) revert UnauthorizedCall();
        _;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // EXTERNAL
    // ═══════════════════════════════════════════════════════════════════════════

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function user() public view returns (address u) {
        assembly ("memory-safe") {
            extcodecopy(address(), 0x00, 0x2d, 0x20)
            u := mload(0x00)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // RECEIVE & FALLBACK
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Accept native ETH sent to the batcher proxy.
    receive() external payable {}

    fallback() external payable {
        if (msg.sender != owner && msg.sender != user()) revert UnauthorizedCall();

        (address facet, bool paused) = IBatcherAccountProxyFactory(owner).dispatch(msg.sig);
        if (paused) revert VersionPaused();
        if (facet == address(0)) revert NoFacetForSelector();

        assembly ("memory-safe") {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
