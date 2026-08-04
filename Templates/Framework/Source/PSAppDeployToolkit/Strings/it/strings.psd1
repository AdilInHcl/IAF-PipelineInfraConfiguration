@{
    BalloonTip = @{
        Start = @{
            Install = 'Installazione avviata.'
            Repair = 'La riparazione è iniziata.'
            Uninstall = 'La disinstallazione è iniziata.'
        }
        Complete = @{
            Install = 'Installazione completata.'
            Repair = 'Riparazione completata.'
            Uninstall = 'Disinstallazione completata.'
        }
        RestartRequired = @{
            Install = 'Installazione completata. È necessario un riavvio.'
            Repair = 'Riparazione completata. È richiesto un riavvio.'
            Uninstall = 'Disinstallazione completata. È necessario un riavvio.'
        }
        FastRetry = @{
            Install = 'Installazione non completata.'
            Repair = 'Riparazione non completata.'
            Uninstall = 'Disinstallazione non completata.'
        }
        Error = @{
            Install = 'Installazione fallita.'
            Repair = 'Riparazione fallita.'
            Uninstall = 'Disinstallazione non riuscita.'
        }
    }
    BlockExecutionText = @{
        Message = @{
            Install = "L'avvio di questa applicazione è stato temporaneamente bloccato per consentire il completamento di un'operazione di installazione."
            Repair = "L'avvio di questa applicazione è stato temporaneamente bloccato per consentire il completamento di un'operazione di riparazione."
            Uninstall = "L'avvio di questa applicazione è stato temporaneamente bloccato per consentire il completamento di un'operazione di disinstallazione."
        }
        Subtitle = @{
            Install = "{Toolkit\CompanyName} - Installazione dell'applicazione."
            Repair = "{Toolkit\CompanyName} - Riparazione dell'applicazione."
            Uninstall = "{Toolkit\CompanyName} - Disinstallazione App."
        }
    }
    DiskSpaceText = @{
        Message = @{
            Install = "Non si dispone di spazio su disco sufficiente per completare l'installazione di:`n{0}`n`nSpazio richiesto: {1}MB`nSpazio disponibile: {2}MB`n`nPer favore, liberi spazio su disco sufficiente per procedere con l'installazione."
            Repair = "Non si dispone di spazio su disco sufficiente per completare la riparazione di:`n{0}`n`nSpazio richiesto: {1}MB`nSpazio disponibile: {2}MB`n`nPer favore, liberi spazio su disco sufficiente per procedere con la riparazione."
            Uninstall = "Non si dispone di spazio su disco sufficiente per completare la disinstallazione di:`n{0}`n`nSpazio richiesto: {1}MB`nSpazio disponibile: {2}MB`n`nPer favore, liberi spazio su disco sufficiente per procedere con la disinstallazione."
        }
    }
    InstallationPrompt = @{
        Subtitle = @{
            Install = "{Toolkit\CompanyName} - Installazione dell'applicazione."
            Repair = "{Toolkit\CompanyName} - Riparazione app."
            Uninstall = "{Toolkit\CompanyName} - Disinstallazione app."
        }
    }
    ProgressPrompt = @{
        Message = @{
            Install = 'Installazione in corso. Attendere prego…'
            Repair = 'Riparazione in corso. Attendere…'
            Uninstall = 'Disinstallazione in corso. Attendere prego…'
        }
        MessageDetail = @{
            Install = "Questa finestra si chiuderà automaticamente al termine dell'installazione."
            Repair = "Questa finestra si chiuderà automaticamente al termine della riparazione."
            Uninstall = "Questa finestra si chiuderà automaticamente al termine della disinstallazione."
        }
        Subtitle = @{
            Install = "{Toolkit\CompanyName} - Installazione di applicazioni."
            Repair = "{Toolkit\CompanyName} - Riparazione dell'applicazione."
            Uninstall = "{Toolkit\CompanyName} - Disinstallazione dell'App."
        }
    }
    RestartPrompt = @{
        ButtonRestartLater = 'Riduci a icona.'
        ButtonRestartNow = 'Riavvia ora.'
        Message = @{
            Install = "Per completare l'installazione, deve riavviare il computer."
            Repair = "Affinché la riparazione sia completata, deve riavviare il computer."
            Uninstall = "Affinché la disinstallazione sia completata, deve riavviare il computer."
        }
        CustomMessage = ''
        MessageRestart = 'Il computer verrà automaticamente riavviato al termine del conto alla rovescia.'
        MessageTime = 'Salvi il suo lavoro e riavvii entro il tempo stabilito.'
        TimeRemaining = 'Tempo rimanente:'
        Title = 'Riavvio richiesto'
        Subtitle = @{
            Install = "{Toolkit\CompanyName} - Installazione di un'applicazione."
            Repair = "{Toolkit\CompanyName} - Riparazione dell'applicazione."
            Uninstall = "{Toolkit\CompanyName} - Disinstallazione App."
        }
    }
    CloseAppsPrompt = @{
        Classic = @{
            WelcomeMessage = @{
                Install = 'La seguente applicazione sta per essere installata:'
                Repair = 'La seguente applicazione sta per essere riparata:'
                Uninstall = 'La seguente applicazione sta per essere disinstallata:'
            }
            CloseAppsMessage = @{
                Install = "I seguenti programmi devono essere chiusi prima che l'installazione possa procedere.`n'nSalvi il suo lavoro, chiuda i programmi e poi continui. In alternativa, salvi il suo lavoro e clicchi su `“Chiudi programmi`”."
                Repair = "I seguenti programmi devono essere chiusi prima che la riparazione possa procedere.`n'nSalvi il suo lavoro, chiuda i programmi e poi continui. In alternativa, salvi il suo lavoro e clicchi su `“Chiudi programmi`”."
                Uninstall = "I seguenti programmi devono essere chiusi prima di procedere alla disinstallazione.`n'nSalvi il suo lavoro, chiuda i programmi e poi continui. In alternativa, salvi il suo lavoro e clicchi su `“Chiudi programmi`”."
            }
            ExpiryMessage = @{
                Install = "Può scegliere di rinviare l'installazione fino alla scadenza del rinvio:"
                Repair = "Può scegliere di rinviare la riparazione fino alla scadenza del rinvio:"
                Uninstall = "Può scegliere di rinviare la disinstallazione fino alla scadenza del rinvio:"
            }
            DeferralsRemaining = 'Rinvii rimanenti:'
            DeferralDeadline = 'Scadenza:'
            ExpiryWarning = 'Una volta scaduto il rinvio, non avrà più la possibilità di rinviare.'
            CountdownDefer = @{
                Install = "L'installazione continuerà automaticamente tra:"
                Repair = "La riparazione continuerà automaticamente in:"
                Uninstall = "La disinstallazione continuerà automaticamente tra:"
            }
            CountdownClose = @{
                Install = 'NOTA: I programmi verranno chiusi automaticamente in:'
                Repair = 'NOTA: I programmi verranno chiusi automaticamente in:'
                Uninstall = 'NOTA: I programmi verranno chiusi automaticamente in:'
            }
            ButtonClose = 'Chiudere &Programmi'
            ButtonDefer = '&Rinviare'
            ButtonContinue = '&Continuare'
            ButtonContinueTooltip = 'Selezioni “Continua” solo dopo aver chiuso le applicazioni sopra elencate.'
        }
        Fluent = @{
            DialogMessage = @{
                Install = 'Salvi il suo lavoro prima di continuare, perché le applicazioni seguenti verranno chiuse automaticamente.'
                Repair = 'Salvi il suo lavoro prima di continuare, perché le applicazioni seguenti verranno chiuse automaticamente.'
                Uninstall = 'Salvi il suo lavoro prima di continuare, perché le applicazioni seguenti verranno chiuse automaticamente.'
            }
            DialogMessageNoProcesses = @{
                Install = "Selezioni Install per continuare l'installazione."
                Repair = "Selezioni Repair per continuare con la riparazione."
                Uninstall = "Selezioni Disinstallazione per proseguire con la disinstallazione."
            }
            AutomaticStartCountdown = "Conto alla rovescia per l'avvio automatico"
            DeferralsRemaining = 'Rimanenti differimenti'
            DeferralDeadline = 'Scadenza di rinvio'
            ButtonLeftText = @{
                Install = "Chiudi le applicazioni e installa."
                Repair = "Chiudi applicazioni e ripara."
                Uninstall = "Chiudere le applicazioni e disinstallare."
            }
            ButtonLeftNoProcessesText = @{
                Install = 'Installa'
                Repair = 'Riparare'
                Uninstall = 'Disinstalla'
            }
            ButtonRightText = 'Rimandare'
            Subtitle = @{
                Install = "{Toolkit\CompanyName} - Installazione di un'applicazione."
                Repair = "{Toolkit\CompanyName} - Riparazione dell'applicazione."
                Uninstall = "{Toolkit\CompanyName} - Disinstallazione App."
            }
        }
        CustomMessage = ''
    }
}

# SIG # Begin signature block
# MIIigQYJKoZIhvcNAQcCoIIicjCCIm4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAj20L4zO86uhz1
# U41+bsyaVuhMZnIHXe+MGayp/OLsGaCCHK4wggQUMIIC/KADAgECAgQQAztrMA0G
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
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEICdbYVMJgied
# caTkOZIBd0YBlNe/gMSlm3WywaCTB0F6MA0GCSqGSIb3DQEBAQUABIIBAF2VMKyO
# dO0g7AmXWrFO0PUOwXQzAfjmUZcUoVkc3C3TIZadPmBZ0wK3/wcbb2mTxxGJYn7B
# C30uIxPCx3q/D3Fopsze2i6pkgN/2Pm7ZuQZp0Q9SQRI+4etnZ8MD7S41O5crvz5
# 2E6IiYBBpIg46e9q37b7kXynzNkiOug2VJyinEsMmEOCOnbzInpOnW9lHap7PdNL
# Ky0E8aWShB21vj4NSEXbdtJsxn+gZT2SG6JMU3H+Bz/0IWUNGCqvC27Zw8U/17y6
# +p2200O+ls1RuOYZga+mA7fWWfsA9yXdz3m7is8IswesetJyR3AHDTl0xLS3Zcsr
# jSWvorXbZAZvIQihggMmMIIDIgYJKoZIhvcNAQkGMYIDEzCCAw8CAQEwfTBpMQsw
# CQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERp
# Z2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIw
# MjUgQ0ExAhAKgO8YS43xBYLRxHanlXRoMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZI
# hvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjYwNDIxMTUyODA3
# WjAvBgkqhkiG9w0BCQQxIgQgFrfunmwVZOIjBUdNy7hVKz2glc0Q8eHKNBxbdBjL
# 5EQwDQYJKoZIhvcNAQEBBQAEggIAMwkYB2hKQf/4CuyC0+W9fNI+nHjs8wyExfAn
# kXawTxaYicXzCDhdtjSrtp1rwAEY+1oh2cDijNgHq2aJWvgiGnHJ99CcMhI9fZss
# gCvV/X1BiT8OmrzdGaD6lRLOR1FfGK1TBBswyYqfFB+1nszrZp2Ldmqc5WPElZ5J
# bzOZ7/7fsbTJTZayM2CYIe13HGCz0AikA1XCjyCqi6MrCA3C+oTLXDh3aDfo+4cv
# 0/Gzt76+8r+UBcCnElW4BL0vqVHyaw19xCYOyIMNmM3GZov1shNVmN9f/lrQnv+A
# UbYCkm7MPuCrOwRbVsSKcWGotebIMP5ZdR7xLIRFvPSH7QcY5JAb1hNvEPyx+COj
# 0HNXHyK9oIBCYeCcBAZADD8iD3zCDBqBFVXmx7/ZNgFq5Dz9ybf0kBXk5JzlLfWe
# Wy1E6OnS1Sd2jUip8klmE8r0VvpsHYMEpla7qKCCdz9IUYulEFM6lJ6wiESI9LLp
# GIPMp7Cu5H7WIigErjCphn/68Rm2F+08Iu+0ogULMQWjfXYUpXobrEej+CI5H0c5
# GHHQ5ti8BuyWgqPPfqgbVurRdX7Ag6S3BpO7FuXcs2X9JGeu82xhZHgc3mD54/Ak
# bOo9bInTAVDiTOFvxzGjuJNT+M4YwajtQrJBfHSgMQmFDUPk6sFbwaAzLOG0hr1e
# FiUXBpg=
# SIG # End signature block
