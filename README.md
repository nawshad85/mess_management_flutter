# 🍽️ Mess Manager

A full-featured **Flutter** application for managing student mess (hostel dining) operations — built with **Firebase** and **GetX**.

## ✨ Features

### 🔐 Authentication
- Email/password registration & login
- Persistent auth sessions (no re-login after app restart)
- Role-based access: **Manager** and **Member**

### 🏠 Mess Management
- Create a mess with configurable rooms & capacities
- Invite members by username
- Accept/decline invitations
- Dashboard with real-time stats (total bazar cost, total meals, cost per meal)

### 🛏️ Room Management
- Assign members to rooms (manager only)
- Set bazar schedules with date ranges per room
- Visual indicators for active bazar periods

### 🛒 Bazar Tracking
- Add itemized bazar entries with individual costs
- View bazar history with cost breakdowns
- Auto-calculated totals

### 🍛 Meal Entry
- Record daily meal counts per person
- Date picker restricted to active bazar period
- Edit existing entries seamlessly
- Per-member meal tracking

### 💬 Real-time Chat
- Group chat within the mess
- Support for text, image, and document messages
- Real-time message streaming

### 🔄 Manager Controls
- Reset all bazar & meal entries with one tap
- Confirmation dialog to prevent accidental resets
- Full permission enforcement throughout the app

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter |
| State Management | GetX |
| Backend | Firebase (Auth, Firestore, Storage) |
| Architecture | Service → Controller → View |

## 📁 Project Structure

```
lib/
├── app/
│   ├── bindings/       # Dependency injection
│   ├── routes/         # Navigation routes
│   └── theme/          # Custom dark theme
├── controllers/        # Business logic (GetX controllers)
├── models/             # Data models
├── services/           # Firebase service layer
├── utils/              # Constants & validators
└── views/              # UI screens
    ├── auth/           # Login & Register
    ├── bazar/          # Bazar & Meal entry
    ├── chat/           # Real-time chat
    ├── home/           # Home with bottom navigation
    ├── mess/           # Dashboard, Create, Invite
    ├── room/           # Room management
    └── splash/         # Splash screen
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0+)
- Firebase project with **Authentication**, **Cloud Firestore**, and **Cloud Storage** enabled
- Android Studio / VS Code

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/nawshad85/mess_management_flutter.git
   cd mess_management_flutter
   ```

2. **Add Firebase config**
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Enable Email/Password authentication
   - Enable Cloud Firestore and Cloud Storage
   - Download `google-services.json` and place it in `android/app/`

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

## 📱 Screenshots

*Coming soon*

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

**Built with ❤️ using Flutter & Firebase**
