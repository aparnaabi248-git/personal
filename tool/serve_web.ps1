param(
  [string]$Root = 'build\web',
  [int]$Port = 8081
)

# Minimal static file server for the Flutter web build.
# Flutter needs correct MIME types, and .dart.js must not be cached, so this
# stays deliberately small rather than pulling in a dependency.

$mime = @{
  '.html' = 'text/html; charset=utf-8'
  '.js'   = 'application/javascript; charset=utf-8'
  '.mjs'  = 'application/javascript; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'
  '.css'  = 'text/css; charset=utf-8'
  '.png'  = 'image/png'
  '.jpg'  = 'image/jpeg'
  '.jpeg' = 'image/jpeg'
  '.gif'  = 'image/gif'
  '.svg'  = 'image/svg+xml'
  '.ico'  = 'image/x-icon'
  '.wasm' = 'application/wasm'
  '.otf'  = 'font/otf'
  '.ttf'  = 'font/ttf'
  '.woff' = 'font/woff'
  '.woff2'= 'font/woff2'
  '.bin'  = 'application/octet-stream'
  '.symbols' = 'application/octet-stream'
}

$rootPath = (Resolve-Path $Root).Path
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()
Write-Output "Serving $rootPath at http://127.0.0.1:$Port/"

while ($listener.IsListening) {
  try {
    $context = $listener.GetContext()
  } catch {
    break
  }

  $req = $context.Request
  $res = $context.Response

  $relative = [System.Uri]::UnescapeDataString($req.Url.AbsolutePath.TrimStart('/'))
  if ([string]::IsNullOrEmpty($relative)) { $relative = 'index.html' }

  # Resolve inside the root and reject anything that escapes it.
  $full = Join-Path $rootPath ($relative -replace '/', '\')
  if (-not $full.StartsWith($rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    $res.StatusCode = 403
    $res.Close()
    continue
  }

  if (Test-Path -LiteralPath $full -PathType Container) {
    $full = Join-Path $full 'index.html'
  }

  if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
    $res.StatusCode = 404
    $res.Close()
    continue
  }

  $ext = [System.IO.Path]::GetExtension($full).ToLowerInvariant()
  $type = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }

  $bytes = [System.IO.File]::ReadAllBytes($full)

  $res.StatusCode = 200
  $res.ContentType = $type
  $res.ContentLength64 = $bytes.Length
  # Always revalidate so a rebuild is picked up on refresh.
  $res.Headers['Cache-Control'] = 'no-store'
  $res.OutputStream.Write($bytes, 0, $bytes.Length)
  $res.Close()
}