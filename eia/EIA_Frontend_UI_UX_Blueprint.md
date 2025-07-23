# Ariya – Frontend UI/UX Blueprint

## 🧱 Tech Stack

- **Framework**: ReactJS
- **Language**: TypeScript
- **Styling**: TailwindCSS
- **Build Tool**: Vite
- **Component Library**: shadcn/ui (for form, modal, tab, etc.)
- **Animation**: Framer Motion

---

## 🎯 Project Focus

We are building the frontend UI/UX of a decentralized event protocol that allows:

- Wallet-based event check-in
- Anonymous identity management
- NFT of Completion minting
- Convener discovery
- Sponsor dashboard with event KPIs
- Token-gated community hub (placeholder for now)

---

## 📁 Folder Structure

```
src/
│
├── components/         # Reusable components (Button, Card, Navbar)
├── pages/              # Main route pages
├── hooks/              # Custom React hooks
├── assets/             # Logos, images, icons
├── utils/              # Utility functions (e.g. formatters)
├── types/              # TypeScript interfaces
├── layouts/            # Page layouts (auth, dashboard)
├── styles/             # Tailwind and custom CSS
└── App.tsx             # App entrypoint
```

---

## 🧩 Pages & Views

### 1. 🏠 Landing Page (`/`)

- Hero section with call-to-action: “Create Event”, “Join Event”
- Features overview with icons
- "How it Works" steps (scroll animation)
- Footer with links

### 2. 🔐 Connect Wallet Modal (Global)

- Uses `@wagmi/core` + RainbowKit
- Optional email/Gmail fallback UI (non-functional for now)

### 3. 📅 Create Event (`/event/create`)

- Multi-step form (Wizard UI) using shadcn/ui `Tabs` or `Stepper`
- Fields: Title, Location, Date, Description, Banner Upload
- Optional: Sponsor fields (KPI inputs placeholder)

### 4. 🎫 My Events (`/events`)

- Tabs: Hosted | Attending | Completed
- Each event displayed in a Card:
  - Event title, status, time, attendance status
  - QR code reveal if available

### 5. 🧾 Event Details (`/event/:id`)

- Details page with:
  - Header image
  - About the event
  - Organizer info
  - Check-in CTA (button or QR)
  - Event completion status
  - NFT of Completion preview

### 6. 📷 QR Scan/Display UI (Verifier or User)

- QR code modal (user)
- Scanner interface (organizer)
- Scan success/failure animations

### 7. 🧑‍💼 Organizer Dashboard (`/dashboard/organizer`)

- Cards for each event with:
  - Status bars (check-ins, completion)
  - Escrow status (static)
  - Ratings summary (placeholder)

### 8. 🏆 Sponsor Dashboard (`/dashboard/sponsor`)

- KPI Metric Cards (e.g., Target: 100 check-ins)
- Event progress tracker
- Attendee rating average
- Status: Pending/Completed

### 9. 🌐 Convener Marketplace (`/organizers`)

- Public profiles of organizers
- On-chain reputation badge (mock)
- Search, sort, and filter organizers

### 10. 🫂 Token-Gated Community Hub (`/community`)

- Placeholder for future logic
- Message board UI, access gated via mock NFT badge

---

## 🎨 UI Guidelines

| Element           | Design Guideline                                               |
| ----------------- | -------------------------------------------------------------- |
| **Font**          | `Inter` or `Satoshi` – clean, legible                          |
| **Theme**         | Default to dark with gradient accent buttons                   |
| **Accent Colors** | #8E44FF (purple), #1ABC9C (teal), #F1C40F (yellow for rewards) |
| **Shadows**       | Use subtle glassmorphism (`bg-opacity`, `backdrop-blur`)       |
| **Buttons**       | Gradient-filled, large, rounded with hover glow                |
| **Cards**         | Soft shadows, border ring, hover animations                    |

---

## 🛠️ Components To Build (in `/components`)

- `Navbar.tsx`
- `ConnectWalletButton.tsx`
- `EventCard.tsx`
- `QRDisplay.tsx`
- `QRScanner.tsx`
- `StepWizard.tsx`
- `StatCard.tsx`
- `RatingStars.tsx`
- `UserAvatarBadge.tsx`

---

## 🧪 Next Steps

- Scaffold pages with `vite + react + typescript + tailwindcss`
- Add shadcn/ui setup
- Start building components and apply layout
- Integrate dummy data for simulating user/event/sponsor flows

---

## ✨ Notes

- Backend/smart contract integration will come later.
- Keep reusable components atomic and style via Tailwind utility classes.
- Keep interfaces (`types/index.ts`) for shared data models.
