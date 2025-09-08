# -*- coding: utf-8 -*-
from __future__ import annotations

import base64
import smtplib
from django.core.mail.backends.smtp import EmailBackend as DjangoEmailBackend


class Utf8EmailBackend(DjangoEmailBackend):
    """
    SMTP AUTH LOGIN sırasında kullanıcı/parolayı UTF-8 ile base64'leyip gönderir.
    smtplib.login() ASCII dayatmasına takılmamak için LOGIN akışını elle yapıyoruz.
    """

    def open(self):
        if self.connection:
            return False

        try:
            if self.use_ssl:
                self.connection = smtplib.SMTP_SSL(
                    self.host, self.port, timeout=self.timeout
                )
            else:
                self.connection = smtplib.SMTP(
                    self.host, self.port, timeout=self.timeout
                )

            self.connection.ehlo()
            if self.use_tls:
                self.connection.starttls()
                self.connection.ehlo()

            if self.username and self.password:
                self._login_utf8(self.username, self.password)

            return True
        except Exception:
            if self.connection:
                try:
                    self.connection.quit()
                except Exception:
                    pass
            self.connection = None
            raise

    def _login_utf8(self, username: str, password: str) -> None:
        # AUTH LOGIN
        code, resp = self.connection.docmd("AUTH", "LOGIN")
        if code != 334:
            raise smtplib.SMTPAuthenticationError(code, resp)

        # Username (utf-8 -> base64 -> ascii string)
        u = base64.b64encode(username.encode("utf-8")).decode("ascii")
        code, resp = self.connection.docmd(u)
        if code != 334:
            raise smtplib.SMTPAuthenticationError(code, resp)

        # Password (utf-8 -> base64 -> ascii string)
        p = base64.b64encode(password.encode("utf-8")).decode("ascii")
        code, resp = self.connection.docmd(p)
        if code != 235:
            raise smtplib.SMTPAuthenticationError(code, resp)
