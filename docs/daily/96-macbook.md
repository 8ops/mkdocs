# MacBook Pro

M2 Pro

## brew

```bash
https://developer.aliyun.com/mirror/homebrew/

    # 替换brew.git:
    cd "$(brew --repo)"
    git remote set-url origin https://mirrors.aliyun.com/homebrew/brew.git
    # 替换homebrew-core.git:
    cd "$(brew --repo)/Library/Taps/homebrew/homebrew-core"
    git remote set-url origin https://mirrors.aliyun.com/homebrew/homebrew-core.git
    # 应用生效
    brew update
    # 替换homebrew-bottles:
    echo 'export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.aliyun.com/homebrew/homebrew-bottles' >> ~/.bash_profile
    source ~/.bash_profile

```



## xcode

```bash
sudo rm -rf /Library/Developer/CommandLineTools
xcode-select --install
/usr/bin/xcodebuild -version

xcode-select -print-path
# sudo xcode-select -s /Library/Developer/CommandLineTools
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

```



## hostname

```bash
sudo scutil --set HostName MacBook-Pro

```

