// Package email provides a thin interface for sending transactional emails
// and an SMTP implementation backed by Brevo (or any standard SMTP relay).
package email

import (
	"fmt"
	"net/smtp"
)

// Sender is the interface handlers depend on. Swap implementations freely.
type Sender interface {
	SendOTP(toAddress, toName, code string) error
}

// SMTPSender sends email via a standard SMTP relay.
type SMTPSender struct {
	host     string
	port     string
	username string
	password string
	from     string // e.g. "Tippsy <charliebissett906@gmail.com>"
}

// NewSMTPSender constructs an SMTPSender. from is the full "Name <addr>" sender string.
func NewSMTPSender(host, port, username, password, from string) *SMTPSender {
	return &SMTPSender{
		host:     host,
		port:     port,
		username: username,
		password: password,
		from:     from,
	}
}

// SendOTP sends a 6-digit verification code to the given address.
func (s *SMTPSender) SendOTP(toAddress, toName, code string) error {
	auth := smtp.PlainAuth("", s.username, s.password, s.host)

	subject := "Your Tippsy verification code"
	body := fmt.Sprintf(`Hi %s,

Your Tippsy verification code is:

    %s

This code expires in 15 minutes. If you didn't create a Tippsy account, you can ignore this email.

— The Tippsy Team
`, toName, code)

	msg := fmt.Sprintf(
		"From: %s\r\nTo: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n%s",
		s.from, toAddress, subject, body,
	)

	addr := s.host + ":" + s.port
	return smtp.SendMail(addr, auth, s.username, []string{toAddress}, []byte(msg))
}

// LogSender is a no-op implementation that prints OTPs to stdout.
// Use during local development when you have no SMTP credentials.
type LogSender struct{}

func (LogSender) SendOTP(toAddress, _ /*toName*/, code string) error {
	fmt.Printf("[email] OTP for %s: %s\n", toAddress, code)
	return nil
}
