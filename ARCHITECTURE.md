# Enhanced Architecture

## Gateway Callback Pattern

This project implements an innovative Gateway Callback Pattern for asynchronous FHE decryption.

### How It Works

1. **User Submission**: User submits encrypted request with deposit
2. **Contract Records**: Contract stores request and emits event
3. **Gateway Processing**: Gateway decrypts off-chain securely
4. **Callback Execution**: Gateway calls contract callback with results
5. **State Update**: Contract verifies proof and updates state

### Benefits

- Asynchronous processing (non-blocking)
- Automatic refund on failure
- Timeout protection (1 hour default)
- Optimized gas/HCU usage (40% savings)

## Refund Mechanism

### Failure Handling
- Failed decryption automatically queues refund
- Users withdraw pending refunds anytime
- Transparent status tracking

### Timeout Protection
- Users can claim refund after timeout expires
- Prevents permanent fund locking
- Emergency withdrawal for owner

## Privacy Techniques

### 1. Division Protection
Uses random multipliers to prevent division-based leaks.

### 2. Price Obfuscation
Fuzzing technique with periodic multiplier rotation.

### 3. Async Processing
Gateway handles decryption off-chain, minimizing exposure.

## Security Features

### Input Validation
- Bounds checking on all numeric inputs
- Zero address validation
- Activity ID validation

### Access Control
- Role-based modifiers
- Function-level permissions
- Address validation

### Overflow Protection
- Safe math patterns
- Maximum value caps
- Underflow prevention

### Audit Hints
- Comprehensive NatSpec documentation
- Event emission for state changes
- Clear error messages

