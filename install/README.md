# Quick Install

## Unix/Linux/macOS

```bash
curl -sSL https://raw.githubusercontent.com/automazeio/ccpm/main/ccpm.sh | bash
```

Or with wget:

```bash
wget -qO- https://raw.githubusercontent.com/automazeio/ccpm/main/ccpm.sh | bash
```

## Windows (PowerShell)

```powershell
iwr -useb https://raw.githubusercontent.com/automazeio/ccpm/main/ccpm.bat | iex
```

Or download and execute:

```powershell
curl -o ccpm.bat https://raw.githubusercontent.com/automazeio/ccpm/main/ccpm.bat && ccpm.bat
```

## One-liner alternatives

### Unix/Linux/macOS (direct commands)
```bash
git clone https://github.com/automazeio/ccpm.git . && rm -rf .git
```

### Windows (cmd)
```cmd
git clone https://github.com/automazeio/ccpm.git . && rmdir /s /q .git
```

### Windows (PowerShell)
```powershell
git clone https://github.com/automazeio/ccpm.git .; Remove-Item -Recurse -Force .git
```
