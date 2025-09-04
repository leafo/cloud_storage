# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Build
- `make build` or `moonc cloud_storage/` - Compile MoonScript files to Lua
- `make local` - Build and install locally with LuaRocks (lua 5.1)

### Linting
- `moonc -l FILE...` - Lint MoonScript files to verify syntax and coding standards

### Testing 
- `busted` - Run all tests using the Busted framework
- `busted spec/cloud_storage_spec.moon` - Run specific test file

### Package Management
- `luarocks make --local cloud_storage-dev-1.rockspec` - Install locally for development
- `luarocks pack cloud_storage-dev-1.rockspec` - Create source rock package

## Project Architecture

This is a Lua library written in MoonScript for accessing Google Cloud Storage and Cloudflare R2. The codebase follows a modular design:

### MoonScript Development
- Source files are written in MoonScript (`.moon` files)
- ONLY edit `.moon` files - never edit the generated `.lua` files directly
- Both `.moon` and `.lua` files are checked into the repo for portability
- Use `moonc` to compile MoonScript to Lua
- Always lint with `moonc -l` before committing changes

### Core Modules
- `cloud_storage/init.moon` - Main module entry point with version info
- `cloud_storage/google.moon` - Google Cloud Storage API implementation
- `cloud_storage/oauth.moon` - OAuth2 authentication for Google services
- `cloud_storage/r2.moon` - Cloudflare R2 compatible storage interface
- `cloud_storage/http.moon` - HTTP client abstraction layer
- `cloud_storage/multipart.moon` - Multipart upload functionality
- `cloud_storage/mock.moon` - Mock implementation for testing

### Authentication
The library supports two authentication methods:
1. JSON service account keys (recommended)
2. P12/PEM private key files with service account email

### HTTP Client
Uses `socket.http` by default but supports custom HTTP clients through the `cloud_storage.http` module's `set()` function.

### Code Style
- Written in MoonScript (`.moon` files) which compiles to Lua
- Lua files are generated artifacts and should not be edited directly
- Test files use Busted framework with MoonScript syntax
- Follow existing patterns for error handling: return `nil, error_message, error_object` on failure
- Use `moonc -l` to verify syntax and coding standards

### Dependencies
Key runtime dependencies (from rockspec):
- `luasocket` - HTTP client and networking
- `lua-cjson` - JSON parsing
- `luaossl` - Cryptographic operations
- `date` - Date/time handling
- `luaexpat` - XML parsing
- `mimetypes` - MIME type detection
