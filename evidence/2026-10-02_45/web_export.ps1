$ErrorActionPreference='Stop'
$rootPath='D:/City-Venture-39'
$configPath="$rootPath/game/export_presets.cfg"
$originalConfig=[IO.File]::ReadAllText($configPath)
$outPath='C:/Users/User/.codex/tmp/cv45-webqa'
New-Item -ItemType Directory -Force -Path $outPath | Out-Null
try {
  [IO.File]::WriteAllText($configPath,$originalConfig.Replace('exclude_filter="tests/*,','exclude_filter="'),[Text.UTF8Encoding]::new($false))
  $env:APPDATA='C:/Users/User/.codex/tmp/cv44-package-user'
  & C:/Users/User/.codex/tmp/cv-godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe --headless --path "$rootPath/game" --export-release Web "$outPath/index.html" *> C:/Users/User/.codex/tmp/cv45-web-export.log
  if ($LASTEXITCODE -ne 0) {throw 'QA web export failed'}
} finally {
  [IO.File]::WriteAllText($configPath,$originalConfig,[Text.UTF8Encoding]::new($false))
}

