# chromedp

## 一、使用实例

```golang title="screen.go"
package screen

import (
	"context"
	"log"
	"ops-report/pkg/config"
	"os"
	"sync"
	"time"

	"github.com/chromedp/cdproto/page"
	"github.com/chromedp/chromedp"
)

var (
	proxyAddr = "ws://127.0.0.1:9222/"
	ctx       = context.Background()
	once      sync.Once
)

func init() {
	once.Do(func() {
		log.Println("Init RemoteAllocator")
		if config.InCluster {
			// ignore cancel()
			// Setting Browser
			opts := append(
				chromedp.DefaultExecAllocatorOptions[:],
				chromedp.DisableGPU,
				chromedp.IgnoreCertErrors,
				chromedp.Flag("headless", false),
			)

			ctx, _ = chromedp.NewExecAllocator(ctx, opts...)

			ctx, _ = chromedp.NewRemoteAllocator(ctx, proxyAddr)
		}
		ctx, _ = chromedp.NewContext(ctx, chromedp.WithLogf(log.Printf))
	})
}

type screen struct {
	Addr   string
	Output string
}

func NewScreen(addr, output string) *screen {
	return &screen{addr, output}
}

func (s *screen) SetAddr(addr string) *screen {
	s.Addr = addr
	return s
}

func (s *screen) SetOutput(output string) *screen {
	s.Output = output
	return s
}

func (s *screen) PDF() error {
	var buf []byte
	if err := chromedp.Run(ctx,
		chromedp.Navigate(s.Addr),
		chromedp.ActionFunc(func(ctx context.Context) error {
			var err error
			buf, _, err = page.PrintToPDF().WithPrintBackground(false).Do(ctx)
			if err != nil {
				return err
			}
			return nil
		}),
	); err != nil {
		return err
	}

	if err := os.WriteFile(s.Output, buf, 0644); err != nil {
		return err
	}

	return nil
}

func (s *screen) Full() error {
	var buf []byte
	if err := chromedp.Run(ctx,
		chromedp.Navigate(s.Addr),
		chromedp.FullScreenshot(&buf, 90),
	); err != nil {
		return err
	}

	if err := os.WriteFile(s.Output, buf, 0644); err != nil {
		return err
	}
	return nil
}

func (s *screen) Area(selector string, height int64) error {
	var buf []byte
	if err := chromedp.Run(ctx,
		chromedp.Navigate(s.Addr),
		chromedp.Sleep(time.Second*10),
		chromedp.EmulateViewport(0, height),
		chromedp.Screenshot(selector, &buf),
	); err != nil {
		log.Fatal(err)
	}

	if err := os.WriteFile(s.Output, buf, 0o644); err != nil {
		log.Fatal(err)
	}

	return nil
}

```



## 二、常见问题

### 2.1 linux或docker下运少缺少google-chromedp

```bash
# 采用RemoteAllocator
docker run -d -p 9222:9222 --rm --name headless-shell chromedp/headless-shell:114.0.5720.4

```



### 2.2 采用RemoteAllocator截屏时中文乱码

```bash
# 原因是缺少中文字体
apt-get install -y ttf-wqy-microhei ttf-wqy-zenhei xfonts-wqy 
```



### 2.3 访问私有证书网站报ERR_CERT_AUTHORITY_INVALID

```bash
# TODO
```

