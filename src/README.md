# src/

放**你自己的**应用包（jar / 静态资源），不要提交到仓库。

```bash
cp /path/to/your-app.jar src/app.jar
docker compose up -d
```

`app.jar` 已在 `.gitignore` 中忽略，所以这个目录在 GitHub 上只有一个 README。
