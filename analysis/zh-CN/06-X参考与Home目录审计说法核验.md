# X 参考材料与“Home 目录审计”说法核验

## 参考信息

- 原始 X 帖：<https://x.com/make_claude/status/2115501814090969583?s=46>
- X status ID：`2115501814090969583`
- 发帖账号：`@make_claude`
- 本地保存日期：2026-10-29
- 相关主题：Claude 账号风控、所谓积分系统、cyber classifier、账号 hold。
- 说明：X 页面对自动抓取返回 403。本文件保存原始 URL、用户提供的评论原文以及基于 Claude Code 2.1.300 客户端和 Anthropic 公开材料的核验结果。

## 用户提供的评论原文

> They are missing the audit. Ive had 14 accounts blocked for cyber violations, and learned why I was getting blocked.
>
> When the classifiers detect violations of ToS for cyber, you get warned multiple times. If you trigger the audit, then Claude Code does a detailed scan of the home directory where you have Claude installed. If that audit turns up hacks, exploits, PoCs and hacking tooling? The account gets blocked. If however your home dir is clean of anything hacking related, you pass and the account survives.
>
> This is from direct experience. This point system may indeed be true, but it doesn't seem to include the audit - and Opus admitted the audit was the source of account blocks, so Im confident that its true.

该评论的作者、发布时间和直接评论 URL 未随文本提供，因此这里只把它视为待核验的用户提供材料，不把“14 个账号”视为已独立验证的事实。

## 中文翻译

> 他们漏掉了审计。我已经有 14 个账号因为网络安全违规被封，并弄清了自己为什么被封。
>
> 当分类器发现违反网络安全相关服务条款的行为时，你会收到多次警告。如果你触发了审计，Claude Code 就会详细扫描安装 Claude 的 home 目录。如果审计发现黑客脚本、exploit、PoC 和黑客工具，账号就会被封；如果 home 目录里没有任何黑客相关内容，就会通过审计，账号可以保留。
>
> 这是我的直接经验。这个积分系统可能确实存在，但似乎没有包括审计。Opus 也承认审计是账号被封的原因，所以我相信这是真的。

## 判定摘要

| 评论中的说法 | 判定 | 证据强度 |
|---|---|---|
| Claude 有 cyber safety classifiers | **真实** | Anthropic 官方资料直接确认 |
| 重复违规可能收到警告并导致封禁 | **大体真实，但不是保证固定次数** | 官方 safeguards 文档确认警告和重复违规封禁 |
| classifier 会审查模型实际读取的文件内容 | **真实** | 官方资料说明检查范围包括模型读取的文件、memory、connector 和 web 内容 |
| cyber 命中会触发隐藏的 home 目录全盘审计 | **当前未证实，2.1.300 客户端未发现调用链** | 官方资料无此说明，客户端无对应触发器 |
| home 中存在 exploit、PoC 或工具就会封号 | **当前未证实** | 未发现目录内容分类、工具签名或封号上报端点 |
| home 干净就一定通过并保号 | **当前未证实** | 没有客户端或官方规则支持 |
| `/auto-mode-setup` 会扫描部分 home 数据 | **真实，但这是用户主动运行的配置功能** | 2.1.300 客户端直接证据 |
| “Opus 承认了”可以证明内部机制 | **不能作为证据** | 模型回答不是产品内部遥测或服务端实现证明 |

最终结论：

> **评论中关于 cyber classifier 和重复违规封禁的部分有官方依据；关于“触发后秘密扫描整个 home，再按黑客文件决定封号”的核心说法，目前没有证据支持。最可能的混淆对象是用户主动运行的 `/auto-mode-setup` 环境扫描，或 Claude 在正常任务中读取并送入模型上下文的文件。**

---

## 01｜官方确认了什么

### Cyber classifier 确实存在

Anthropic 的 Cyber Verification Program 说明，一般用户在执行 malware analysis、exploit validation 等网络安全工作时，可能被 safety classifier 中断。获得不同验证等级的安全研究人员可以使用降低阻断强度的模型访问。

参考：<https://support.claude.com/en/articles/14604842-cyber-verification-program>

这能证明：

- cyber 请求会经过自动分类器。
- 恶意软件分析、exploit 验证等内容可能触发阻断。
- 账号的验证或信任状态可能影响可用能力。

这不能证明：

- classifier 会命令本地 CLI 扫描整个磁盘。
- 仅仅存放安全工具就构成违规。
- 目录中存在 PoC 文件会自动上传或导致封禁。

### 分类器检查“模型读取的内容”

Anthropic 关于模型切换和阻断的帮助文档明确写到，自动安全检查不只看用户最后一条消息，还会检查模型读取的 memory、connector 内容、web 搜索结果和文件。

参考：<https://support.claude.com/en/articles/16049681-why-claude-switched-models-in-your-conversation-with-opus-5-or-opus-5-5>

准确的数据链是：

```text
用户请求
  + 已进入模型上下文的历史消息
  + Claude 实际读取并加入上下文的文件
  + memory / connector / web 内容
      ↓
服务端 safety classifier
      ↓
正常回答 / fallback / refusal / block
```

这里的关键词是“模型实际读取”。它不等于客户端在后台递归扫描所有未打开文件。

### 重复违规可能导致账号处理

Anthropic 的 safeguards 文档确认：

- 系统会对被认为违反 Usage Policy 的提示发出警告。
- API 警告与账号范围内持续超过违规阈值有关。
- 重复违反 Usage Policy、地区或 ToS 问题可能导致账号被禁止。

参考：<https://support.claude.com/en/articles/8241253-safeguards-warnings-and-appeals>

所以“多次触发后账号可能被封”是合理的。

但官方没有承诺所有账号都会先收到固定次数警告，也没有说明 cyber 违规一定按“警告 N 次 → home audit → 封禁”的固定三段式执行。

### Anthropic 确实会调查严重滥用

Anthropic 的 Threat Intelligence 页面描述了 Detect、Investigate、Attribute、Disrupt 的调查流程，也公开过对恶意网络活动关联账号的封禁。

参考：<https://www.anthropic.com/threat-intelligence>

这里的 investigation 指服务端威胁情报和人工/自动调查，不能自动推导为本地 CLI 对用户 home 目录的文件审计。

---

## 02｜2.1.300 客户端中真正存在的本地扫描

### `/auto-mode-setup` 环境扫描

Claude Code 2.1.300 新增/强化了 `/auto-mode-setup`。界面文案直接说明它会花几分钟映射 repositories、trusted services 和 routine commands，然后把结果写入 auto-mode 设置。

客户端注册入口：

```text
/auto-mode-setup
  → vqe / Qjo 命令注册
  → Zkt() 解析用户选择的 scope 和 depth
  → Nts() 机械收集 pre-gathered recon
  → Qkt() 调用模型生成 auto-mode proposal
  → 用户审阅
  → 接受后写入 autoMode 设置
```

证据位置：

- `bundle/cli.min.js:12080`：注册 `auto-mode-setup` 命令。
- `bundle/cli.min.js:32163`：`Zkt()` 根据 `scope/depth` 决定是否收集 shell history、home repos 和所有项目。
- `bundle/cli.min.js:32164`：`Nts()` 构建 `Pre-gathered recon`。
- `bundle/cli.min.js:32309`：`Qkt()` 调用 `Nts()` 后让模型生成 proposal。
- `bundle/cli.min.js:32466`：非交互命令明确要求 `--wizard ... --propose`。
- `bundle/cli.min.js:51076`：交互式 wizard 收集用户选择，并在后台显示扫描任务。

### 它具体读取什么

按用户在 wizard 中选择的深度，可能收集：

| 收集项 | 代码中的显示名称 | 实际内容 |
|---|---|---|
| 当前项目文档 | `CLAUDE.md files and project docs` | 当前项目指令与文档 |
| 仓库事实 | `Repo facts` | 当前仓库结构和 Git 信息 |
| GitHub 仓库状态 | `Repo visibility & branch protection` | 可见性、ruleset、保护分支 |
| 同组织仓库文档 | `Sibling repo docs` | 用户选择 all-projects 且策略允许时读取 |
| 当前项目近期使用 | `Recent usage in this project (names only)` | 转录中的名称和统计，不是任意文件全文 |
| shell history | `Shell history (command words only)` | 命令词，带敏感路径过滤和读取上限 |
| home 下其他 Git 仓库 | `Other git repos under the home directory` | 最深两层、最多 20 个 repo，跳过大量目录 |
| 全部项目近期使用 | `Recent usage across all projects (names only)` | 用户选择 all-projects 时收集名称级信息 |
| 配置扫描 | `Config scans (names only)` | 已知客户端配置项名称 |

### Home 仓库扫描有明确边界

`It()` 的扫描参数和保护条件包括：

```text
maxRepoDepth = 2
maxDirsVisited = 4000
maxRepos = 20
timeoutMs = 8000
```

默认跳过：

```text
.git
node_modules
.oh-my-zsh
.vim
.tmux
.nvm
.rustup
.cargo
.local
.cache
.npm
.gem
.claude
OneDrive / Dropbox / Google Drive
macOS Library
```

它主要识别 Git 仓库和经过清洗的 remote，不会把每个源码文件全文加入扫描结果。

### 为什么它不是评论所说的“封号审计”

`/auto-mode-setup` 与评论描述有四个根本差别：

| 对比项 | `/auto-mode-setup` | 评论声称的 cyber audit |
|---|---|---|
| 触发方式 | 用户明确运行命令并选择范围 | classifier 命中后隐藏触发 |
| 界面可见性 | 有 wizard、后台任务和最终审阅 | 据称用户不可见 |
| 目的 | 给 auto-mode classifier 生成环境说明和规则 | 查找黑客工具并决定封号 |
| 代码连接 | `auto_mode_pregather` → proposal → settings | 未发现连接到 cyber refusal 或 `account_on_hold` |

当前代码中没有发现：

```text
cyber refusal
  → invoke Nts()
  → scan $HOME for exploit/PoC/tool signatures
  → upload file inventory
  → account_on_hold
```

---

## 03｜其他名字带 audit 的功能也不是它

### Prompt audit

`/doctor prompt-audit` 和 `/claude-api prompt-audit` 用于检查当前项目中的 prompts、tool descriptions、skills、`CLAUDE.md`、rules、commands 和 subagents 是否含有过时模式。

证据：

- `bundle/cli.min.js:21945`：`prompt-audit` 子命令文本。
- `bundle/cli.min.js:23051`：doctor 命令入口。
- `bundle/modules/prompt-audit-467e2f57.md`：具体流程。

它是用户主动运行的项目配置检查，不是封号审计。

### SDK credentials-file audit

`Qdn()` 只检查 `~/.claude/.credentials.json` 的文件权限和所有者：

- group/world writable 时拒绝。
- group/world readable 时拒绝。
- owner 不是当前 uid 时警告。

证据：`security-model.md` 的 “SDK credentials-file audit” 部分。

它是本地凭据文件安全检查，不检查 exploit、PoC 或黑客工具。

### Auto-mode dangerous-tool-use classifier

2.1.300 有 server-side `arbiter` 和本地 auto-mode classifier，用来判断某个待执行工具调用是否危险。

证据：

- `security-model.md` 的 “Auto-mode classifier” 和 “Server-side classifier” 部分。
- API beta：`dangerous-tool-use-2026-09-03`。
- 响应字段：`safeguard_results`。

它审查的是当前命令或工具调用是否应自动批准，不是扫描 home 目录后执行账号封禁。

---

## 04｜为什么“Opus 承认了”不能证明产品内部机制

Claude/Opus 可以根据用户描述、上下文和可见文件推测一个听起来连贯的解释，但模型本身并不能访问：

- Anthropic 内部账号风险数据库。
- Safeguards 团队的调查记录。
- 服务端 classifier 的私有权重和阈值。
- 某个账号被 hold 的内部原因码。
- 未提供给模型的 Claude Code 客户端运行日志。

除非回答同时给出了可独立核验的日志、API 响应、客户端函数、端点或官方文档，否则“模型承认”只是模型生成的陈述。

特别是在追问“你们是不是偷偷做了 X”时，模型可能顺着用户假设补全一个系统设计，并不代表它检索到了 Anthropic 内部事实。

---

## 05｜这 14 个账号为什么可能真的被封

评论者关于“14 个账号因 cyber violations 被封”的个人经历无法独立核实，但存在多种不需要 home audit 就能解释的路径：

```text
重复提交被 cyber classifier 标记的请求
    ↓
服务端累积账号级违规信号
    ↓
自动警告 / 模型 fallback / refusal
    ↓
Safeguards 或 Threat Intelligence 调查
    ↓
account_on_hold / account suspension
```

Claude Code 正常工作时，用户要求模型读取的 exploit、PoC、malware 或安全工具源码会进入模型上下文；分类器因而能看到这些内容。此时的观测来源是“任务中实际读取的内容”，不是隐藏的 home 全盘扫描。

如果 14 个账号还存在相同设备、网络、付款、行为或组织关联，服务端也可能进行账号聚类，但具体关联策略仍然不可见。

所以个人经历可能是真实的，评论者对因果机制的解释仍可能是错误的。

---

## 06｜如何真正验证是否发生过隐藏扫描

要把这项说法从传闻提升为证据，需要至少拿到以下一种材料：

| 证据 | 能证明什么 |
|---|---|
| CLI 文件系统 trace 显示 classifier 命中后递归打开 `$HOME` | 证明客户端发生隐藏扫描 |
| Proxyman/mitmproxy 抓到目录清单或文件摘要上传 | 证明扫描结果离开本机 |
| CLI 中存在 cyber-result → scan function 的静态调用链 | 证明产品实现了触发器 |
| 服务端响应给出 audit challenge 或 audit token | 证明服务端启动独立审计阶段 |
| 官方文档明确描述 home audit | 证明这是公开产品机制 |
| 多账号对照实验有完整日志且唯一变量是 home 内容 | 支持 home 内容影响裁决的因果关系 |

目前拥有的证据只支持：

```text
cyber classifier 存在
重复违规可能封号
模型读取的文件会进入 classifier 可见上下文
/auto-mode-setup 可在用户主动运行时扫描有限的 home 元数据
```

目前不支持：

```text
cyber 命中自动启动隐藏 home audit
任意 exploit / PoC / hacking tool 文件会被枚举并上传
home 干净就是账号存活的决定条件
```

---

## 07｜最终判定

对评论逐句拆分后：

1. “有 cyber classifier”是真的。
2. “重复违规可能警告和封号”大体是真的。
3. “分类器能看到 Claude 实际读取的文件”是真的。
4. “触发 audit 后自动扫描整个 home”没有官方或客户端证据。
5. “发现 PoC/工具就封号，目录干净就通过”没有证据。
6. “Opus 承认”不能用来证明内部实现。
7. 客户端里最相似的功能是 `/auto-mode-setup`，但它是用户主动运行、界面可见、用于配置 auto mode 的有限扫描，与账号封禁链没有代码关联。

因此，这段评论的整体可信度应标记为：

> **部分事实正确，但核心因果链未证实，且很可能把模型上下文检查和 `/auto-mode-setup` 环境扫描误认为封号审计。**

## 相关本地报告

- [X 长帖式账号风控完整解读](05-X长帖式账号风控完整解读.md)
- [账号风控检测点核验](01-账号风控检测点核验.md)
- [账号风控调用关联网](账号风控检测流程.html)
- [安全、权限与远程执行](04-安全权限与远程执行.md)
- [2.1.300 security model](../../versions/2.1.300/security-model.md)
- [2.1.300 security checks dataset](../../versions/2.1.300/data/security-checks.yaml)

