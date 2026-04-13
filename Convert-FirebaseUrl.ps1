param(
    [string]$StorageLocation,
    [string]$AccessToken
)

# Remove the gs://bucket/ prefix to get the file path
$path = $StorageLocation -replace '^gs://[^/]+/', ''

# URL-encode the path (slashes become %2F, spaces become %20, etc.)
$encodedPath = [Uri]::EscapeDataString($path)

# Extract the bucket name
$bucket = ($StorageLocation -replace '^gs://', '') -replace '/.*', ''

# Build the full URL
$url = "https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath`?alt=media&token=$AccessToken"

Write-Host "`nDownload URL:`n"
Write-Host $url

# Copy to clipboard
$url | Set-Clipboard
Write-Host "`n(Copied to clipboard)"