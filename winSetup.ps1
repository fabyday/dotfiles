$VSCode = "$env:APPDATA\Code\User"

Copy-Item "$PSScriptRoot\..\vscode\settings.json" `
          "$VSCode\settings.json" -Force

Copy-Item "$PSScriptRoot\..\vscode\keybindings.json" `
          "$VSCode\keybindings.json" -Force

Copy-Item "$PSScriptRoot\..\vscode\snippets\*" `
          "$VSCode\snippets\" -Force

# Get-Content "$PSScriptRoot\..\vscode\extensions.txt" | ForEach-Object {
#     code --install-extension $_
# }