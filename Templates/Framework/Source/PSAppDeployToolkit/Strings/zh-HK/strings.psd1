@{
    BalloonTip = @{
        Start = @{
            Install = '安裝開始。'
            Repair = '修復開始。'
            Uninstall = '卸載開始。'
        }
        Complete = @{
            Install = '安裝完成。'
            Repair = '修復完成。'
            Uninstall = '解除安裝完成。'
        }
        RestartRequired = @{
            Install = '安裝完成。需要重新啟動。'
            Repair = '修復完成。需要重新啟動。'
            Uninstall = '卸載完成。需要重新啟動。'
        }
        FastRetry = @{
            Install = '安裝未完成。'
            Repair = '修復未完成。'
            Uninstall = '解除安裝未完成。'
        }
        Error = @{
            Install = '安裝失敗。'
            Repair = '維修失敗。'
            Uninstall = '解除安裝失敗。'
        }
    }
    BlockExecutionText = @{
        Message = @{
            Install = '啟動此應用程式已被暫時阻止，以便完成安裝作業。'
            Repair = '啟動此應用程式已被暫時阻止，以便完成修復操作。'
            Uninstall = '啟動此應用程式已暫時受阻，以便完成卸載作業。'
        }
        Subtitle = @{
            Install = '{Toolkit\CompanyName} - 應用程式安裝'
            Repair = '{Toolkit\CompanyName} - 應用程式維修'
            Uninstall = '{Toolkit\CompanyName} - 應用程式卸載'
        }
    }
    DiskSpaceText = @{
        Message = @{
            Install = "您沒有足夠的磁碟空間來完成安裝：`n{0}`n`n所需空間： {1}MB `n 可用空間： {2}MB`n`n請釋放足夠的磁碟空間，以便繼續安裝。"
            Repair = "您沒有足夠的磁碟空間來完成修復:`n{0}`n`n所需空間： {1}MB`n可用空間： {2}MB`n`n請釋放足夠的磁碟空間，以便繼續進行修復。"
            Uninstall = "您沒有足夠的磁碟空間來完成卸載:`n{0}`n`n所需空間： {1}MB`n可用空間： {2}MB`n`n請釋放足夠的磁碟空間，以便繼續卸載。"
        }
    }
    InstallationPrompt = @{
        Subtitle = @{
            Install = '{Toolkit\CompanyName} - 應用程式安裝'
            Repair = '{Toolkit\CompanyName} - 應用程式維修'
            Uninstall = '{Toolkit\CompanyName} - 應用程式卸載'
        }
    }
    ProgressPrompt = @{
        Message = @{
            Install = '安裝中。 請稍候…'
            Repair = '維修中。 請稍候…'
            Uninstall = '正在卸載。 請稍候…'
        }
        MessageDetail = @{
            Install = '安裝完成後，此視窗將自動關閉。'
            Repair = '維修完成後，此視窗將自動關閉。'
            Uninstall = '卸載完成後，此視窗將自動關閉。'
        }
        Subtitle = @{
            Install = '{Toolkit\CompanyName} - 應用程式安裝'
            Repair = '{Toolkit\CompanyName} - 應用程式維修'
            Uninstall = '{Toolkit\CompanyName} - 應用程式卸載'
        }
    }
    RestartPrompt = @{
        ButtonRestartLater = '最小化'
        ButtonRestartNow = '現在重新啟動'
        Message = @{
            Install = '為了完成安裝，您必須重新啟動電腦。'
            Repair = '為了完成維修，您必須重新啟動電腦。'
            Uninstall = '為了讓卸載完成，您必須重新啟動電腦。'
        }
        CustomMessage = ''
        MessageRestart = '您的電腦會在倒數計時結束時自動重新啟動。'
        MessageTime = '請儲存您的工作，並在指定時間內重新啟動。'
        TimeRemaining = '剩餘時間：'
        Title = '需要重新啟動'
        Subtitle = @{
            Install = '{Toolkit\CompanyName} - 應用程式安裝'
            Repair = '{Toolkit\CompanyName} - 應用程式維修'
            Uninstall = '{Toolkit\CompanyName} - 應用程式卸載'
        }
    }
    CloseAppsPrompt = @{
        Classic = @{
            WelcomeMessage = @{
                Install = '下列應用程式即將安裝：'
                Repair = '下列應用程式即將被修復：'
                Uninstall = '下列應用程式即將被解除安裝：'
            }
            CloseAppsMessage = @{
                Install = "在繼續安裝之前，必須關閉下列程式。`n`n請儲存您的工作，關閉程式，然後繼續。或者，保存您的工作，然後按一下`「關閉程式`」。"
                Repair = "在進行修復之前，必須關閉下列程式。`n`n請儲存您的工作，關閉程式，然後繼續。或者，保存您的工作并单击 「关闭程序」。"
                Uninstall = "卸載程式前，必須先關閉下列程式。或者，保存您的工作並點擊 「關閉程式」。"
            }
            ExpiryMessage = @{
                Install = '您可以選擇延遲安裝，直到延遲到期:'
                Repair = '您可以選擇延遲修復，直到延遲到期：'
                Uninstall = '您可以選擇延遲卸載，直到延遲期限到期：'
            }
            DeferralsRemaining = '剩餘的延遲：'
            DeferralDeadline = '截止日期:'
            ExpiryWarning = '一旦延遲到期，您將無法再選擇延遲。'
            CountdownDefer = @{
                Install = '安裝會自動繼續：'
                Repair = '維修會自動繼續進行：'
                Uninstall = '卸載將自動繼續中：'
            }
            CountdownClose = @{
                Install = '注意：程式會自動關閉：'
                Repair = '注意：程式會自動關閉：'
                Uninstall = '注意：程式會自動關閉：'
            }
            ButtonClose = '關閉程式'
            ButtonDefer = '延遲'
            ButtonContinue = '繼續'
            ButtonContinueTooltip = '僅在關閉上述列出的應用程式後選擇 「繼續」。'
        }
        Fluent = @{
            DialogMessage = @{
                Install = '請先保存您的工作再繼續，因為下列應用程式會自動關閉。'
                Repair = '請先保存您的工作再繼續，因為下列應用程式會自動關閉。'
                Uninstall = '請先保存您的工作再繼續，因為下列應用程式會自動關閉。'
            }
            DialogMessageNoProcesses = @{
                Install = '請選擇「安裝」繼續安裝。'
                Repair = '請選擇「維修」繼續進行維修。'
                Uninstall = '請選擇「卸載」繼續進行卸載。'
            }
            AutomaticStartCountdown = '自動啟動倒數計時'
            DeferralsRemaining = '剩餘延期'
            DeferralDeadline = '延期截止日期'
            ButtonLeftText = @{
                Install = '關閉應用程式並安裝'
                Repair = '關閉應用程式與修復'
                Uninstall = '關閉應用程式並卸載'
            }
            ButtonLeftNoProcessesText = @{
                Install = '安裝'
                Repair = '修復'
                Uninstall = '解除安裝'
            }
            ButtonRightText = '延遲'
            Subtitle = @{
                Install = '{Toolkit\CompanyName} - 應用程式安裝'
                Repair = '{Toolkit\CompanyName} - 應用程式維修'
                Uninstall = '{Toolkit\CompanyName} - 應用程式卸載'
            }
        }
        CustomMessage = ''
    }
}

# SIG # Begin signature block
# MIIigQYJKoZIhvcNAQcCoIIicjCCIm4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAWqXgdDK0QNkXp
# aj7BHllXzCsz4HaPr7xrlMEETxgPRqCCHK4wggQUMIIC/KADAgECAgQQAztrMA0G
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
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEILYymqpZlT84
# d2ESop9ttzXPDluwMA37379u5iAEVsF0MA0GCSqGSIb3DQEBAQUABIIBADyvbtcy
# m+3qtUugyHylsShvHcl2dvGrBugXaqRTM1e2SR9ZZ8oUAnC5lCWs/nI0e5YLFt0p
# oBw7I9+2YCitya25v92tcusKwtM6AWH0VEzQXvn7t9soKJSq/0OBalKxh3zXaTwS
# JLk28gJinZ8XC5BazFX7wH4AFbmjb7mXKFrrHpfvOAM566y9FS1Ccn/Tu54elNQW
# 9ZSjr2iBxKM2u8zR9IA82hFq4mH/AqXTS4aHL9/ml4IQwe3aYzgM1BPZiO7X5dEb
# cnsMZeQOEXYHfjSgC/UgjLdiZux2FzRMh/tUaIUeFr6VNlioZLTNU5FGqzfJIF0W
# bI5XHsmuh6VVOTuhggMmMIIDIgYJKoZIhvcNAQkGMYIDEzCCAw8CAQEwfTBpMQsw
# CQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERp
# Z2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIw
# MjUgQ0ExAhAKgO8YS43xBYLRxHanlXRoMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZI
# hvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjYwNDIxMTUyODEx
# WjAvBgkqhkiG9w0BCQQxIgQgKtLRQO4PDpVUBHlNKJjcQoQH4Ym3JByWJrcU0GmT
# KJ8wDQYJKoZIhvcNAQEBBQAEggIAze0Oth61/k84cr9eM01P4WZZYX04GpOcsz4f
# dCB8GOOnOSQYitmiiiFiio1eSu1nRTHAodKjnXuoF0NKyTcUmpfdXxP0QnktIypS
# Yy/ZTdwdDbI4CWfBFneW/XYuDsDgDgPJ23puM6xSMmI9RnBvZlBkeA5/kbU8Cvw2
# 4U1ez/uWGepjXGukgxPO4jmxKj2pswZhJ7CRkk7MRWeaH5qHQUw0Op6VNJOGw8uL
# HJA6n6CjkKCAV995W1gRlsgcEvdtzYzze9RBCVAFpZ+lNA4e6+W2sMiKexvXWA/M
# h92wByaXN329ISI+Q+qvQWpaK+h5U88Gzmp8oKEWPVyphZDJp0d5PSf9axHkJuii
# Wucpm5PXGGn1F9Us6J9CDKJH1VW7FfhVIWlCj9m9LtwZKATx63rI7uYbJvDNeZwe
# imI9mvlgxtOBqIm0gv0llluOdC5sCtwa50tZoxukCOWV1/x9kv+GlyV63IuRuRyG
# eFxmJivyXv8QqCjrv3y14N2wer9+SOnQHktPaoQzNbsGxJ27mSp6Xed4WHPfIZ4P
# 2gua7CK++JSEGRZZE5wOSljz31WoawBnFLnvpKUhz7EzGdYZgYzRH5bWimwGcTsX
# vZ1mNqLTqND9l3iGcmRGJjZLLdU/ai+YVP2pUJE7rVNQboSf+nLXX/UKV8mMw+by
# 7xg3qlQ=
# SIG # End signature block
