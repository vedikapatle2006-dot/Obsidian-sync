// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Obsidian Sync
 * @dev Decentralized file synchronization metadata registry
 *      Inspired by Obsidian.md's local-first philosophy but with on-chain immutability
 */
contract ObsidianSync {
    address public immutable owner;

    struct FileRecord {
        string fileName;
        bytes32 contentHash;    // keccak256 hash of file content
        string cid;             // IPFS/Arweave/Filecoin CID (optional)
        uint256 lastModified;
        uint256 version;
        address lastEditor;
    }

    // user => vaultId => filePath => FileRecord
    mapping(address => mapping(string => mapping(string => FileRecord))) public vaults;

    // vaultId => list of authorized editors
    mapping(address => mapping(string => address[])) public vaultEditors;

    event FileSynced(
        address indexed user,
        string indexed vaultId,
        string indexed filePath,
        bytes32 contentHash,
        string cid,
        uint256 version
    );

    event EditorAdded(address indexed user, string indexed vaultId, address editor);
    event EditorRemoved(address indexed user, string indexed vaultId, address editor);

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Sync (upsert) a file's latest metadata
     */
    function syncFile(
        string calldata vaultId,
        string calldata filePath,
        string calldata fileName,
        bytes32 contentHash,
        string calldata cid
    ) external {
        require(isAuthorized(msg.sender, vaultId), "Not authorized");

        FileRecord storage record = vaults[msg.sender][vaultId][filePath];

        if (record.lastModified == 0) {
            // First time this file is seen
            record.version = 1;
        } else {
            record.version += 1;
        }

        record.fileName = fileName;
        record.contentHash = contentHash;
        record.cid = cid;
        record.lastModified = block.timestamp;
        record.lastEditor = msg.sender;

        emit FileSynced(msg.sender, vaultId, filePath, contentHash, cid, record.version);
    }

    /**
     * @dev Grant edit access to another address for a specific vault
     */
    function addEditor(string calldata vaultId, address editor) external {
        require(msg.sender == ownerOfVault(msg.sender, vaultId), "Only vault owner");
        require(editor != address(0), "Invalid address");

        // Prevent duplicates
        address[] storage editors = vaultEditors[msg.sender][vaultId];
        for (uint i = 0; i < editors.length; i++) {
            if (editors[i] == editor) return;
        }

        vaultEditors[msg.sender][vaultId].push(editor);
        emit EditorAdded(msg.sender, vaultId, editor);
    }

    /**
     * @dev Remove editor access
     */
    function removeEditor(string calldata vaultId, address editor) external {
        require(msg.sender == ownerOfVault(msg.sender, vaultId), "Only vault owner");

        address[] storage editors = vaultEditors[msg.sender][vaultId];
        for (uint i = 0; i < editors.length; i++) {
            if (editors[i] == editor) {
                editors[i] = editors[editors.length - 1];
                editors.pop();
                emit EditorRemoved(msg.sender, vaultId, editor);
                break;
            }
        }
    }

    /**
     * @dev Check if an address is authorized to edit a vault
     */
    function isAuthorized(address user, string calldata vaultId) public view returns (bool) {
        if (user == ownerOfVault(user, vaultId)) return true;

        address[] memory editors = vaultEditors[user][vaultId];
        for (uint i = 0; i < editors.length; i++) {
            if (editors[i] == msg.sender) return true;
        }
        return false;
    }

    /**
     * @dev Internal helper: vault owner is the first one who used it
     */
    function ownerOfVault(address user, string calldata vaultId) internal view returns (address) {
        // Simplified: the creator of the first file in vault is considered owner
        // In production you might want a separate mapping
        return user;
    }

    /**
     * @dev Get latest file record
     */
    function getFile(
        address user,
        string calldata vaultId,
        string calldata filePath
    ) external view returns (FileRecord memory) {
        return vaults[user][vaultId][filePath];
    }
}
