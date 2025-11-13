# Force Load New Files - Complete Steps

## 🎯 The Issue

You've rebuilt the frontend, restarted n8n 10 times, but browser still loads old JavaScript files.

## ✅ Nuclear Option - Guaranteed to Work

### Step 1: Check What n8n is Actually Serving

**After n8n starts, check backend console for:**
```
Editor is now accessible via: http://localhost:5678/n8nnet/
```

**Then open browser and check Network tab:**
- Request: `/n8nnet/assets/index-*.js`
- Look at the filename hash
- Is it `index-BFhrDNcH.js` (new) or something else (old)?

### Step 2: Force Browser to Load Fresh

**Try these in order:**

#### Option 1: Incognito/Private Window
```
Ctrl + Shift + N (Chrome)
Ctrl + Shift + P (Firefox)
```

Navigate to: `http://cmqacore.elevatelocal.com:5000/n8nnet/`

This guarantees no cache!

#### Option 2: Different Browser
Try Edge, Firefox, or another browser you haven't used.

#### Option 3: Disable Service Worker
```javascript
// In console:
navigator.serviceWorker.getRegistrations().then(registrations => {
  registrations.forEach(r => r.unregister());
  console.log('Service workers cleared');
  location.reload();
});
```

### Step 3: Check index.html

The index.html file references which JavaScript files to load.

**In browser, check:**
```
View > Developer > View Source
```

Look for:
```html
<script type="module" crossorigin src="/n8nnet/assets/index-??????.js"></script>
```

What's the hash? Is it `BFhrDNcH` (new) or something else (old)?

---

## 🔍 Debug: What File is Actually There

**Run this:**
```powershell
Get-ChildItem "C:\Git\n8n-mssql\packages\frontend\editor-ui\dist\index.html" | Select-Object LastWriteTime
```

**Then open:** `C:\Git\n8n-mssql\packages\frontend\editor-ui\dist\index.html`

Search for `index-` - what hash does it have?

---

## 💡 Alternative: Manually Set localStorage for Testing

Even with old files, you can test by manually setting:

```javascript
localStorage.setItem('ls.authorizationData', JSON.stringify({token: 'test'}));
localStorage.setItem('ls.database', JSON.stringify('test'));
location.reload();
```

If it STILL redirects to signin, then the old `isAuthenticated` code is running.

---

## 🎯 Try Incognito Mode First

That's the fastest way to verify if new files work!

