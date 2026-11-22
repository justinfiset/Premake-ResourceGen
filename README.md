# Premake-ResourceGen

A Premake-integrated code generator for embedding files into C++ projects.

Premake-ResourceGen transforms arbitrary files into C++20 modules, allowing resources to be embedded directly into your application without requiring external files at runtime.

## Features

- Generate C++20 modules from arbitrary files.
- Generate resource identifiers based on file paths.
- Support virtual paths for flexible resource organization.
- Configurable C++ namespaces.
- Embed resources as compile-time constants.
- Avoid unnecessary rebuilds by only updating generated files when their content changes.

## Requirements

- C++20-compatible compiler with module support.
- [Premake](https://premake.github.io/).

## Usage

Load the generator from your `premake5.lua`:

```lua
local resourcegen = dofile(path.join(
    _MAIN_SCRIPT_DIR,
    "vendor/Premake-ResourceGen/init.lua"
))
```

### Generating icons

Use `GenerateResources` to generate a C++ module containing a constant for each matching file.

```lua
resourcegen.GenerateResources({
    rootDir = path.getabsolute("Assets"),
    uriPrefix = "editor://",
    outFile = path.getabsolute("Generated/Icons.ixx"),

    namespace = "MyEngine::Resources",
    moduleName = "MyEngine.Resources.Icons",

    namespaceFromPath = true,
    extensions = { ".png", ".svg" }
})
```

For example, given the following directory structure:

```text
Assets/Icons/
├── Light/
│   ├── Save.png
│   └── Open.png
└── Dark/
    └── Save.png
```

The generated module contains:

```cpp
export module MyEngine.Editor.Icons;

export namespace MyEngine::Editor::Icons
{
    inline constexpr const char* DarkSave =
        "editor://Icons/Dark/Save.png";

    inline constexpr const char* LightOpen =
        "editor://Icons/Light/Open.png";

    inline constexpr const char* LightSave =
        "editor://Icons/Light/Save.png";
}
```

### Generator options

| Option                | Required | Description                                                           |
| --------------------- | -------- | --------------------------------------------------------------------- |
| `rootDir`             | Yes      | Absolute directory to scan.                                           |
| `uriPrefix`           | Yes      | Virtual path prefix for generated resource paths.                     |
| `outFile`             | Yes      | Absolute output `.ixx` file path.                                     |
| `namespace`           | Yes      | C++ namespace for generated constants.                                |
| `moduleName`          | Yes      | Generated C++ module name.                                            |
| `extensions`          | No       | File extensions to include. Defaults to `{ ".png" }`.                 |
| `includeFolderInName` | No       | Include directory names in generated identifiers. Defaults to `true`. |

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
