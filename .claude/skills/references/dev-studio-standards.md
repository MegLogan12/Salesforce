# LOVING Dev Studio — Tech Stack and Publishing Standards

## Web Stack
- Framework: React 18 + Vite
- Styling: Tailwind CSS + shadcn/ui
- State: Zustand or React Query
- Backend: Supabase (Postgres + Auth + Storage + Edge Functions) or Node/Express
- Hosting: Vercel (preferred) or Netlify
- Domain: managed through Cloudflare for DNS + SSL
- Analytics: PostHog or Google Analytics 4

## Mobile Stack
- Framework: React Native + Expo (SDK 51+)
- Navigation: Expo Router v3
- Styling: NativeWind v4
- State: Zustand + React Query
- Storage: Expo SecureStore (sensitive), AsyncStorage (general)
- Offline: WatermelonDB for heavy offline data
- Camera: Expo Camera
- Location: Expo Location
- Push: Expo Notifications + FCM (Android) + APNs (iOS)
- Maps: React Native Maps
- Build service: EAS Build (Expo Application Services)

## Publishing Accounts Required
- Apple Developer Program: $99/year, Apple Developer account required
- Google Play Console: $25 one-time, Google account required
- Both require privacy policy URL before submission

## Code Standards
- TypeScript everywhere — no plain JS in new projects
- ESLint + Prettier configured in every repo
- Git flow: main (production) → staging → feature branches
- PR required before merge to staging or main
- No secrets in code — all via environment variables
- README required: setup instructions, environment variables list, deployment steps

## LOVING Brand Tokens
- Primary Green: #2D5016
- Secondary Green: #4A7C2F
- Warm Tan: #C8A96E
- Earth Brown: #6B4226
- Off-White: #F5F0E8
- Dark Text: #1A1A1A
- LOVING Orange accent: #D46B00
- Error Red: #C0392B
- Success Green: #27AE60

## Fonts
- Headings: Playfair Display or Lora (serif, warm, outdoor-living feel)
- Body: Inter or Outfit (clean, readable)
- Monospace (code/data): JetBrains Mono
