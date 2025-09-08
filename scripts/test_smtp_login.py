# -*- coding: utf-8 -*-
from __future__ import annotations

import os
import ssl
import smtplib
import base64

host = os.getenv("SMTP_HOST", "smtp.office365.com")
port = int(os.getenv("SMTP_PORT", "587"))
user = os.getenv("SMTP_USER", "")
pwd  = os.getenv("SMTP_PASS", "")

print("Host:", host)
print("Port:", port)
print("User:", user)

if not user or not pwd:
    raise SystemExit("SMTP_USER/SMTP_PASS boş.")

ctx = ssl.create_default_context()
smtp = smtplib.SMTP(host, port, timeout=30)
smtp.set_debuglevel(1)
smtp.ehlo()
smtp.starttls(context=ctx)
smtp.ehlo()

# AUTH LOGIN (UTF-8 base64)
code, resp = smtp.docmd("AUTH", "LOGIN")
if code != 334:
    raise smtplib.SMTPAuthenticationError(code, resp)

u = base64.b64encode(user.encode("utf-8")).decode("ascii")
code, resp = smtp.docmd(u)
if code != 334:
    raise smtplib.SMTPAuthenticationError(code, resp)

p = base64.b64encode(pwd.encode("utf-8")).decode("ascii")
code, resp = smtp.docmd(p)
if code != 235:
    raise smtplib.SMTPAuthenticationError(code, resp)

print("LOGIN OK")
smtp.quit()
