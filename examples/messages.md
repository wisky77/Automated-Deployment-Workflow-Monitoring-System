# Example messages

## Slack (success)
```
✅ Deployment succeeded for *my-vercel-project* on branch *main*
<https://my-vercel-project.vercel.app|Open live app>
commit: 8f2a1b4
vercel: dpl_123abc
```

## Slack (failure)
```
🚨 Deployment failed for *my-vercel-project* on branch *main*
commit: 8f2a1b4
status: ERROR
error: Build failed: Could not resolve dependency 'xyz'
```

## Discord (success)
```
✅ Deployment succeeded for my-vercel-project on main | https://my-vercel-project.vercel.app
```

## Discord (failure)
```
🚨 Deployment failed for my-vercel-project on main | status=ERROR
```
