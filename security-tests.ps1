# ═══════════════════════════════════════════════════════════════════════════
# Radio Apollo — Security Verification Suite
# ═══════════════════════════════════════════════════════════════════════════
#
# Runs the attacks from the security report against the live deployment
# and reports which are blocked.
#
# Usage:
#   .\security-tests.ps1
#
# Run from any directory. Read-only — does not depend on local code.
# Note: Test 7 (admin login XFF) will lock your IP out of admin login
# for ~5 minutes. Don't run it right before you need to log in as admin.
# ═══════════════════════════════════════════════════════════════════════════

$ProjectId = 'radio-apollo-90693'
$Region    = 'europe-west1'
$WebApiKey = 'AIzaSyBmJ4n2iQzNsRqMl62tu_DgSYTPX6ZiT6E'
$FuncBase  = "https://$Region-$ProjectId.cloudfunctions.net"
$FsBase    = "https://firestore.googleapis.com/v1/projects/$ProjectId/databases/(default)/documents"

# ── Helper: run a request and report pass/fail ──────────────────────────────
function Invoke-AttackTest {
    param(
        [string]$Name,
        [string]$Description,
        [scriptblock]$Test,
        [int[]]$ExpectedFailureCodes = @(401, 403, 429, 400)
    )

    Write-Host ""
    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "TEST: $Name" -ForegroundColor Cyan
    Write-Host "      $Description" -ForegroundColor Gray
    Write-Host ""

    try {
        $result = & $Test
        Write-Host "  FAIL: Attack succeeded (HTTP 2xx). Response:" -ForegroundColor Red
        Write-Host "  $result" -ForegroundColor Red
        return $false
    } catch {
        $status = $_.Exception.Response.StatusCode.value__
        $body = ''
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $body = $reader.ReadToEnd()
        } catch {}

        if ($ExpectedFailureCodes -contains $status) {
            Write-Host "  PASS: Blocked with HTTP $status" -ForegroundColor Green
            if ($body) { Write-Host "  Response: $body" -ForegroundColor DarkGray }
            return $true
        } else {
            Write-Host "  UNEXPECTED: HTTP $status (expected one of $($ExpectedFailureCodes -join ', '))" -ForegroundColor Yellow
            Write-Host "  Response: $body" -ForegroundColor Yellow
            return $false
        }
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host "  Radio Apollo - Security Verification" -ForegroundColor Magenta
Write-Host "  Target: $ProjectId" -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor Magenta

$results = @()

# Test 1: Direct Firestore message injection
$results += Invoke-AttackTest `
    -Name "1. Direct Firestore message injection" `
    -Description "Attacker writes a chat message via Firestore REST API." `
    -Test {
        $body = @{
            fields = @{
                username  = @{ stringValue    = 'Attacker' }
                text      = @{ stringValue    = 'Test injection - should be blocked' }
                role      = @{ stringValue    = 'user' }
                timestamp = @{ timestampValue = '2026-04-26T12:00:00Z' }
            }
        } | ConvertTo-Json -Depth 6 -Compress

        Invoke-WebRequest `
            -Uri "$FsBase/chat_messages?key=$WebApiKey" `
            -Method POST `
            -ContentType 'application/json' `
            -Body $body `
            -UseBasicParsing `
            -ErrorAction Stop
    }

# Test 2: Username impersonation via direct Firestore
$results += Invoke-AttackTest `
    -Name "2. Username impersonation via direct Firestore" `
    -Description "Attacker writes a message claiming to be 'Frank'." `
    -Test {
        $body = @{
            fields = @{
                username  = @{ stringValue    = 'Frank' }
                text      = @{ stringValue    = 'Fake message from Frank' }
                role      = @{ stringValue    = 'user' }
                timestamp = @{ timestampValue = '2026-04-26T12:00:00Z' }
            }
        } | ConvertTo-Json -Depth 6 -Compress

        Invoke-WebRequest `
            -Uri "$FsBase/chat_messages?key=$WebApiKey" `
            -Method POST `
            -ContentType 'application/json' `
            -Body $body `
            -UseBasicParsing `
            -ErrorAction Stop
    }

# Test 3: claimUsername without App Check (STRICT — must reject)
$results += Invoke-AttackTest `
    -Name "3. claimUsername without App Check token" `
    -Description "Bulk-claiming usernames via Cloud Function with no token." `
    -Test {
        Invoke-WebRequest `
            -Uri "$FuncBase/claimUsername" `
            -Method POST `
            -ContentType 'application/json' `
            -Body '{"name":"AttackerSquatter"}' `
            -UseBasicParsing `
            -ErrorAction Stop
    }

# Test 4: claimUsername with forged App Check token
$results += Invoke-AttackTest `
    -Name "4. claimUsername with forged App Check token" `
    -Description "Calling with a fake X-Firebase-AppCheck header." `
    -Test {
        Invoke-WebRequest `
            -Uri "$FuncBase/claimUsername" `
            -Method POST `
            -Headers @{ 'X-Firebase-AppCheck' = 'eyJhbGciOiJIUzI1NiJ9.fake.token' } `
            -ContentType 'application/json' `
            -Body '{"name":"AttackerSquatter"}' `
            -UseBasicParsing `
            -ErrorAction Stop
    }

# Test 5: Direct Firestore username claim
$results += Invoke-AttackTest `
    -Name "5. Direct Firestore username claim" `
    -Description "Attacker writes to /usernames/{name} via REST API." `
    -Test {
        $body = @{
            fields = @{
                displayName = @{ stringValue    = 'AttackerSquatter' }
                claimedAt   = @{ timestampValue = '2026-04-26T12:00:00Z' }
            }
        } | ConvertTo-Json -Depth 6 -Compress

        Invoke-WebRequest `
            -Uri "$FsBase/usernames/attackersquatter?key=$WebApiKey" `
            -Method PATCH `
            -ContentType 'application/json' `
            -Body $body `
            -UseBasicParsing `
            -ErrorAction Stop
    }

# Test 6: userSendMessage soft-fail with unknown username
# userSendMessage now soft-fails App Check (calls without token are allowed
# through, rate-limited strictly). With an unclaimed username, it must
# still reject with 400 'Onbekende gebruikersnaam'.
$results += Invoke-AttackTest `
    -Name "6. userSendMessage with unclaimed username" `
    -Description "Soft App Check is fine; unclaimed name should reject with 400." `
    -Test {
        Invoke-WebRequest `
            -Uri "$FuncBase/userSendMessage" `
            -Method POST `
            -ContentType 'application/json' `
            -Body '{"username":"NobodyHasThisName123456","text":"impersonation attempt"}' `
            -UseBasicParsing `
            -ErrorAction Stop
    } `
    -ExpectedFailureCodes @(400)

# Test 7: Admin login XFF spoofing + sequential lockout
# Fires 6 wrong-password attempts with rotated XFF headers.
# WARNING: this locks YOUR IP out of admin login for ~5 minutes.
Write-Host ""
Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "TEST: 7. Admin login X-Forwarded-For spoofing + lockout" -ForegroundColor Cyan
Write-Host "      6 failed attempts with rotated XFF headers." -ForegroundColor Gray
Write-Host "      Expected: requests 1-5 -> 401, request 6 -> 429 (locked)" -ForegroundColor Gray
Write-Host "      WARNING: this locks YOUR IP out of admin login for ~5 min." -ForegroundColor Yellow
Write-Host ""

$lockoutTriggered = $false
$statuses = @()

for ($i = 1; $i -le 6; $i++) {
    try {
        Invoke-WebRequest `
            -Uri "$FuncBase/adminLogin" `
            -Method POST `
            -Headers @{ 'X-Forwarded-For' = "10.0.0.$i" } `
            -ContentType 'application/json' `
            -Body "{`"password`":`"wrong-attempt-$i`"}" `
            -UseBasicParsing `
            -ErrorAction Stop | Out-Null
    } catch {
        $code = $_.Exception.Response.StatusCode.value__
        $statuses += $code
        if ($code -eq 429) { $lockoutTriggered = $true }
    }
    Start-Sleep -Milliseconds 500
}

Write-Host "  Status codes seen: $($statuses -join ', ')" -ForegroundColor DarkGray

if ($lockoutTriggered) {
    Write-Host "  PASS: Lockout (429) triggered despite rotated XFF" -ForegroundColor Green
    Write-Host "  -> req.ip is being used, X-Forwarded-For is ignored." -ForegroundColor Green
    $results += $true
} else {
    Write-Host "  FAIL: 6 attempts allowed without lockout - XFF still trusted?" -ForegroundColor Red
    $results += $false
}

# Test 8: Malformed JSON payload — should fail gracefully, not 500
$results += Invoke-AttackTest `
    -Name "8. Malformed JSON payload" `
    -Description "Sending broken JSON should return 400, not 500." `
    -Test {
        Invoke-WebRequest `
            -Uri "$FuncBase/userSendMessage" `
            -Method POST `
            -ContentType 'application/json' `
            -Body '{this is not json' `
            -UseBasicParsing `
            -ErrorAction Stop
    } `
    -ExpectedFailureCodes @(400, 401)

# Test 9: Read protected /config (admin password hash)
$results += Invoke-AttackTest `
    -Name "9. Read protected /config (admin password hash)" `
    -Description "Should be blocked by Firestore rules." `
    -Test {
        Invoke-WebRequest `
            -Uri "$FsBase/config/admin?key=$WebApiKey" `
            -Method GET `
            -UseBasicParsing `
            -ErrorAction Stop
    }

# Test 10: Read protected /_admin_sessions
$results += Invoke-AttackTest `
    -Name "10. Read protected /_admin_sessions" `
    -Description "Should be blocked by Firestore rules." `
    -Test {
        Invoke-WebRequest `
            -Uri "$FsBase/_admin_sessions?key=$WebApiKey" `
            -Method GET `
            -UseBasicParsing `
            -ErrorAction Stop
    }

# ── Summary ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "================================================================" -ForegroundColor Magenta
$passed = ($results | Where-Object { $_ -eq $true }).Count
$total = $results.Count
if ($passed -eq $total) {
    Write-Host "  RESULT: $passed / $total tests passed [OK]" -ForegroundColor Green
} else {
    Write-Host "  RESULT: $passed / $total tests passed [WARN]" -ForegroundColor Yellow
    Write-Host "  Investigate any FAIL or UNEXPECTED results above." -ForegroundColor Yellow
}
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host ""