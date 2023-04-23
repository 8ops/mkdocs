# smtp

## 一、实例代码

### 1.1 email.go

```golang linenums="1" title="email.go"
package email

import (
	"fmt"
	"strings"

	"gopkg.in/gomail.v2"
)

type TextType int

const (
	TEXT TextType = iota
	HTML
	IMAGE
)

type email struct {
	NickName   string
	UserName   string
	Passport   string
	Host       string
	Port       int
	TO         []string
	CC         []string
	AttachMent []string
	ImageView  struct {
		Header string
		Footer string
		Source string
		Link   string
	}
	Type TextType
}

func NewEmail() *email { return &email{} }

func (e *email) SetNickName(nickname string) *email {
	e.NickName = nickname
	return e
}

func (e *email) SetUserName(username string) *email {
	e.UserName = username
	return e
}

func (e *email) SetPassport(passport string) *email {
	e.Passport = passport
	return e
}

func (e *email) SetHost(host string) *email {
	e.Host = host
	return e
}

func (e *email) SetPort(port int) *email {
	e.Port = port
	return e
}

func (e *email) SetTo(to ...string) *email {
	e.TO = to
	return e
}

func (e *email) SetCC(cc ...string) *email {
	e.CC = cc
	return e
}

func (e *email) SetAttachMent(attach ...string) *email {
	e.AttachMent = attach
	return e
}

func (e *email) SetImageView(header, footer, source, link string) *email {
	e.ImageView.Header = header
	e.ImageView.Footer = footer
	e.ImageView.Source = source
	e.ImageView.Link = link
	return e
}

func (e *email) SetType(typ TextType) *email {
	e.Type = typ
	return e
}

func (e *email) Send(subject, content string) error {
	m := gomail.NewMessage()
	m.SetHeader("From", m.FormatAddress(e.UserName, e.NickName))
	m.SetHeader("To", e.TO...)
	m.SetHeader("Cc", e.CC...)
	m.SetHeader("Subject", subject)

	switch typ := e.Type; typ {
	case HTML:
		m.SetBody("text/html", content)
	case IMAGE:
		m.Embed(e.ImageView.Source)
		embedNameS := strings.Split(e.ImageView.Source, "/")
		embedName := embedNameS[len(embedNameS)-1]
		body := fmt.Sprintf(`%s<br/>
			%s<br/>
			<a href="%s" >
			<img src="cid:%s" alt="%s" />
			</a>
			<br/>%s
			`,
			e.ImageView.Header,
			content,
			e.ImageView.Link,
			embedName, embedName,
			e.ImageView.Footer,
		)
		m.SetBody("text/html", body)
	default:
		m.SetBody("text/plain", content)
	}

	for _, attach := range e.AttachMent {
		m.Attach(attach)
	}

	d := gomail.NewDialer(e.Host, e.Port, e.UserName, e.Passport)

	if err := d.DialAndSend(m); err != nil {
		return err
	}

	return nil
}

```

### 1.2 email_test.go

```golang linenums="1" title="email_test.go"
package email_test

import (
	"ops-report/pkg/config"
	"ops-report/pkg/email"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

var e = email.NewEmail()

func init() {
	conf := config.Conf

	e.SetNickName(conf.Email.NickName).
		SetUserName(conf.Email.UserName).
		SetPassport(conf.Email.Passport).
		SetHost(conf.Email.Host).
		SetPort(conf.Email.Port).
		SetTo(conf.Email.TO...).
		SetCC(conf.Email.CC...).
		SetAttachMent(conf.Email.AttachMent...)
}

func TestSendTEXT(t *testing.T) {
	var (
		subject = "【文本报告】This is Subject - " + time.Now().Format("20060201150405")
		content = "<h1>This is Content</h1>"
	)

	err := e.Send(subject, content)
	if assert.NoError(t, err); err != nil {
		t.Logf("Send OK.")
	}
}
func TestSendHTML(t *testing.T) {
	var (
		subject = "【网页报告】This is Subject - " + time.Now().Format("20060201150405")
		content = "<h2>This is Content</h2>"
	)

	e.SetType(email.HTML)
	err := e.Send(subject, content)
	if assert.NoError(t, err); err != nil {
		t.Logf("Send OK.")
	}
}

func TestSendIMAGE(t *testing.T) {
	var (
		subject = "【图表报告】This is Subject - " + time.Now().Format("20060201150405")
		content = "<h2>This is Content</h2>"
	)

	e.SetType(email.IMAGE).
		SetAttachMent("/Users/jesse/Downloads/books.png").
		SetImageView("HEADER", "FOOTER", "/Users/jesse/Downloads/books.png", "https://books.8ops.top")
	err := e.Send(subject, content)
	if assert.NoError(t, err); err != nil {
		t.Logf("Send OK.")
	}
}

```



## 二、常见问题

### 2.1 抄送失败

```bash
# 必须设置Header's Cc	
	m.SetHeader("Cc", e.CC...)
```

