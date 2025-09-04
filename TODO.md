# Test Coverage TODO

This document tracks missing test coverage areas in the cloud_storage library. Tests should be added to `spec/cloud_storage_spec.moon` using the Busted framework.

## Priority: CRITICAL (Core Authentication & Infrastructure)

### OAuth Class Methods (5/5 tested) ✅
- [x] `OAuth:get_access_token()` - Token retrieval with caching
- [x] `OAuth:refresh_access_token()` - Token refresh from Google OAuth
- [x] `OAuth:sign_string(string)` - Cryptographic string signing
- [x] `OAuth:_load_private_key(str)` - Private key loading from string
- [x] `OAuth:_private_key()` - Private key loading from file
- [x] Error handling for invalid keys/authentication failures

### LOMFormatter Class Methods (0/4 tested)
- [ ] `LOMFormatter:format(res, code, headers)` - XML response formatting
- [ ] `LOMFormatter:ListAllMyBucketsResult(res)` - Bucket list XML parsing
- [ ] `LOMFormatter:ListBucketResult(res)` - File list XML parsing  
- [ ] `LOMFormatter:Error(res)` - Error response XML parsing

## Priority: HIGH (Missing Core Storage Operations)

### CloudStorage Class Methods (14/15 well-tested) ✅
- [x] `CloudStorage:get_service()` - Service endpoint functionality
- [x] `CloudStorage:head_file(bucket, key)` - File metadata retrieval
- [x] `CloudStorage:put_file(bucket, fname, options)` - File upload from filesystem
- [x] `CloudStorage:put_file_acl(bucket, key, acl)` - ACL management
- [x] `CloudStorage:compose(bucket, key, source_keys, options)` - File composition
- [x] `CloudStorage:start_resumable_upload(bucket, key, options)` - Resumable uploads
- [x] `CloudStorage:encode_and_sign_policy(expiration, conditions)` - Policy encoding
- [x] Comprehensive error handling for all methods with validation
- [ ] Additional edge cases (malformed inputs, network failures, etc.)

## Priority: MEDIUM (Alternative Implementations)

### MockStorage Class Methods (0/11 tested)
- [ ] `MockStorage:new(dir_name, url_prefix)` - Constructor
- [ ] `MockStorage:bucket(bucket)` - Bucket wrapper creation
- [ ] `MockStorage:_full_path(bucket, key)` - Path construction
- [ ] `MockStorage:file_url(bucket, key)` - URL generation
- [ ] `MockStorage:get_service()` - Service endpoint (should error)
- [ ] `MockStorage:get_bucket(bucket)` - File listing via filesystem
- [ ] `MockStorage:put_file_string(bucket, key, data, options)` - String upload
- [ ] `MockStorage:put_file(bucket, fname, options)` - File upload
- [ ] `MockStorage:delete_file(bucket, key)` - File deletion
- [ ] `MockStorage:get_file(bucket, key)` - File retrieval (should error)
- [ ] `MockStorage:head_file(bucket, key)` - File metadata (should error)

### Multipart Module Functions (0/5 tested)
- [ ] `encode(params)` - Multipart form encoding
- [ ] `encode_tbl(params)` - Table-based multipart encoding
- [ ] `File:new(fname)` - File object constructor
- [ ] `File:mime()` - MIME type detection
- [ ] `File:content()` - File content reading

### Bucket Class Methods (0/2+ tested)
- [ ] `Bucket:new(bucket_name, storage)` - Constructor
- [ ] Method forwarding functionality (list, delete_file, get_file, etc.)
- [ ] Integration with both CloudStorage and MockStorage backends

## Priority: LOW (Future/Incomplete Features)

### R2 Module Methods (0/2 tested)
- [ ] `CloudflareR2:base_url(account_id)` - URL construction
- [ ] `CloudflareR2:list_buckets()` - Bucket listing (incomplete implementation)

### Utility Functions
- [ ] `url_encode_key()` - Additional edge cases beyond current tests

## Integration Test Areas (0/4 tested)

- [ ] **Authentication Workflows** - End-to-end OAuth flow with real/mock responses
- [ ] **File Upload/Download Workflows** - Complete file lifecycle testing
- [ ] **Cross-Storage Compatibility** - Same operations work on CloudStorage and MockStorage
- [ ] **Error Propagation** - Errors bubble up correctly through Bucket -> Storage layers

## Testing Guidelines

### Test Structure
- Follow existing patterns in `spec/cloud_storage_spec.moon`
- Use `describe` blocks to group related functionality
- Use `before_each`/`after_each` for setup/teardown
- Mock HTTP requests for CloudStorage tests
- Use filesystem operations for MockStorage tests

### Key Testing Principles
- Test both success and failure cases
- Validate input parameter checking (nil, empty string, wrong type)
- Verify HTTP request structure for CloudStorage methods
- Check file system operations for MockStorage methods
- Test authentication token caching and refresh logic
- Validate XML parsing with various response formats

### Dependencies
- Some tests require test key files (spec/test_key.pem, spec/test_key.json)
- HTTP mocking requires the existing test infrastructure
- MockStorage tests need temporary directory handling
- LOMFormatter tests need sample XML responses

## Progress Tracking

**Total Methods Identified**: ~35
**Currently Well-Tested**: ~10
**Coverage Goal**: 90%+ of public methods

Update this file as tests are added and remove completed items.