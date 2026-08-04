@{
    Assets = @{
        # Specify filename of the logo.
        Logo = '..\Assets\AppIcon.png'

        # Specify filename of the logo (for dark mode).
        LogoDark = '..\Assets\AppIcon.png'

        # Specify filename of the banner (Classic-only).
        Banner = '..\Assets\Banner.Classic.png'
    }

    MSI = @{
        # MSI install parameters used in interactive mode.
        InstallParams = 'REBOOT=ReallySuppress /QN'

        # Logging level used for MSI logging.
        LoggingOptions = '/L*V'

        # Log path used for MSI logging. Uses the same path as Toolkit when null or empty.
        LogPath = $null

        # Log path used for MSI logging when RequireAdmin is False. Uses the same path as Toolkit when null or empty.
        LogPathNoAdminRights = $null

        # The length of time in seconds to wait for the MSI installer service to become available. Default is 600 seconds (10 minutes).
        MutexWaitTime = 600

        # MSI install parameters used in silent mode.
        SilentParams = 'REBOOT=ReallySuppress /QN'

        # MSI uninstall parameters.
        UninstallParams = 'REBOOT=ReallySuppress /QN'
    }

    Toolkit = @{
        # Specify the path for the cache folder.
        CachePath = '$envProgramData\SoftwareCache'

        # The name to show by default for dialog subtitles, balloon notifications, etc.
        CompanyName = 'PSAppDeployToolkit'

        # Specify if the log files should be bundled together in a compressed zip file.
        CompressLogs = $false

        # Choose from either 'Native' for native PowerShell file copy via Copy-ADTFile, or 'Robocopy' to use robocopy.exe.
        FileCopyMode = 'Native'

        # Specify if an existing log file should be appended to.
        LogAppend = $true

        # Specify if debug messages such as bound parameters passed to a function should be logged.
        LogDebugMessage = $false

        # Specify maximum number of previous log files to retain.
        LogMaxHistory = 10

        # Specify maximum file size limit for log file in megabytes (MB).
        LogMaxSize = 10

        # Log path used for Toolkit logging.
        LogPath = '$envWinDir\Logs\Software'

        # Same as LogPath but used when RequireAdmin is False.
        LogPathNoAdminRights = '$envProgramData\Logs\Software'

        # Specifies that logging should be to a hierarchical structure of AppVendor\AppName\AppVersion. Takes precident over "LogToSubfolder" if both are set.
        LogToHierarchy = $false

        # Specifies that a subfolder based on InstallName should be used for all log capturing.
        LogToSubfolder = $false

        # Specify if log file should be a CMTrace compatible log file or a Legacy text log file.
        LogStyle = 'CMTrace'

        # Specify if log messages should be written to the console.
        LogWriteToHost = $true

        # Specify if console log messages should bypass PowerShell's subsystems and be sent direct to stdout/stderr.
        # This only applies if "LogWriteToHost" is true, and the script is being ran in a ConsoleHost (not the ISE, or another host).
        LogHostOutputToStdStreams = $false

        # Registry key used to store toolkit information (with PSAppDeployToolkit as child registry key), e.g. deferral history.
        RegPath = 'HKLM:\SOFTWARE'

        # Same as RegPath but used when RequireAdmin is False. Bear in mind that since this Registry Key should be writable without admin permission, regular users can modify it also.
        RegPathNoAdminRights = 'HKCU:\SOFTWARE'

        # Path used to store temporary Toolkit files (with PSAppDeployToolkit as subdirectory), e.g. cache toolkit for cleaning up blocked apps. Normally you don't want this set to a path that is writable by regular users, this might lead to a security vulnerability. The default Temp variable for the LocalSystem account is C:\Windows\Temp.
        TempPath = '$envTemp'

        # Same as TempPath but used when RequireAdmin is False.
        TempPathNoAdminRights = '$envTemp'
    }

    UI = @{
        # Used to turn automatic balloon notifications on or off.
        BalloonNotifications = $true

        # Choose from either 'Fluent' for contemporary dialogs, or 'Classic' for PSAppDeployToolkit 3.x WinForms dialogs.
        DialogStyle = 'Fluent'

        # Specify the Accent Color in hex (with the first two characters for transparency, 00 = 0%, FF = 100%), e.g. 0xFF0078D7.
        # The value specified here should be literally typed (i.e. `FluentAccentColor = 0xFF0078D7`) and not wrapped in quotes.
        FluentAccentColor = $null

        # Exit code used when a UI prompt times out.
        DefaultExitCode = 1618

        # Time in seconds after which the prompt should be repositioned centre screen when the -PersistPrompt parameter is used. Default is 60 seconds.
        DefaultPromptPersistInterval = 60

        # Time in seconds to automatically timeout installation dialogs. Default is 55 minutes so that dialogs timeout before Intune times out.
        DefaultTimeout = 3300

        # Exit code used when a user opts to defer.
        DeferExitCode = 1602

        <# Specify a static UI language using the one of the Language Codes listed below to override the language culture detected on the system.
            Language Code    Language
            =============    ========
            ar               Arabic
            bg               Bulgarian
            cs               Czech
            da               Danish
            de               German
            en               English
            el               Greek
            es               Spanish
            fi               Finnish
            fr               French
            he               Hebrew
            hu               Hungarian
            it               Italian
            ja               Japanese
            ko               Korean
            lv               Latvian
            nl               Dutch
            nb               Norwegian (Bokmål)
            pl               Polish
            pt               Portuguese (Portugal)
            pt-BR            Portuguese (Brazil)
            ru               Russian
            sk               Slovak
            sv               Swedish
            tr               Turkish
            zh-CN            Chinese (Simplified)
            zh-HK            Chinese (Traditional)
        #>
        LanguageOverride = $null

        # Time in seconds after which to re-prompt the user to close applications in case they ignore the prompt or they cancel the application's save prompt.
        PromptToSaveTimeout = 120

        # Time in seconds after which the restart prompt should be re-displayed/repositioned when the -NoCountdown parameter is specified. Default is 600 seconds.
        RestartPromptPersistInterval = 600
    }
}

# SIG # Begin signature block
# MIIigQYJKoZIhvcNAQcCoIIicjCCIm4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB6U3QbCJqdYYai
# DLrAUg0+UvzVFFQTSU7+K0oZSnXZQKCCHK4wggQUMIIC/KADAgECAgQQAztrMA0G
# CSqGSIb3DQEBCwUAMEUxCzAJBgNVBAYTAkRFMRAwDgYDVQQKDAdBbGxpYW56MSQw
# IgYDVQQDDBtBbGxpYW56IEluZnJhc3RydWN0dXJlIENBIFYwHhcNMjUwMzEyMDcz
# MjM0WhcNMjcwMzEyMDczMjM0WjA8MQswCQYDVQQGEwJERTEQMA4GA1UECgwHQWxs
# aWFuejEbMBkGA1UEAwwSV1BTX0FQUFNfUGFja2FnaW5nMIIBIjANBgkqhkiG9w0B
# AQEFAAOCAQ8AMIIBCgKCAQEAp2jGJrEwfnn0ii6d0v1/mZfvjw4godWtF/u+0Sxo
# 4LV37NAUIE7ntLPn7D4dvuBpVuvJeEPBEmn7pgLgsKZXDfXDnz+6JRotu+AFNi1J
# +xUlwalAlsojexe6aJHCWxFNeLwdO12v1MaAw/22AKTx/MZAU9/ckCKj6SqE/IJZ
# lPkTxe2OCTB1JZvCc5/gs6EhCAvwGTbZy3KSiKiXYZoyPvl8IlGolVJbpYgZ5Gr/
# d13FnRUKiLqOF5ykQ+ZUE24cFfq3TJAHdS1ld7Y4eEdH7f4pA0Lpa0g6+l3CsOaV
# MueMSnfC4u37y8dHkZeDwcd1z7i1Qujp1xGf/7za3VnJvwIDAQABo4IBEzCCAQ8w
# HQYDVR0OBBYEFCpHadszhB+Ki9+CYKU6dDbmQeFgMA4GA1UdDwEB/wQEAwIHgDAT
# BgNVHSUEDDAKBggrBgEFBQcDAzAbBgkrBgEEAYI3FQoEDjAMMAoGCCsGAQUFBwMD
# MDsGCCsGAQUFBwEBBC8wLTArBggrBgEFBQcwAYYfaHR0cDovL3Jvb3RjYS5hbGxp
# YW56LmNvbS9vY3NwLzBvBgNVHR8EaDBmMDGgL6AthitodHRwOi8vcm9vdGNhLmFs
# bGlhbnouY29tL2NybC9JbmZyYUNBLVYuY3JsMDGgL6AthitodHRwOi8vcm9vdGNh
# LmluZC5hbGxpYW56L2NybC9JbmZyYUNBLVYuY3JsMA0GCSqGSIb3DQEBCwUAA4IB
# AQB2dD0t9o8W7n18NyFGEmOux0XCvt9s/DacEmgbadQZDUxM1TWQB8PZ5yzbRgsD
# livpi1h9YxZuWBGpyiwQJzOvVYS1ptcw8GEWkcPiUkEzOt/JyO0g8k29kdXdbLe/
# WR/gFLORZmYPA/lbhFGtsrGtaCef5uGFJwowPhh+bO8i9lZClRlwGSsqALqizLmM
# cDJrX5sxGG9RmMlNgLn1Yt0kaQydNFx/YTV568cgeslvHvWiXJ4GqCkeWMIPFpax
# ctW1BgzcDkeF5UnHN2nvuFbaKCN3/EPhgD19G6QMTYsCx5ZJ5nLW/4u3x5oEkM4G
# SZGq6eVq9sCj/b8LfZeGh2mYMIIFWDCCA0CgAwIBAgIBCTANBgkqhkiG9w0BAQsF
# ADA9MQswCQYDVQQGEwJERTEQMA4GA1UEChMHQWxsaWFuejEcMBoGA1UEAxMTQWxs
# aWFueiBSb290IENBIElJSTAeFw0xNTA0MjkwOTEzMDJaFw0zMDA0MjUwOTEzMDJa
# MEUxCzAJBgNVBAYTAkRFMRAwDgYDVQQKDAdBbGxpYW56MSQwIgYDVQQDDBtBbGxp
# YW56IEluZnJhc3RydWN0dXJlIENBIFYwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
# ggEKAoIBAQDPROja9dPfvzzYV7oiiCQ06BCwbEr0QBhYdxQDa9bCi8h98Sg//ARQ
# 308eJ1QS8HVNa0XzP5eqDmvjNf0mJvjp4MWqBkHxyliLjNWYjX7zAZsRGgqLpZpe
# cwiFGKfy+46WrVCpL9mEIWc1I6C17BZKeIzzhq0dl4KFpKaoLcDJc4t97/ulUJvC
# ztFKSMjOF2U7+FCL2QuXiAfOtHT0bH+dGpcg+wFsIVOxpYIZ50p4i/CKusYrQqo9
# BiDFtVjT3J8suhAN8iqCh0pLGE6LCC/W+wZgnZtJF7BbOwz7F/xTNitTvvZ6YK/c
# AOBI3cFZHBzNBSTzqGWx4+SZ9cO1iGIBAgMBAAGjggFZMIIBVTAOBgNVHQ8BAf8E
# BAMCAYYwHQYDVR0OBBYEFHG9sutEhiEEN7BuC3TAjPpdhO3QMB8GA1UdIwQYMBaA
# FBpX2GOBsZ8a/os2bNCngGhHLnr5MBIGA1UdEwEB/wQIMAYBAf8CAQAwOgYDVR0f
# BDMwMTAvoC2gK4YpaHR0cDovL3Jvb3RjYS5hbGxpYW56LmNvbS9jcmwvcm9vdGNh
# My5jcmwwgbIGA1UdIASBqjCBpzCBpAYJKwYBBAG3dx4gMIGWMCoGCCsGAQUFBwIB
# Fh5odHRwOi8vcm9vdGNhLmFsbGlhbnouY29tL2NwczMwaAYIKwYBBQUHAgIwXDAW
# Fg9BbGxpYW56IEdlcm1hbnkwAwIBARpCVGhpcyBDZXJ0aWZpY2F0ZSBpcyBpc3N1
# ZWQgYnkgQWxsaWFueiBSb290IENBIElJSSwgQWxsaWFueiBHZXJtYW55MA0GCSqG
# SIb3DQEBCwUAA4ICAQCzq+l+6m9LA7hXS43xlNnYvX1MReAUmK05zIIipCfWfSK0
# f5ZFcqrHAbHI/rxflM88yCepFPpVqwkL2sOBAtlvLmyLMRsrOunT8hOiDdcPyQVh
# GHAE1awBg8lU45xupsifuYNr+7+mfoHFhnI15f/ADy3zlnj1EsSESL30YPWK3PyN
# QQGU8PG65eRZGvceGvQV+dn2j1isy1fesFnsoFjgtfS2xoxhYlm9EGwkQKOzWK9y
# mtD3qHefHykq8RfYfGqF04r3TRVGz0mjOKElzk1kNxv64H8xI3u4PzsWYRSLZkAo
# IxvTWQKb/mCXRkBYvTN53zG186lfNKvoaCfiDJDYVTs1yNTDHP0DgQzbmbtfvDNj
# 9itUZ3qIQaXxyyXVSt57ixj+HbwwNMJOQRVa5jR3AqqiLWMQ3R01vFP27C9SdSQa
# pm17xb9CYZZwhq5qcViC9lD/Nxc/uAu2oB4Q6YpwWWZWTAXXLYyIjK+KCvRxNQW/
# P1jz2T9XeKnt28uY2R5pxdy/SyCV1Il08cqIqcHDGfdRmG8teg51IHRdzDWFmKRo
# 0dvuEG2HZkdz3c808DCXicVVHLedyhLqzvUMdNOB2YuT8HsrJ9au0b6ZiUr68HtH
# ObCowP00BXpLmCmHCjxp9QEZhnwmk7H3R18SSvbeg0iYACOo7ThQJG0LPZ0GLjCC
# BY0wggR1oAMCAQICEA6bGI750C3n79tQ4ghAGFowDQYJKoZIhvcNAQEMBQAwZTEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290
# IENBMB4XDTIyMDgwMTAwMDAwMFoXDTMxMTEwOTIzNTk1OVowYjELMAkGA1UEBhMC
# VVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0
# LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MIICIjANBgkq
# hkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAv+aQc2jeu+RdSjwwIjBpM+zCpyUuySE9
# 8orYWcLhKac9WKt2ms2uexuEDcQwH/MbpDgW61bGl20dq7J58soR0uRf1gU8Ug9S
# H8aeFaV+vp+pVxZZVXKvaJNwwrK6dZlqczKU0RBEEC7fgvMHhOZ0O21x4i0MG+4g
# 1ckgHWMpLc7sXk7Ik/ghYZs06wXGXuxbGrzryc/NrDRAX7F6Zu53yEioZldXn1RY
# jgwrt0+nMNlW7sp7XeOtyU9e5TXnMcvak17cjo+A2raRmECQecN4x7axxLVqGDgD
# EI3Y1DekLgV9iPWCPhCRcKtVgkEy19sEcypukQF8IUzUvK4bA3VdeGbZOjFEmjNA
# vwjXWkmkwuapoGfdpCe8oU85tRFYF/ckXEaPZPfBaYh2mHY9WV1CdoeJl2l6SPDg
# ohIbZpp0yt5LHucOY67m1O+SkjqePdwA5EUlibaaRBkrfsCUtNJhbesz2cXfSwQA
# zH0clcOP9yGyshG3u3/y1YxwLEFgqrFjGESVGnZifvaAsPvoZKYz0YkH4b235kOk
# GLimdwHhD5QMIR2yVCkliWzlDlJRR3S+Jqy2QXXeeqxfjT/JvNNBERJb5RBQ6zHF
# ynIWIgnffEx1P2PsIV/EIFFrb7GrhotPwtZFX50g/KEexcCPorF+CiaZ9eRpL5gd
# LfXZqbId5RsCAwEAAaOCATowggE2MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYE
# FOzX44LScV1kTN8uZz/nupiuHA9PMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6en
# IZ3zbcgPMA4GA1UdDwEB/wQEAwIBhjB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUH
# MAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDov
# L2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNy
# dDBFBgNVHR8EPjA8MDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGln
# aUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMBEGA1UdIAQKMAgwBgYEVR0gADANBgkq
# hkiG9w0BAQwFAAOCAQEAcKC/Q1xV5zhfoKN0Gz22Ftf3v1cHvZqsoYcs7IVeqRq7
# IviHGmlUIu2kiHdtvRoU9BNKei8ttzjv9P+Aufih9/Jy3iS8UgPITtAq3votVs/5
# 9PesMHqai7Je1M/RQ0SbQyHrlnKhSLSZy51PpwYDE3cnRNTnf+hZqPC/Lwum6fI0
# POz3A8eHqNJMQBk1RmppVLC4oVaO7KTVPeix3P0c2PR3WlxUjG/voVA9/HYJaISf
# b8rbII01YBwCA8sgsKxYoA5AY8WYIsGyWfVVa88nq2x2zm8jLfR+cWojayL/ErhU
# LSd+2DrZ8LaHlv1b0VysGMNNn3O3AamfV6peKOK5lDCCBrQwggScoAMCAQICEA3H
# rFcF/yGZLkBDIgw6SYYwDQYJKoZIhvcNAQELBQAwYjELMAkGA1UEBhMCVVMxFTAT
# BgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEh
# MB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MB4XDTI1MDUwNzAwMDAw
# MFoXDTM4MDExNDIzNTk1OVowaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lD
# ZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFt
# cGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMTCCAiIwDQYJKoZIhvcNAQEBBQAD
# ggIPADCCAgoCggIBALR4MdMKmEFyvjxGwBysddujRmh0tFEXnU2tjQ2UtZmWgyxU
# 7UNqEY81FzJsQqr5G7A6c+Gh/qm8Xi4aPCOo2N8S9SLrC6Kbltqn7SWCWgzbNfiR
# +2fkHUiljNOqnIVD/gG3SYDEAd4dg2dDGpeZGKe+42DFUF0mR/vtLa4+gKPsYfwE
# u7EEbkC9+0F2w4QJLVSTEG8yAR2CQWIM1iI5PHg62IVwxKSpO0XaF9DPfNBKS7Za
# zch8NF5vp7eaZ2CVNxpqumzTCNSOxm+SAWSuIr21Qomb+zzQWKhxKTVVgtmUPAW3
# 5xUUFREmDrMxSNlr/NsJyUXzdtFUUt4aS4CEeIY8y9IaaGBpPNXKFifinT7zL2gd
# FpBP9qh8SdLnEut/GcalNeJQ55IuwnKCgs+nrpuQNfVmUB5KlCX3ZA4x5HHKS+rq
# BvKWxdCyQEEGcbLe1b8Aw4wJkhU1JrPsFfxW1gaou30yZ46t4Y9F20HHfIY4/6vH
# espYMQmUiote8ladjS/nJ0+k6MvqzfpzPDOy5y6gqztiT96Fv/9bH7mQyogxG9QE
# PHrPV6/7umw052AkyiLA6tQbZl1KhBtTasySkuJDpsZGKdlsjg4u70EwgWbVRSX1
# Wd4+zoFpp4Ra+MlKM2baoD6x0VR4RjSpWM8o5a6D8bpfm4CLKczsG7ZrIGNTAgMB
# AAGjggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBTvb1NK6eQG
# fHrK4pBW9i/USezLTjAfBgNVHSMEGDAWgBTs1+OC0nFdZEzfLmc/57qYrhwPTzAO
# BgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgwdwYIKwYBBQUHAQEE
# azBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQQYIKwYB
# BQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0
# ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2lj
# ZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAGA1UdIAQZMBcwCAYG
# Z4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAF877FoAc/gc9
# EXZxML2+C8i1NKZ/zdCHxYgaMH9Pw5tcBnPw6O6FTGNpoV2V4wzSUGvI9NAzaoQk
# 97frPBtIj+ZLzdp+yXdhOP4hCFATuNT+ReOPK0mCefSG+tXqGpYZ3essBS3q8nL2
# UwM+NMvEuBd/2vmdYxDCvwzJv2sRUoKEfJ+nN57mQfQXwcAEGCvRR2qKtntujB71
# WPYAgwPyWLKu6RnaID/B0ba2H3LUiwDRAXx1Neq9ydOal95CHfmTnM4I+ZI2rVQf
# jXQA1WSjjf4J2a7jLzWGNqNX+DF0SQzHU0pTi4dBwp9nEC8EAqoxW6q17r0z0noD
# js6+BFo+z7bKSBwZXTRNivYuve3L2oiKNqetRHdqfMTCW/NmKLJ9M+MtucVGyOxi
# Df06VXxyKkOirv6o02OoXN4bFzK0vlNMsvhlqgF2puE6FndlENSmE+9JGYxOGLS/
# D284NHNboDGcmWXfwXRy4kbu4QFhOm0xJuF2EZAOk5eCkhSxZON3rGlHqhpB/8Ml
# uDezooIs8CVnrpHMiD2wL40mm53+/j7tFaxYKIqL0Q4ssd8xHZnIn/7GELH3IdvG
# 2XlM9q7WP/UwgOkw/HQtyRN62JK4S1C8uw3PdBunvAZapsiI5YKdvlarEvf8EA+8
# hcpSM9LHJmyrxaFtoza2zNaQ9k+5t1wwggbtMIIE1aADAgECAhAKgO8YS43xBYLR
# xHanlXRoMA0GCSqGSIb3DQEBCwUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5E
# aWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1l
# U3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEwHhcNMjUwNjA0MDAwMDAw
# WhcNMzYwOTAzMjM1OTU5WjBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNl
# cnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFNIQTI1NiBSU0E0MDk2IFRpbWVz
# dGFtcCBSZXNwb25kZXIgMjAyNSAxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEA0EasLRLGntDqrmBWsytXum9R/4ZwCgHfyjfMGUIwYzKomd8U1nH7C8Dr
# 0cVMF3BsfAFI54um8+dnxk36+jx0Tb+k+87H9WPxNyFPJIDZHhAqlUPt281mHrBb
# ZHqRK71Em3/hCGC5KyyneqiZ7syvFXJ9A72wzHpkBaMUNg7MOLxI6E9RaUueHTQK
# WXymOtRwJXcrcTTPPT2V1D/+cFllESviH8YjoPFvZSjKs3SKO1QNUdFd2adw44wD
# cKgH+JRJE5Qg0NP3yiSyi5MxgU6cehGHr7zou1znOM8odbkqoK+lJ25LCHBSai25
# CFyD23DZgPfDrJJJK77epTwMP6eKA0kWa3osAe8fcpK40uhktzUd/Yk0xUvhDU6l
# vJukx7jphx40DQt82yepyekl4i0r8OEps/FNO4ahfvAk12hE5FVs9HVVWcO5J4dV
# mVzix4A77p3awLbr89A90/nWGjXMGn7FQhmSlIUDy9Z2hSgctaepZTd0ILIUbWuh
# KuAeNIeWrzHKYueMJtItnj2Q+aTyLLKLM0MheP/9w6CtjuuVHJOVoIJ/DtpJRE7C
# e7vMRHoRon4CWIvuiNN1Lk9Y+xZ66lazs2kKFSTnnkrT3pXWETTJkhd76CIDBbTR
# ofOsNyEhzZtCGmnQigpFHti58CSmvEyJcAlDVcKacJ+A9/z7eacCAwEAAaOCAZUw
# ggGRMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFOQ7/PIx7f391/ORcWMZUEPPYYzo
# MB8GA1UdIwQYMBaAFO9vU0rp5AZ8esrikFb2L9RJ7MtOMA4GA1UdDwEB/wQEAwIH
# gDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDCBlQYIKwYBBQUHAQEEgYgwgYUwJAYI
# KwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBdBggrBgEFBQcwAoZR
# aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGlt
# ZVN0YW1waW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3J0MF8GA1UdHwRYMFYwVKBS
# oFCGTmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFRp
# bWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNybDAgBgNVHSAEGTAXMAgG
# BmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBAGUqrfEcJwS5
# rmBB7NEIRJ5jQHIh+OT2Ik/bNYulCrVvhREafBYF0RkP2AGr181o2YWPoSHz9iZE
# N/FPsLSTwVQWo2H62yGBvg7ouCODwrx6ULj6hYKqdT8wv2UV+Kbz/3ImZlJ7YXwB
# D9R0oU62PtgxOao872bOySCILdBghQ/ZLcdC8cbUUO75ZSpbh1oipOhcUT8lD8QA
# GB9lctZTTOJM3pHfKBAEcxQFoHlt2s9sXoxFizTeHihsQyfFg5fxUFEp7W42fNBV
# N4ueLaceRf9Cq9ec1v5iQMWTFQa0xNqItH3CPFTG7aEQJmmrJTV3Qhtfparz+BW6
# 0OiMEgV5GWoBy4RVPRwqxv7Mk0Sy4QHs7v9y69NBqycz0BZwhB9WOfOu/CIJnzkQ
# TwtSSpGGhLdjnQ4eBpjtP+XB3pQCtv4E5UCSDag6+iX8MmB10nfldPF9SVD7weCC
# 3yXZi/uuhqdwkgVxuiMFzGVFwYbQsiGnoa9F5AaAyBjFBtXVLcKtapnMG3VH3EmA
# p/jsJ3FVF3+d1SVDTmjFjLbNFZUWMXuZyvgLfgyPehwJVxwC+UpX2MSey2ueIu9T
# HFVkT+um1vshETaWyQo8gmBto/m3acaP9QsuLj3FNwFlTxq25+T4QwX9xa6ILs84
# ZPvmpovq90K8eWyG2N01c4IhSOxqt81nMYIFKTCCBSUCAQEwTTBFMQswCQYDVQQG
# EwJERTEQMA4GA1UECgwHQWxsaWFuejEkMCIGA1UEAwwbQWxsaWFueiBJbmZyYXN0
# cnVjdHVyZSBDQSBWAgQQAztrMA0GCWCGSAFlAwQCAQUAoIGEMBgGCisGAQQBgjcC
# AQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYB
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIMm3qk0N5ivy
# d1FbuKXTpHJMS2ijUsj5geU0yb9aURseMA0GCSqGSIb3DQEBAQUABIIBAAzjmPdB
# rmw4qXp94a/cdjnSl0o0b3S3hVdEvbzaYqroPcuL4TYMc/E1P/2llgai+E8670fb
# L1Oc3UYWFaAWE7c/85tnyrTyEFvLzoEM2FCHNw1xeLnYIJWmjndyBvaQUhjNiMDR
# 41NsglcfD3zjVxujuSD45M+/k3wdMI+r6M8mUDKgB4EgfUjv182lYXdvhBRTwtfx
# IN8Lgz04Man1dmKphqb24fJVfp8sxuo5nBgckk6zFi/j3ibjRnhGE+BbhZaa8eC3
# AYZWaNQKHAtZsjLutliaBNecuHi3CrMH+YbXKyjk80mERFkBUwdJ0tZAswhDe6f1
# mf0Cu1mbW3MTxSmhggMmMIIDIgYJKoZIhvcNAQkGMYIDEzCCAw8CAQEwfTBpMQsw
# CQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERp
# Z2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIw
# MjUgQ0ExAhAKgO8YS43xBYLRxHanlXRoMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZI
# hvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjYwNDIxMTUyODAz
# WjAvBgkqhkiG9w0BCQQxIgQgDW/D9UOOA8ZAwIO0D71wLN7v8+RXrwjh5uty3IfZ
# BxswDQYJKoZIhvcNAQEBBQAEggIAY0oOWPiXFgtrDpCnF9/0dVVB66NBJn+/Xoe3
# Zn/LHmSld4ZTGPnbyFP8DJzy7B+ZlaVnqzu4Z4Mn0+7ov5BSU6XMSxwwU3k1hGim
# z7JCIj4rkRCPot12NBh3u2SKcwtp2L2NmLUJQBvbFJbx0yOw3t5bv2HiSZoN/k1X
# C81zySVXW7YzWdmRHElZKf5+tn3UznplEV76krnE4bZUiybUabMgyrTI2HGAhfUq
# BjfqWwy2mDVnBdvLW4CfQhJdbT1PSfp8skfkj+LI4vchfO7YtcY2ea2PlD31u9nQ
# Xnu0byVPU4Zch3IHFZyu5AxAjy4JpGK0QYQ4F+run3Cd3ogeILPNtxQOK7PCI/rE
# V4Uj8CjsbHLIS10EHyk7/t1wl1XTO4w1POGQzqFjl7PJ7eBkI40vp0KGzEWjMUlL
# WGru0HIKzG8K0GfNKhP8RJECGN80+B0o3yQI3LLs4KSeqY0uVoNdCURAIwRqcZ9j
# neSYfTQC4N3plltHS5sADENZDa0C5uA/3cT2YxsiUxyrsu9ovGU/zlQGKE/7hh7c
# 70YyWbk8XdgS59S1ZhQKnW6sCaK7s259alDcba1z8kGpVP7wBl94zX74joHJUDv+
# MdDBp2d3su9OgjDxw4sBDMmi6stK9pJzNRcnp88yhHJi0e01ICYUSddgWu5RYLlp
# xquCo6s=
# SIG # End signature block
