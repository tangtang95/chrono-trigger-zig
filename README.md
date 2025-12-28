# Chrono Trigger POC with Zig

For steam linux requires to put as launch options:
```sh
WINEDLLOVERRIDES="version=n,b" %command%
```

## Local development

### Requirements

- Zig 0.15.2
- `steam` executable
- Chrono Trigger game installed in Steam

### Build
```sh
zig build
```

### Run the game with the dll
```sh
zig build run -Dgame-path=/absolute/path/to/game/install/path
```

NOTE: Tested only on Linux
