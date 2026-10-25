# 00 · 把仓库推上 GitHub（Windows / 10 分钟）

> 前提：已注册 GitHub 账号（截图里是 `Weis1`）。下面命令在 **Git Bash** 或 **PowerShell** 里都能跑。

## 一、先装 Git

- 下载 <https://git-scm.com/download/win>，一路默认安装
- 验证：

```bash
git --version
```

## 二、在网页上创建仓库（你截图那一步）

| 字段 | 填什么 | 说明 |
| --- | --- | --- |
| Owner | 你的账号 | 默认 |
| Repository name | `ops-lab` | 全小写，用短横线，别用中文和空格 |
| Description | `Linux 运维实验与排障记录：部署、脚本、故障排查手册` | 一句话说清 |
| Choose visibility | **Public** | 面试官要能直接打开；放了密码就完了，所以别放 |
| Add README | **On** | 有 README 才能被搜索引擎和 HR 看到 |
| Add .gitignore | No .gitignore | 我们本地已经有 `.gitignore` |
| Add license | No license | 个人仓库不需要 |

点 **Create repository**。

## 三、把本地这份骨架推上去

```bash
# 1. 进入解压后的 ops-lab 目录
cd /c/Users/86132/Desktop/11/ops-lab

# 2. 配置身份（只需一次，邮箱用 GitHub 的邮箱）
git config --global user.name "Weis1"
git config --global user.email "你的GitHub邮箱"

# 3. 初始化并提交
git init
git add .
git commit -m "init: 运维实验仓库，含排障手册与部署脚本"

# 4. 关联远程仓库（把 Weis1 换成你的用户名）
git branch -M main
git remote add origin https://github.com/Weis1/ops-lab.git

# 5. 推送（第一次会弹窗要求登录）
git push -u origin main
```

## 四、推送要密码怎么办

GitHub 从 2021 年起**不能用账号密码**推送，要用 **Personal Access Token**：

1. GitHub → 右上角头像 → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token (classic) → 勾选 `repo` → 生成后**立刻复制**（只显示一次）
3. `git push` 弹窗时：用户名填 `Weis1`，密码粘贴这串 token

## 五、常见报错

| 报错 | 原因 | 解决 |
| --- | --- | --- |
| `remote: Support for password authentication was removed` | 用了账号密码 | 换成 token（见上） |
| `failed to push some refs` | 远程有 README，本地没有 | `git pull --rebase origin main` 再 push |
| `Permission denied (publickey)` | 用了 SSH 地址但没配密钥 | 改用 https 地址，或配 SSH key |
| `fatal: not a git repository` | 不在仓库目录 | `cd` 到 ops-lab 再执行 |
| 推送超时/连不上 | 网络问题 | 多试几次，或配代理 |

## 六、日常怎么维护（每天 5 分钟）

```bash
# 改完文档或脚本后
git status                 # 看改了什么
git add docs/ scripts/     # 只加你改的
git commit -m "docs: 补充磁盘写满排查场景"
git push
```

**提交信息写清楚**：`docs:` 文档 / `feat:` 新增脚本 / `fix:` 修正错误。面试官会翻 commit 记录，一行一个「补充 XX 场景」比一次 `update` 强得多。

## 七、截图怎么放

1. 截图存到 `screenshots/`，命名 `序号-场景-日期.png`，例如 `03-disk-full-20261024.png`
2. 在对应 md 里引用：

```markdown
![磁盘写满](screenshots/03-disk-full-20261024.png)
```

3. 单张图建议 < 1MB，太大先压缩（<https://tinypng.com>）

> 也可以直接在 GitHub 网页上拖拽图片到 md 编辑器里，它会自动生成链接。
