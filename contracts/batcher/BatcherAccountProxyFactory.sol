// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {BatcherAccountProxy} from "contracts/batcher/BatcherAccountProxy.sol";
import {IBatcherAccountProxy} from "contracts/batcher/interfaces/IBatcherAccountProxy.sol";
import {
    Funding,
    IBatcherAccountProxyFactory,
    NFTFunding
} from "contracts/batcher/interfaces/IBatcherAccountProxyFactory.sol";
import {IBatcherFacet} from "contracts/batcher/interfaces/IBatcherFacet.sol";
import {BatcherConstants} from "contracts/batcher/libraries/BatcherConstants.sol";
import {LibTransient} from "solady/utils/LibTransient.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/// @dev Deployed on Hub & Spoke chains
contract BatcherAccountProxyFactory is IBatcherAccountProxyFactory, Ownable2Step, Multicall {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using LibTransient for LibTransient.TBool;

    uint256 internal constant MAX_SELECTORS_PER_FACET = 100;

    bytes32 private constant _INIT_LOCK_SLOT = bytes32(uint256(keccak256("nami.batcher.factory.initLock")) - 1);

    address public immutable wrappedNative;
    address public immutable implementation;

    uint256 public totalVersions;
    uint256 public draftVersion;

    mapping(address user => address proxy) public batchers;
    mapping(address proxy => address user) public users;
    mapping(address proxy => uint256 versionId) public proxyVersion;
    mapping(uint256 => Version) internal _versions;

    constructor(address _wrappedNative, address _owner) Ownable(_owner) {
        if (_wrappedNative == address(0)) revert ZeroAddress();
        wrappedNative = _wrappedNative;
        // Deploy the singleton implementation that all per-user clones delegatecall.
        // Owner immutable on the singleton is set to this factory.
        implementation = address(new BatcherAccountProxy(_wrappedNative, address(this)));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ADMIN
    // ═══════════════════════════════════════════════════════════════════════════

    function addSelectorsToVersion(FacetSelectors[] calldata facetGroups) external onlyOwner {
        uint256 groupsLen = facetGroups.length;
        if (groupsLen == 0) revert EmptyFacetGroups();

        uint256 id = _ensureDraft();
        Version storage v = _versions[id];

        for (uint256 g; g < groupsLen; g++) {
            address facet = facetGroups[g].facet;
            bytes4[] calldata selectors = facetGroups[g].selectors;
            uint256 len = selectors.length;

            if (facet == address(0)) revert ZeroAddress();
            if (IBatcherFacet(facet).batcherFacetId() != BatcherConstants.BATCHER_FACET_ID) {
                revert InvalidBatcherFacet(facet);
            }
            if (len == 0) revert EmptySelectors();
            if (len > MAX_SELECTORS_PER_FACET) revert TooManySelectors();

            for (uint256 i; i < len; i++) {
                bytes4 s = selectors[i];
                if (!v.selectorSet.add(bytes32(s))) revert SelectorAlreadyInVersion(s);
                v.selectorToFacet[s] = facet;
            }
            emit VersionSelectorsAdded(id, facet, selectors);
        }
    }

    function removeSelectorsFromVersion(bytes4[] calldata selectors) external onlyOwner {
        uint256 len = selectors.length;
        if (len == 0) revert EmptySelectors();

        uint256 id = _ensureDraft();
        Version storage v = _versions[id];

        for (uint256 i; i < len; i++) {
            bytes4 s = selectors[i];
            if (!v.selectorSet.remove(bytes32(s))) revert SelectorNotInVersion(s);
            v.selectorToFacet[s] = address(0);
        }
        emit VersionSelectorsRemoved(id, selectors);
    }

    function setVersionInitializer(address initializer) external onlyOwner {
        uint256 id = _ensureDraft();
        _versions[id].initializer = initializer;
        emit VersionInitializerSet(id, initializer);
    }

    function finalizeVersion() external onlyOwner returns (uint256 finalizedId) {
        finalizedId = draftVersion;
        if (finalizedId == 0) revert NoDraft();
        _versions[finalizedId].finalized = true;
        draftVersion = 0;
        emit VersionFinalized(finalizedId);
    }

    function setVersionPaused(uint256 id, bool paused) external onlyOwner {
        if (id == 0 || id > totalVersions) revert InvalidVersionId();
        Version storage v = _versions[id];
        if (!v.finalized) revert VersionNotFinalized();
        v.paused = paused;
        emit VersionPauseChanged(id, paused);
    }

    function setVersionRescueSelector(uint256 id, bytes4 selector, bool allowed) external onlyOwner {
        if (id == 0 || id > totalVersions) revert InvalidVersionId();
        Version storage v = _versions[id];
        if (!v.finalized) revert VersionNotFinalized();
        if (v.selectorToFacet[selector] == address(0)) revert SelectorNotInVersion(selector);
        if (allowed) v.rescueSelectors.add(bytes32(selector));
        else v.rescueSelectors.remove(bytes32(selector));
        emit VersionRescueSelectorSet(id, selector, allowed);
    }

    function _ensureDraft() internal returns (uint256 id) {
        id = draftVersion;
        if (id == 0) {
            id = ++totalVersions;
            draftVersion = id;
            emit VersionCreated(id);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // USER
    // ═══════════════════════════════════════════════════════════════════════════

    function deploy() public returns (address instance) {
        instance = batchers[msg.sender];
        if (instance == address(0)) {
            instance = Clones.cloneDeterministicWithImmutableArgs(
                implementation, abi.encode(msg.sender), keccak256(abi.encode(msg.sender))
            );
            batchers[msg.sender] = instance;
            users[instance] = msg.sender;
            emit BatcherDeployed(msg.sender, instance);
        }
    }

    function setVersion(uint256 newVersionId) public {
        address instance = batchers[msg.sender];
        if (instance == address(0)) revert NoBatcher();
        if (newVersionId == 0 || newVersionId > totalVersions) revert InvalidVersionId();

        Version storage v = _versions[newVersionId];
        if (!v.finalized) revert VersionNotFinalized();
        if (v.paused) revert VersionPaused();

        uint256 oldId = proxyVersion[instance];
        proxyVersion[instance] = newVersionId;

        emit UserVersionSet(msg.sender, oldId, newVersionId);

        if (v.initializer != address(0)) {
            _initLock().set(true);
            IBatcherAccountProxy(payable(instance)).runInit(v.initializer);
            _initLock().clear();
        }
    }

    function execute(bytes calldata payload) external payable returns (bytes memory result) {
        address instance = batchers[msg.sender];
        if (instance == address(0)) revert NoBatcher();
        return Address.functionCallWithValue(instance, payload, msg.value);
    }

    /// @notice Funds the calling batcher from its own user, so approvals land here, not on clones.
    function pullFor(Funding[] calldata funding) external {
        address _user = users[msg.sender];
        if (_user == address(0)) revert NoBatcher();

        for (uint256 i; i < funding.length; ++i) {
            SafeTransferLib.safeTransferFrom(funding[i].token, _user, msg.sender, funding[i].amount);
        }
    }

    /// @notice pullFor for ERC721, so operator approvals land here rather than on every clone.
    function pullNFTFor(NFTFunding[] calldata funding) external {
        address _user = users[msg.sender];
        if (_user == address(0)) revert NoBatcher();

        for (uint256 i; i < funding.length; ++i) {
            IERC721(funding[i].collection).transferFrom(_user, msg.sender, funding[i].tokenId);
        }
    }

    function deployExecute(uint256 id, bytes calldata data) external payable returns (address proxy, bytes memory res) {
        proxy = deploy();
        if (id != 0) setVersion(id);
        res = Address.functionCallWithValue(proxy, data, msg.value);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // VIEWS (public introspection)
    // ═══════════════════════════════════════════════════════════════════════════

    function dispatch(bytes4 selector) external view returns (address facet, bool paused) {
        Version storage v = _versions[proxyVersion[msg.sender]];
        return (v.selectorToFacet[selector], v.paused && !v.rescueSelectors.contains(bytes32(selector)));
    }

    function isInitAuthorized() external view returns (bool) {
        return _initLock().get();
    }

    function _initLock() private pure returns (LibTransient.TBool storage) {
        return LibTransient.tBool(_INIT_LOCK_SLOT);
    }

    function versionSelectorToFacet(uint256 id, bytes4 selector) external view returns (address) {
        return _versions[id].selectorToFacet[selector];
    }

    function versionRescueSelector(uint256 id, bytes4 selector) external view returns (bool) {
        return _versions[id].rescueSelectors.contains(bytes32(selector));
    }

    function versionRescueSelectors(uint256 id, uint256 start, uint256 count)
        external
        view
        returns (bytes4[] memory out)
    {
        EnumerableSet.Bytes32Set storage s = _versions[id].rescueSelectors;
        uint256 len = s.length();
        if (start >= len) return new bytes4[](0);
        uint256 end = start + count;
        if (end > len) end = len;
        uint256 outLen = end - start;
        out = new bytes4[](outLen);
        for (uint256 i; i < outLen; i++) {
            out[i] = bytes4(s.at(start + i));
        }
    }

    function versionInfo(uint256 id) external view returns (address initializer, bool finalized, bool paused) {
        Version storage v = _versions[id];
        return (v.initializer, v.finalized, v.paused);
    }

    function versionSelectors(uint256 id, uint256 start, uint256 count) external view returns (bytes4[] memory out) {
        EnumerableSet.Bytes32Set storage s = _versions[id].selectorSet;
        uint256 len = s.length();
        if (start >= len) return new bytes4[](0);
        uint256 end = start + count;
        if (end > len) end = len;
        uint256 outLen = end - start;
        out = new bytes4[](outLen);
        for (uint256 i; i < outLen; i++) {
            out[i] = bytes4(s.at(start + i));
        }
    }

    function computeBatcherAddress(address user) external view returns (address) {
        return Clones.predictDeterministicAddressWithImmutableArgs(
            implementation, abi.encode(user), keccak256(abi.encode(user)), address(this)
        );
    }

    function renounceOwnership() public view override onlyOwner {
        revert("disabled");
    }
}
