# Static Menu + Flutter Admin MVP

Architecture:
- `website/`: Astro static menu website
- `admin_app/`: Flutter RTL admin app
- `data/menu.json`: menu content
- `.github/workflows/deploy.yml`: GitHub Pages deployment

## Website
```bash
cd website
npm install
npm run dev
```

## Flutter admin
```bash
cd admin_app
flutter pub get
flutter run
```

The MVP Flutter app uses an abstract `MenuRepository` with a local JSON-backed implementation. Replace it with a GitHub API/Cloudflare Worker implementation for production credentials and remote commits.
