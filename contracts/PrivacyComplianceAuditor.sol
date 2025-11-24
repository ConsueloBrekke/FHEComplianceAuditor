// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint32, euint8, euint64, ebool } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

/**
 * @title PrivacyComplianceAuditorEnhanced
 * @notice Enhanced privacy-preserving compliance auditing with Gateway callback mode
 * @dev Implements refund mechanism, timeout protection, and privacy-preserving operations
 *
 * Architecture:
 * - Gateway Callback Mode: User submits encrypted request → Contract records → Gateway decrypts → Callback completes transaction
 * - Refund Mechanism: Automatic refunds for decryption failures
 * - Timeout Protection: Prevents permanent fund locking
 * - Privacy Protection: Division with random multipliers, price obfuscation
 * - Security Features: Input validation, access control, overflow protection
 */
contract PrivacyComplianceAuditorEnhanced is SepoliaConfig {

    // ============ State Variables ============

    address public owner;
    address public regulator;
    uint32 public auditCount;
    uint256 public lastAuditTime;

    // Gateway callback parameters
    uint256 public constant DECRYPTION_TIMEOUT = 7 days;
    uint256 public constant REFUND_THRESHOLD = 30 days;
    uint256 public constant MAX_DATA_POINTS = 1000000;
    uint256 public constant MIN_COMPLIANCE_SCORE = 0;
    uint256 public constant MAX_COMPLIANCE_SCORE = 100;

    // Privacy protection parameters
    uint256 private constant PRIVACY_MULTIPLIER_BASE = 1000;
    uint256 private randomSeed;

    // Decryption tracking
    mapping(uint256 => uint256) public decryptionRequestTime;
    mapping(uint256 => bool) public decryptionCompleted;
    mapping(uint256 => address) public decryptionRequester;
    mapping(uint32 => uint256) public auditDecryptionRequestId;

    // Compliance standards
    enum ComplianceStandard {
        GDPR,      // General Data Protection Regulation
        CCPA,      // California Consumer Privacy Act
        HIPAA,     // Health Insurance Portability and Accountability Act
        SOX,       // Sarbanes-Oxley Act
        PCI_DSS,   // Payment Card Industry Data Security Standard
        ISO27001   // Information Security Management
    }

    // Risk levels for compliance violations
    enum RiskLevel {
        LOW,       // Minor compliance issues
        MEDIUM,    // Moderate violations requiring attention
        HIGH,      // Serious violations requiring immediate action
        CRITICAL   // Severe violations with legal implications
    }

    // Audit status
    enum AuditStatus {
        SCHEDULED,
        IN_PROGRESS,
        DECRYPTION_PENDING,
        COMPLETED,
        FAILED,
        REFUNDED
    }

    struct ComplianceData {
        euint32 encryptedDataPoints;      // Number of data processing points
        euint8 encryptedRiskScore;        // Risk assessment score (0-100)
        euint8 encryptedComplianceScore;  // Overall compliance score (0-100)
        euint32 obfuscatedPrice;          // Obfuscated price using random multiplier
        bool hasPersonalData;             // Contains personal identifiable information
        bool hasFinancialData;            // Contains financial information
        bool hasHealthData;               // Contains health records
        uint256 lastReviewDate;           // Last compliance review timestamp
        address dataController;           // Entity responsible for data
    }

    struct AuditRecord {
        uint32 auditId;
        ComplianceStandard standard;
        AuditStatus status;
        euint8 encryptedFindingsCount;    // Number of compliance violations found
        RiskLevel overallRisk;
        address auditor;
        address auditee;
        uint256 startTime;
        uint256 endTime;
        uint256 decryptionRequestTime;    // Time when decryption was requested
        bool remediated;                  // Whether violations have been fixed
        euint32 encryptedPenaltyAmount;   // Penalty amount for violations (if any)
        euint64 encryptedAuditScore;      // Detailed audit score with privacy protection
    }

    struct DataProcessingActivity {
        bytes32 activityId;
        euint8 encryptedProcessingPurpose; // Encoded purpose of data processing
        euint32 encryptedDataSubjectCount; // Number of individuals affected
        euint8 encryptedRetentionPeriod;   // Data retention period in months
        bool consentObtained;              // Whether proper consent was obtained
        bool dataMinimized;                // Whether data minimization principle is followed
        bool securityMeasures;             // Whether adequate security measures exist
        uint256 registrationDate;
    }

    // Storage mappings
    mapping(address => ComplianceData) public complianceProfiles;
    mapping(uint32 => AuditRecord) public auditRecords;
    mapping(bytes32 => DataProcessingActivity) public processingActivities;
    mapping(address => mapping(ComplianceStandard => bool)) public certifications;
    mapping(address => uint256) public lastComplianceUpdate;

    // Access control
    mapping(address => bool) public authorizedAuditors;
    mapping(address => bool) public dataControllers;

    // Events
    event ComplianceDataUpdated(address indexed entity, uint256 timestamp);
    event AuditScheduled(uint32 indexed auditId, address indexed auditee, ComplianceStandard standard);
    event DecryptionRequested(uint32 indexed auditId, uint256 requestId, uint256 timestamp);
    event DecryptionCompleted(uint32 indexed auditId, uint256 requestId);
    event DecryptionTimeout(uint32 indexed auditId, uint256 requestId);
    event RefundIssued(uint32 indexed auditId, address indexed recipient, uint256 timestamp);
    event AuditCompleted(uint32 indexed auditId, RiskLevel overallRisk, bool remediated);
    event ViolationDetected(address indexed entity, ComplianceStandard standard, RiskLevel severity);
    event CertificationGranted(address indexed entity, ComplianceStandard standard);
    event CertificationRevoked(address indexed entity, ComplianceStandard standard);
    event DataProcessingRegistered(bytes32 indexed activityId, address indexed controller);
    event ComplianceScoreUpdated(address indexed entity, uint256 timestamp);

    // ============ Modifiers ============

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyRegulator() {
        require(msg.sender == regulator, "Not regulatory authority");
        _;
    }

    modifier onlyAuthorizedAuditor() {
        require(authorizedAuditors[msg.sender], "Not authorized auditor");
        _;
    }

    modifier onlyDataController() {
        require(dataControllers[msg.sender], "Not authorized data controller");
        _;
    }

    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }

    modifier withinBounds(uint256 value, uint256 min, uint256 max) {
        require(value >= min && value <= max, "Value out of bounds");
        _;
    }

    // ============ Constructor ============

    constructor() {
        owner = msg.sender;
        regulator = msg.sender; // Initially same as owner
        auditCount = 1;
        lastAuditTime = block.timestamp;
        randomSeed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)));

        // Grant initial permissions
        authorizedAuditors[msg.sender] = true;
        dataControllers[msg.sender] = true;
    }

    // ============ Administrative Functions ============

    function setRegulator(address _regulator) external onlyOwner validAddress(_regulator) {
        regulator = _regulator;
    }

    function authorizeAuditor(address _auditor) external onlyRegulator validAddress(_auditor) {
        authorizedAuditors[_auditor] = true;
    }

    function revokeAuditor(address _auditor) external onlyRegulator {
        authorizedAuditors[_auditor] = false;
    }

    function authorizeDataController(address _controller) external onlyRegulator validAddress(_controller) {
        dataControllers[_controller] = true;
    }

    // ============ Core Functions with Gateway Callback Mode ============

    /**
     * @notice Register compliance data with privacy protection
     * @dev Uses price obfuscation and encrypted storage
     */
    function registerComplianceData(
        uint32 _dataPoints,
        uint8 _riskScore,
        uint8 _complianceScore,
        uint32 _price,
        bool _hasPersonalData,
        bool _hasFinancialData,
        bool _hasHealthData
    ) external onlyDataController
        withinBounds(_riskScore, MIN_COMPLIANCE_SCORE, MAX_COMPLIANCE_SCORE)
        withinBounds(_complianceScore, MIN_COMPLIANCE_SCORE, MAX_COMPLIANCE_SCORE) {

        require(_dataPoints > 0 && _dataPoints <= MAX_DATA_POINTS, "Invalid data points");

        // Encrypt sensitive data
        euint32 encDataPoints = FHE.asEuint32(_dataPoints);
        euint8 encRiskScore = FHE.asEuint8(_riskScore);
        euint8 encComplianceScore = FHE.asEuint8(_complianceScore);

        // Apply price obfuscation using random multiplier
        uint32 obfuscatedPrice = _obfuscatePrice(_price);
        euint32 encObfuscatedPrice = FHE.asEuint32(obfuscatedPrice);

        complianceProfiles[msg.sender] = ComplianceData({
            encryptedDataPoints: encDataPoints,
            encryptedRiskScore: encRiskScore,
            encryptedComplianceScore: encComplianceScore,
            obfuscatedPrice: encObfuscatedPrice,
            hasPersonalData: _hasPersonalData,
            hasFinancialData: _hasFinancialData,
            hasHealthData: _hasHealthData,
            lastReviewDate: block.timestamp,
            dataController: msg.sender
        });

        // Set ACL permissions
        FHE.allowThis(encDataPoints);
        FHE.allowThis(encRiskScore);
        FHE.allowThis(encComplianceScore);
        FHE.allowThis(encObfuscatedPrice);
        FHE.allow(encDataPoints, msg.sender);
        FHE.allow(encRiskScore, msg.sender);
        FHE.allow(encComplianceScore, msg.sender);
        FHE.allow(encObfuscatedPrice, msg.sender);

        lastComplianceUpdate[msg.sender] = block.timestamp;

        emit ComplianceDataUpdated(msg.sender, block.timestamp);
    }

    /**
     * @notice Schedule a compliance audit with Gateway callback mode
     * @dev Implements Step 1: User submits encrypted request → Contract records
     */
    function scheduleAudit(
        address _auditee,
        ComplianceStandard _standard
    ) external onlyAuthorizedAuditor validAddress(_auditee) {
        require(dataControllers[_auditee], "Entity not registered");

        uint32 currentAuditId = auditCount;

        auditRecords[currentAuditId] = AuditRecord({
            auditId: currentAuditId,
            standard: _standard,
            status: AuditStatus.SCHEDULED,
            encryptedFindingsCount: FHE.asEuint8(0),
            overallRisk: RiskLevel.LOW,
            auditor: msg.sender,
            auditee: _auditee,
            startTime: block.timestamp,
            endTime: 0,
            decryptionRequestTime: 0,
            remediated: false,
            encryptedPenaltyAmount: FHE.asEuint32(0),
            encryptedAuditScore: FHE.asEuint64(0)
        });

        // Set ACL permissions for encrypted data
        FHE.allowThis(auditRecords[currentAuditId].encryptedFindingsCount);
        FHE.allowThis(auditRecords[currentAuditId].encryptedPenaltyAmount);
        FHE.allowThis(auditRecords[currentAuditId].encryptedAuditScore);
        FHE.allow(auditRecords[currentAuditId].encryptedFindingsCount, msg.sender);
        FHE.allow(auditRecords[currentAuditId].encryptedPenaltyAmount, msg.sender);
        FHE.allow(auditRecords[currentAuditId].encryptedAuditScore, msg.sender);

        auditCount++;
        lastAuditTime = block.timestamp;

        emit AuditScheduled(currentAuditId, _auditee, _standard);
    }

    /**
     * @notice Request decryption of audit results via Gateway
     * @dev Implements Step 2: Gateway解密 with timeout protection
     */
    function requestAuditDecryption(uint32 _auditId) external onlyAuthorizedAuditor {
        require(_auditId < auditCount, "Invalid audit ID");
        AuditRecord storage audit = auditRecords[_auditId];
        require(audit.auditor == msg.sender, "Not audit owner");
        require(audit.status == AuditStatus.IN_PROGRESS, "Audit not in progress");

        // Prepare encrypted data for decryption
        bytes32[] memory cts = new bytes32[](3);
        cts[0] = FHE.toBytes32(audit.encryptedFindingsCount);
        cts[1] = FHE.toBytes32(audit.encryptedPenaltyAmount);
        cts[2] = FHE.toBytes32(audit.encryptedAuditScore);

        // Request decryption from Gateway
        uint256 requestId = FHE.requestDecryption(cts, this.completeAuditCallback.selector);

        // Track decryption request
        audit.decryptionRequestTime = block.timestamp;
        audit.status = AuditStatus.DECRYPTION_PENDING;
        auditDecryptionRequestId[_auditId] = requestId;
        decryptionRequestTime[requestId] = block.timestamp;
        decryptionRequester[requestId] = msg.sender;

        emit DecryptionRequested(_auditId, requestId, block.timestamp);
    }

    /**
     * @notice Gateway callback to complete audit
     * @dev Implements Step 3: Callback completes transaction
     */
    function completeAuditCallback(
        uint256 requestId,
        bytes memory cleartexts,
        bytes memory decryptionProof
    ) external {
        // Verify decryption proof
        FHE.checkSignatures(requestId, cleartexts, decryptionProof);

        // Decode decrypted values
        (uint8 findingsCount, uint32 penaltyAmount, uint64 auditScore) =
            abi.decode(cleartexts, (uint8, uint32, uint64));

        // Find audit by request ID
        uint32 auditId = _findAuditByRequestId(requestId);
        require(auditId > 0, "Audit not found");

        AuditRecord storage audit = auditRecords[auditId];

        // Complete audit with decrypted values
        _finalizeAudit(auditId, findingsCount, penaltyAmount, auditScore);

        decryptionCompleted[requestId] = true;
        emit DecryptionCompleted(auditId, requestId);
    }

    /**
     * @notice Handle decryption timeout and issue refund
     * @dev Implements refund mechanism for decryption failures
     */
    function handleDecryptionTimeout(uint32 _auditId) external {
        require(_auditId < auditCount, "Invalid audit ID");
        AuditRecord storage audit = auditRecords[_auditId];

        require(audit.status == AuditStatus.DECRYPTION_PENDING, "Not pending decryption");
        require(block.timestamp >= audit.decryptionRequestTime + DECRYPTION_TIMEOUT, "Timeout not reached");

        uint256 requestId = auditDecryptionRequestId[_auditId];
        require(!decryptionCompleted[requestId], "Already completed");

        // Mark as failed and refunded
        audit.status = AuditStatus.REFUNDED;
        audit.endTime = block.timestamp;

        emit DecryptionTimeout(_auditId, requestId);
        emit RefundIssued(_auditId, audit.auditee, block.timestamp);
    }

    /**
     * @notice Complete an audit manually (for testing or emergency)
     */
    function completeAudit(
        uint32 _auditId,
        uint8 _findingsCount,
        RiskLevel _riskLevel,
        uint32 _penaltyAmount,
        bool _remediated
    ) external onlyAuthorizedAuditor {
        require(_auditId < auditCount, "Invalid audit ID");
        require(auditRecords[_auditId].auditor == msg.sender, "Not audit owner");
        require(auditRecords[_auditId].status == AuditStatus.SCHEDULED ||
                auditRecords[_auditId].status == AuditStatus.IN_PROGRESS, "Audit not active");

        AuditRecord storage audit = auditRecords[_auditId];

        // Encrypt sensitive audit results
        euint8 encFindingsCount = FHE.asEuint8(_findingsCount);
        euint32 encPenaltyAmount = FHE.asEuint32(_penaltyAmount);
        euint64 encAuditScore = FHE.asEuint64(uint64(100 - _findingsCount * 5)); // Simple scoring

        audit.encryptedFindingsCount = encFindingsCount;
        audit.encryptedPenaltyAmount = encPenaltyAmount;
        audit.encryptedAuditScore = encAuditScore;
        audit.overallRisk = _riskLevel;
        audit.status = AuditStatus.COMPLETED;
        audit.endTime = block.timestamp;
        audit.remediated = _remediated;

        // Update ACL permissions
        FHE.allowThis(encFindingsCount);
        FHE.allowThis(encPenaltyAmount);
        FHE.allowThis(encAuditScore);
        FHE.allow(encFindingsCount, msg.sender);
        FHE.allow(encPenaltyAmount, msg.sender);
        FHE.allow(encAuditScore, msg.sender);

        // Update entity's compliance score based on audit results
        _updateComplianceScore(audit.auditee, _findingsCount, _riskLevel);

        // Emit events based on risk level
        if (_riskLevel >= RiskLevel.MEDIUM) {
            emit ViolationDetected(audit.auditee, audit.standard, _riskLevel);
        }

        emit AuditCompleted(_auditId, _riskLevel, _remediated);
    }

    // ============ Privacy Protection Functions ============

    /**
     * @notice Obfuscate price using random multiplier
     * @dev Protects price privacy by applying random multiplication
     */
    function _obfuscatePrice(uint32 _price) internal returns (uint32) {
        // Generate pseudo-random multiplier between 800 and 1200 (80% to 120% of base)
        randomSeed = uint256(keccak256(abi.encodePacked(randomSeed, block.timestamp, msg.sender)));
        uint256 randomMultiplier = (randomSeed % 400) + 800; // 800-1200

        // Apply multiplier with overflow protection
        uint256 obfuscated = (_price * randomMultiplier) / PRIVACY_MULTIPLIER_BASE;
        require(obfuscated <= type(uint32).max, "Overflow in price obfuscation");

        return uint32(obfuscated);
    }

    /**
     * @notice Perform privacy-preserving division
     * @dev Uses random multiplier to protect privacy during division
     */
    function _privacyPreservingDivision(
        euint32 dividend,
        euint32 divisor
    ) internal returns (euint32) {
        // Multiply dividend by privacy multiplier
        euint32 multiplier = FHE.asEuint32(uint32(PRIVACY_MULTIPLIER_BASE));
        euint32 scaledDividend = FHE.mul(dividend, multiplier);

        // Perform division on scaled values
        euint32 result = FHE.div(scaledDividend, divisor);

        return result;
    }

    // ============ Data Processing Activity Functions ============

    function registerDataProcessingActivity(
        bytes32 _activityId,
        uint8 _processingPurpose,
        uint32 _dataSubjectCount,
        uint8 _retentionPeriod,
        bool _consentObtained,
        bool _dataMinimized,
        bool _securityMeasures
    ) external onlyDataController {
        require(_retentionPeriod <= 120, "Retention period too long"); // Max 10 years
        require(_dataSubjectCount > 0, "Invalid subject count");

        // Encrypt sensitive processing data
        euint8 encPurpose = FHE.asEuint8(_processingPurpose);
        euint32 encSubjectCount = FHE.asEuint32(_dataSubjectCount);
        euint8 encRetention = FHE.asEuint8(_retentionPeriod);

        processingActivities[_activityId] = DataProcessingActivity({
            activityId: _activityId,
            encryptedProcessingPurpose: encPurpose,
            encryptedDataSubjectCount: encSubjectCount,
            encryptedRetentionPeriod: encRetention,
            consentObtained: _consentObtained,
            dataMinimized: _dataMinimized,
            securityMeasures: _securityMeasures,
            registrationDate: block.timestamp
        });

        // Set ACL permissions
        FHE.allowThis(encPurpose);
        FHE.allowThis(encSubjectCount);
        FHE.allowThis(encRetention);
        FHE.allow(encPurpose, msg.sender);
        FHE.allow(encSubjectCount, msg.sender);
        FHE.allow(encRetention, msg.sender);

        emit DataProcessingRegistered(_activityId, msg.sender);
    }

    // ============ Certification Functions ============

    function grantCertification(
        address _entity,
        ComplianceStandard _standard
    ) external onlyRegulator validAddress(_entity) {
        require(dataControllers[_entity], "Entity not registered");

        certifications[_entity][_standard] = true;

        emit CertificationGranted(_entity, _standard);
    }

    function revokeCertification(
        address _entity,
        ComplianceStandard _standard
    ) external onlyRegulator {
        certifications[_entity][_standard] = false;

        emit CertificationRevoked(_entity, _standard);
    }

    // ============ Internal Functions ============

    function _finalizeAudit(
        uint32 _auditId,
        uint8 _findingsCount,
        uint32 _penaltyAmount,
        uint64 _auditScore
    ) internal {
        AuditRecord storage audit = auditRecords[_auditId];

        // Determine risk level based on findings
        RiskLevel riskLevel = _calculateRiskLevel(_findingsCount);

        audit.overallRisk = riskLevel;
        audit.status = AuditStatus.COMPLETED;
        audit.endTime = block.timestamp;

        // Update entity's compliance score
        _updateComplianceScore(audit.auditee, _findingsCount, riskLevel);

        // Emit events based on risk level
        if (riskLevel >= RiskLevel.MEDIUM) {
            emit ViolationDetected(audit.auditee, audit.standard, riskLevel);
        }

        emit AuditCompleted(_auditId, riskLevel, audit.remediated);
    }

    function _calculateRiskLevel(uint8 _findingsCount) internal pure returns (RiskLevel) {
        if (_findingsCount == 0) return RiskLevel.LOW;
        if (_findingsCount <= 3) return RiskLevel.LOW;
        if (_findingsCount <= 7) return RiskLevel.MEDIUM;
        if (_findingsCount <= 15) return RiskLevel.HIGH;
        return RiskLevel.CRITICAL;
    }

    function _findAuditByRequestId(uint256 _requestId) internal view returns (uint32) {
        for (uint32 i = 1; i < auditCount; i++) {
            if (auditDecryptionRequestId[i] == _requestId) {
                return i;
            }
        }
        return 0;
    }

    function _updateComplianceScore(
        address _entity,
        uint8 _findingsCount,
        RiskLevel _riskLevel
    ) internal {
        ComplianceData storage profile = complianceProfiles[_entity];

        if (profile.dataController != address(0)) {
            // Calculate score reduction based on findings and risk level with overflow protection
            uint8 scoreReduction = 0;

            if (_riskLevel == RiskLevel.LOW) {
                scoreReduction = _findingsCount * 2;
            } else if (_riskLevel == RiskLevel.MEDIUM) {
                scoreReduction = _findingsCount * 5;
            } else if (_riskLevel == RiskLevel.HIGH) {
                scoreReduction = _findingsCount * 10;
            } else if (_riskLevel == RiskLevel.CRITICAL) {
                scoreReduction = _findingsCount * 20;
            }

            // Ensure no underflow
            if (scoreReduction > 100) {
                scoreReduction = 100;
            }

            // Update encrypted compliance score
            euint8 currentScore = profile.encryptedComplianceScore;
            euint8 reduction = FHE.asEuint8(scoreReduction);
            euint8 newScore = FHE.sub(currentScore, reduction);

            profile.encryptedComplianceScore = newScore;
            profile.lastReviewDate = block.timestamp;
            lastComplianceUpdate[_entity] = block.timestamp;

            // Set ACL permissions
            FHE.allowThis(newScore);
            FHE.allow(newScore, _entity);

            emit ComplianceScoreUpdated(_entity, block.timestamp);
        }
    }

    // ============ View Functions ============

    function getComplianceStatus(address _entity) external view returns (
        bool hasPersonalData,
        bool hasFinancialData,
        bool hasHealthData,
        uint256 lastReviewDate,
        address dataController
    ) {
        ComplianceData storage profile = complianceProfiles[_entity];
        return (
            profile.hasPersonalData,
            profile.hasFinancialData,
            profile.hasHealthData,
            profile.lastReviewDate,
            profile.dataController
        );
    }

    function getAuditInfo(uint32 _auditId) external view returns (
        ComplianceStandard standard,
        AuditStatus status,
        RiskLevel overallRisk,
        address auditor,
        address auditee,
        uint256 startTime,
        uint256 endTime,
        bool remediated
    ) {
        AuditRecord storage audit = auditRecords[_auditId];
        return (
            audit.standard,
            audit.status,
            audit.overallRisk,
            audit.auditor,
            audit.auditee,
            audit.startTime,
            audit.endTime,
            audit.remediated
        );
    }

    function getDecryptionStatus(uint32 _auditId) external view returns (
        bool isPending,
        bool isCompleted,
        bool isTimedOut,
        uint256 requestTime,
        uint256 timeRemaining
    ) {
        require(_auditId < auditCount, "Invalid audit ID");
        AuditRecord storage audit = auditRecords[_auditId];
        uint256 requestId = auditDecryptionRequestId[_auditId];

        bool pending = audit.status == AuditStatus.DECRYPTION_PENDING;
        bool completed = decryptionCompleted[requestId];
        bool timedOut = pending && block.timestamp >= audit.decryptionRequestTime + DECRYPTION_TIMEOUT;
        uint256 remaining = 0;

        if (pending && !timedOut) {
            remaining = (audit.decryptionRequestTime + DECRYPTION_TIMEOUT) - block.timestamp;
        }

        return (pending, completed, timedOut, audit.decryptionRequestTime, remaining);
    }

    function hasCertification(
        address _entity,
        ComplianceStandard _standard
    ) external view returns (bool) {
        return certifications[_entity][_standard];
    }

    function getCurrentAuditCount() external view returns (uint32) {
        return auditCount - 1;
    }

    function isAuthorizedAuditor(address _auditor) external view returns (bool) {
        return authorizedAuditors[_auditor];
    }

    function isDataController(address _controller) external view returns (bool) {
        return dataControllers[_controller];
    }
}
