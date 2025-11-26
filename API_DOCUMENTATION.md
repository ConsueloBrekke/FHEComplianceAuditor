# API Documentation

## Core Functions

### registerComplianceData
Register compliance data (plaintext encrypted on-chain)
- Parameters: dataPoints (uint32), riskScore (uint8), complianceScore (uint8), flags (bool)
- Access: onlyDataController
- Validation: Bounds checking on all inputs

### registerComplianceDataEncrypted
Register pre-encrypted compliance data
- Parameters: Encrypted inputs with proof
- Access: onlyDataController + payable
- Requires: MIN_AUDIT_FEE deposit

### scheduleAudit
Schedule audit with Gateway callback deposit
- Parameters: auditee (address), standard (enum)
- Access: onlyAuthorizedAuditor + payable
- Requires: MIN_AUDIT_FEE (0.001 ETH)
- Returns: Audit ID via event

### requestAuditDecryption
Request Gateway decryption of audit results
- Parameters: auditId (uint32)
- Access: Auditor or owner
- Initiates: Async Gateway processing

### auditDecryptionCallback
Gateway callback (automatic)
- Parameters: requestId, cleartexts, proof
- Called by: Gateway after decryption
- Verifies: Cryptographic proof
- Updates: Audit state

### claimTimeoutRefund
Claim refund for timed-out request
- Parameters: requestId (uint256)
- Access: Request owner
- Available: After DECRYPTION_TIMEOUT (1 hour)
- Returns: Deposit refund

### withdrawPendingRefund
Withdraw accumulated refunds
- Parameters: None
- Access: Any user with pending refunds
- Returns: Total pending amount

## View Functions

### getComplianceStatus
Query compliance profile
- Returns: Data flags, dates, controller

### getAuditInfo
Query audit details
- Returns: Standard, status, risk, parties, timestamps

### getDecryptionRequestStatus
Query decryption request
- Returns: Audit ID, requester, timing, status, timeout flag

### getPendingRefund
Check pending refund amount
- Returns: Amount (wei)

### getUserPendingRequests
Get user pending request IDs
- Returns: Array of request IDs

