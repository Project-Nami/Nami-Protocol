// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @notice One token movement from the caller into the caller own batcher.
struct Funding {
    address token;
    uint256 amount;
}

/// @notice One NFT movement from the caller into the caller own batcher.
struct NFTFunding {
    address collection;
    uint256 tokenId;
}

interface IBatcherAccountProxyFactory {
    // ═══════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ═══════════════════════════════════════════════════════════════════════════

    struct Version {
        EnumerableSet.Bytes32Set selectorSet;
        mapping(bytes4 => address) selectorToFacet;
        EnumerableSet.Bytes32Set rescueSelectors;
        address initializer;
        bool finalized;
        bool paused;
    }

    /// @notice Per-facet input bundle for batched selector registration.
    struct FacetSelectors {
        address facet;
        bytes4[] selectors;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════════════════

    error ZeroAddress();
    error InvalidVersionId();
    error VersionNotFinalized();
    error VersionPaused();
    error EmptySelectors();
    error EmptyFacetGroups();
    error TooManySelectors();
    error SelectorAlreadyInVersion(bytes4 selector);
    error SelectorNotInVersion(bytes4 selector);
    error NoDraft();
    error NoBatcher();
    error InvalidBatcherFacet(address facet);

    // ═══════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════════════════

    event VersionCreated(uint256 indexed versionId);
    event VersionSelectorsAdded(uint256 indexed versionId, address indexed facet, bytes4[] selectors);
    event VersionSelectorsRemoved(uint256 indexed versionId, bytes4[] selectors);
    event VersionInitializerSet(uint256 indexed versionId, address initializer);
    event VersionFinalized(uint256 indexed versionId);
    event VersionPauseChanged(uint256 indexed versionId, bool paused);
    event VersionRescueSelectorSet(uint256 indexed versionId, bytes4 indexed selector, bool allowed);
    event BatcherDeployed(address indexed user, address indexed instance);
    event UserVersionSet(address indexed user, uint256 indexed oldVersionId, uint256 indexed newVersionId);

    // ═══════════════════════════════════════════════════════════════════════════
    // ADMIN
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Add facet selectors to the current draft. Auto-creates a new
    ///         draft (incrementing totalVersions) if none is in progress.
    function addSelectorsToVersion(FacetSelectors[] calldata facetGroups) external;

    /// @notice Remove selectors from the current draft. Auto-creates a draft
    ///         if none is in progress (the call will then revert SelectorNotInVersion).
    function removeSelectorsFromVersion(bytes4[] calldata selectors) external;

    /// @notice Set the initializer for the current draft. Auto-creates a draft
    ///         if none is in progress. The initializer must expose a parameterless
    ///         `initialize()` function (called via delegatecall on each user opt-in).
    function setVersionInitializer(address initializer) external;

    /// @notice Finalize the current draft, locking it and clearing draftVersion.
    ///         Returns the finalized version id. Reverts NoDraft if no draft is in progress.
    function finalizeVersion() external returns (uint256 finalizedId);

    /// @notice Pause/unpause a finalized version. Targets a specific id since
    ///         drafts are never paused (they're not user-visible until finalized).
    function setVersionPaused(uint256 id, bool paused) external;

    /// @notice Mark a selector as a rescue selector for a finalized version.
    ///         Rescue selectors remain callable even while the version is paused,
    function setVersionRescueSelector(uint256 id, bytes4 selector, bool allowed) external;

    // ═══════════════════════════════════════════════════════════════════════════
    // USER
    // ═══════════════════════════════════════════════════════════════════════════

    function deploy() external returns (address instance);
    function setVersion(uint256 newVersionId) external;
    function execute(bytes calldata payload) external payable returns (bytes memory result);

    /// @notice Funds the calling batcher from its own user, so approvals land here, not on clones.
    function pullFor(Funding[] calldata funding) external;

    /// @notice pullFor for ERC721, so operator approvals land here rather than on every clone.
    function pullNFTFor(NFTFunding[] calldata funding) external;

    /// @notice Deploy the caller's batcher if absent, bind version `id` when non-zero, then
    ///         forward `data` with msg.value. Not doable via the non-payable `multicall`.
    function deployExecute(uint256 id, bytes calldata data) external payable returns (address proxy, bytes memory res);

    // ═══════════════════════════════════════════════════════════════════════════
    // VIEWS
    // ═══════════════════════════════════════════════════════════════════════════

    /// @notice Fused dispatch lookup: returns the facet for the selector under the
    ///         caller's bound version, plus that version's paused flag. Keyed off
    ///         msg.sender (the calling proxy).
    function dispatch(bytes4 selector) external view returns (address facet, bool paused);

    /// @notice True iff the factory is currently inside `setVersion`'s init call,
    ///         signalling to the proxy that `runInit` is authorized this frame.
    ///         Reverts cleanly when the user routes `runInit` through `execute`.
    function isInitAuthorized() external view returns (bool);

    function versionSelectorToFacet(uint256 id, bytes4 selector) external view returns (address);
    function versionRescueSelector(uint256 id, bytes4 selector) external view returns (bool);
    function versionRescueSelectors(uint256 id, uint256 start, uint256 count) external view returns (bytes4[] memory);
    function versionInfo(uint256 id) external view returns (address initializer, bool finalized, bool paused);
    function versionSelectors(uint256 id, uint256 start, uint256 count) external view returns (bytes4[] memory);
    function totalVersions() external view returns (uint256);
    function draftVersion() external view returns (uint256);
    function proxyVersion(address proxy) external view returns (uint256);
    function batchers(address user) external view returns (address);
    function users(address batcher) external view returns (address);
    function computeBatcherAddress(address user) external view returns (address);
}
