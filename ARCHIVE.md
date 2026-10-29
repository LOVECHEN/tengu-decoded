# 独立归档说明

本仓库是 [`wtfwhs/tengu-decoded`](https://github.com/wtfwhs/tengu-decoded)
的独立非 Fork 归档。原始内容继续按 CC BY 4.0 许可，并在
[`LICENSE`](LICENSE) 中归属于 `whs`。

## 保留模型

- `main` 保存首次克隆的源码、归档自动化脚本与持续分析报告。
- `upstream/<branch>` 跟踪每个上游分支最后一次观测到的顶端。
- `archive/heads/<branch>/<timestamp>-<object>` 为每个不同的上游分支顶端创建不可移动快照标签。
- `archive/tags/<tag>/<timestamp>-<object>` 保留每个观测到的上游标签对象。
- `upstream/<tag>` 镜像上游标签最新观测到的目标。
- `analysis/upstream-updates/` 在上游 `main` 变化时记录文件树与提交差异。

监控任务不删除任何快照标签，也不删除已保留的实时指针。因此，上游之后发生的
force-push、分支删除、标签替换、squash 或清空树提交，都不会让已被观测的对象从本归档中丢失。
无法消除的边界是观测频率：如果某个 ref 在两次监控运行之间创建后又被删除，则无法抓取。

定时工作流在每小时第 7 分钟和第 37 分钟运行，也可在 Actions 页面手动启动。

## 恢复示例

列出已观测的上游 `main` 快照：

```bash
git tag --list 'archive/heads/main/*' --sort=-refname
```

将某个快照恢复为本地分支：

```bash
git switch -c recovered-main 'archive/heads/main/<timestamp>-<object>'
```

比较两次观测：

```bash
git diff 'archive/heads/main/<older>' 'archive/heads/main/<newer>'
```
