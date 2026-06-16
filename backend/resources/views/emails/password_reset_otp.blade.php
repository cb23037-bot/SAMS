<!DOCTYPE html>
<html>
<body style="font-family: Arial, sans-serif; color: #111827; background-color: #F5F7FA; padding: 24px;">
    <table role="presentation" width="100%" style="max-width: 480px; margin: 0 auto; background: #ffffff; border-radius: 16px; padding: 32px;">
        <tr>
            <td>
                <h2 style="margin: 0 0 12px;">Password Reset Request</h2>
                <p style="font-size: 14px; line-height: 1.6; color: #374151;">
                    We received a request to reset the password for your SA Management account.
                    Use the verification code below to continue.
                </p>
                <p style="text-align: center; font-size: 32px; font-weight: 700; letter-spacing: 8px; color: #1E5BFF; margin: 24px 0;">
                    {{ $otp }}
                </p>
                <p style="font-size: 13px; line-height: 1.6; color: #5B6B86;">
                    This code will expire in 15 minutes. If you did not request a password reset,
                    you can safely ignore this email.
                </p>
            </td>
        </tr>
    </table>
</body>
</html>
