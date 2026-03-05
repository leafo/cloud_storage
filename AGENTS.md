## Development Commands

### Building
- `make build` - Compile MoonScript files to Lua
- `make local` - Build and install locally with LuaRocks (lua 5.1)

### Linting
- `moonc -l FILE...` - Lint MoonScript files to verify syntax and coding standards

### Testing 
- `busted` - Run all tests using the Busted framework
- `busted spec/cloud_storage_spec.moon` - Run specific test file

## Project Architecture

This is a Lua library written in MoonScript for accessing Google Cloud Storage
and Cloudflare R2. The codebase follows a modular design:

### MoonScript Development
- Source files are written in MoonScript (`.moon` files)
- ONLY edit `.moon` files - never edit the generated `.lua` files directly
- Both `.moon` and `.lua` files are checked into the repo for portability
- Use `moonc` to compile MoonScript to Lua
- Always lint with `moonc -l` before committing changes

