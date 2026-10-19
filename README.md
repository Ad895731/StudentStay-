# StudentStay

StudentStay is a modern student accommodation discovery and verification platform designed to simplify finding trusted housing near colleges and coaching institutes.

---

## 📌 Problem

Students relocating to a new city for college, coaching, internships, or jobs frequently struggle to find affordable, safe, and trustworthy rooms, PGs, and hostels near their destination. Common challenges include:
- Lack of verified property details and authentic student reviews.
- Lack of transparent pricing, sharing configurations, food options, and amenities.
- Inefficient search and discovery mechanisms without map visualizations or commute distance indicators.

---

## 💡 Solution

StudentStay provides a discovery experience tailored specifically to student housing:
- **Search & Filtering:** Search by city, college/institute, budget, commute distance, room sharing type, food availability, and key amenities.
- **Verification & Status:** Clear verification badges (`VERIFIED` vs `PENDING REVIEW`), availability indicators, and photo galleries.
- **Interactive Exploration:** Map-based view for locating stays near campus using OpenStreetMap markers and thumbnail previews.
- **Google Maps Directions:** Turn-by-turn navigation directly from property cards.
- **Role-Based Workflows:** Distinct portals and permissions for Students, Property Owners, and Platform Administrators.

---

## 🛠️ Tech Stack

- **Frontend:** Flutter & Dart (Cross-platform: Mobile, Web, Desktop) with Material 3
- **Backend:** FastAPI (Python 3.10+)
- **Database:** PostgreSQL with SQLAlchemy 2.x ORM & Alembic migrations
- **Authentication:** JWT (PyJWT) with Argon2 password hashing & Role-Based Access Control (RBAC)
- **Object Storage:** Supabase Storage (5 MB limit, binary magic-byte validation for JPEG, PNG, WebP)
- **Maps & Geolocation:** OpenStreetMap (`flutter_map` + `latlong2`), Haversine distance calculations, Google Maps directions (`url_launcher`)
- **Testing:** `pytest` (Backend - 77 tests) / `flutter test` (Frontend - 36 tests)

---

## 🚀 Development Status & Roadmap

- **Phase 1: Project Initialization & Foundation**
  - Modular FastAPI backend & Flutter frontend structure established with health check endpoint (`GET /health`).
- **Phase 2: Database Foundation**
  - PostgreSQL database connection configured with SQLAlchemy 2.x engine and sessionmaker.
  - `User` database model created and initial Alembic migration applied.
- **Phase 3: Authentication & Security**
  - Argon2 password hashing, user registration, JWT generation, and `GET /auth/me`.
- **Phase 4: Accommodation Database Design**
  - SQLAlchemy 2.x models: `Property`, `Room`, `Amenity`, `PropertyImage`, and `property_amenities` association table with cascading deletes and financial integrity constraints.
- **Phase 5: Property CRUD APIs**
  - `POST /properties`, `GET /properties`, `GET /properties/{id}`, `PATCH /properties/{id}`, `DELETE /properties/{id}` with strict owner/admin RBAC.
- **Phase 6: Search, Filtering, Sorting & Pagination**
  - Text search query (`q`) across title, description, city, address with `ilike`.
  - Room-level filters (`city`, `property_type`, `sharing_type`, `min_rent`, `max_rent`) applied via `EXISTS` subqueries to prevent duplicate records.
  - Deterministic sorting (`newest`, `rent_low_to_high`, `rent_high_to_low`) and pagination.
- **Phase 7: Maps, Exact Property Location & Google Maps Directions**
  - Interactive OpenStreetMap location picker with tap-to-place markers and coordinate validation.
  - Haversine distance calculations and radius filtering (`latitude`, `longitude`, `radius_km`).
  - One-tap Google Maps directions via `url_launcher`.
- **Phase 8A & 8B: Supabase Storage Integration & Image APIs**
  - Secure backend storage utility using Supabase Storage bucket (`property-images`).
  - Image upload (`POST /properties/{id}/images`) with magic byte validation (JPEG/PNG/WebP, 5 MB limit) and database rollback on failure.
  - Image deletion (`DELETE /properties/{id}/images/{image_id}`) with ownership validation.
- **Phase 8C: Flutter Image Picker & Gallery**
  - Multi-image selection from device gallery with pre-upload thumbnail previews, per-item removal, and carousel display on property details.
- **Phase 9: Complete StudentStay Flutter Frontend**
  - Explore Stays Screen: Search bar, Material 3 filter bottom sheet, sorting, pagination, and property cards.
  - Property Detail Screen: Carousel gallery, rooms breakdown, amenities chips, availability banner, and embedded mini map.
  - Owner Dashboard: My listings (`GET /properties/my`), verification status chips (`VERIFIED` / `PENDING REVIEW`), Add Property flow, and student access protection.
  - Profile & Account: Sign In / Create Account with role selection (Student / Owner) and session persistence via `shared_preferences`.
- **Phase 10: End-to-End Integration & Testing**
  - Added backend CORS middleware for Flutter Web, iOS, Android, and Desktop clients.
  - Platform-aware base URL resolution (`resolveBaseUrl`) supporting Android emulator (`10.0.2.2:8000`), iOS/Web/Desktop (`127.0.0.1:8000`), and custom physical device LAN IPs (`--dart-define=API_BASE_URL=...`).
  - User-friendly error message extraction from FastAPI responses.
- **Phase 11: Final QA, Bug Fixing & Stability**
  - Complete test suite verification (77 backend pytest tests, 36 Flutter tests, 0 analyze issues).
  - Live end-to-end integration verification against real PostgreSQL and Supabase Storage.

---

## 📂 Project Structure

```text
StudentStay/
├── frontend/                     # Flutter client application
│   ├── lib/
│   │   ├── models/               # Property, Room, Amenity, Image, User models
│   │   ├── screens/              # ExploreStays, ExploreMap, PropertyDetail, PropertyForm, OwnerDashboard, Profile
│   │   ├── services/             # ApiService, AuthService, DirectionsService
│   │   └── main.dart             # Main navigation shell (4 destinations)
│   ├── test/                     # 36 Flutter unit, widget, and E2E integration tests
│   └── pubspec.yaml              # Dependencies (flutter_map, latlong2, shared_preferences, etc.)
├── backend/                      # FastAPI backend service
│   ├── alembic/                  # Database migration scripts
│   ├── app/
│   │   ├── core/                 # Config, database, security, dependencies
│   │   ├── models/               # User, Property, Room, Amenity, PropertyImage
│   │   ├── routers/              # auth, properties, admin, health
│   │   ├── schemas/              # Pydantic validation schemas
│   │   ├── services/             # Supabase storage utility
│   │   ├── tests/                # 77 Pytest test cases
│   │   └── main.py               # FastAPI entrypoint with CORS middleware
│   ├── requirements.txt          # Python dependencies
│   └── .env.example              # Environment variables template
└── README.md
```

---

## ⚙️ Setup & Installation

### 1. Prerequisites
- **Python:** 3.10 or higher
- **PostgreSQL:** 14 or higher (running locally or remotely)
- **Flutter SDK:** 3.20 or higher
- **Supabase Account:** Free project with a public or authenticated bucket named `property-images`

---

### 2. Backend Setup

1. **Navigate to the backend directory and activate a virtual environment:**
   ```bash
   cd backend
   python3 -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   ```

2. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Configure environment variables:**
   ```bash
   cp .env.example .env
   ```
   Edit `.env` with your real settings:
   ```env
   DATABASE_URL=postgresql+psycopg://postgres:your_password@localhost:5432/studentstay_db
   JWT_SECRET_KEY=your-secure-random-secret-key-at-least-32-chars
   JWT_ALGORITHM=HS256
   ACCESS_TOKEN_EXPIRE_MINUTES=60
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_SECRET_KEY=your-supabase-service-role-or-secret-key
   SUPABASE_STORAGE_BUCKET=property-images
   ```

4. **Run database migrations:**
   ```bash
   alembic upgrade head
   ```

5. **Start the FastAPI backend server:**
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```
   * Interactive API docs: `http://localhost:8000/docs`
   * Health check: `http://localhost:8000/health`

---

### 3. Frontend Setup

1. **Navigate to the frontend directory:**
   ```bash
   cd frontend
   flutter pub get
   ```

2. **Run on your target platform:**
   * **Chrome (Web):**
     ```bash
     flutter run -d chrome
     ```
   * **macOS (Desktop):**
     ```bash
     flutter run -d macos
     ```
   * **Android Emulator:**
     ```bash
     flutter run -d emulator-5554
     ```
     *(Automatically routes to `http://10.0.2.2:8000`)*
   * **iOS Simulator:**
     ```bash
     flutter run -d iPhone
     ```
     *(Automatically routes to `http://127.0.0.1:8000`)*
   * **Physical Device (LAN IP):**
     ```bash
     flutter run --dart-define=API_BASE_URL=http://<YOUR_COMPUTER_IP>:8000
     ```

---

## 🧪 Testing

### Backend Tests (77 tests)
```bash
cd backend
source .venv/bin/activate
pytest -v
```

### Frontend Tests (36 tests)
```bash
cd frontend
flutter analyze
flutter test
```

---

## 🔒 Security Best Practices
- **No Secrets in Frontend:** The Flutter application contains zero database credentials, JWT secrets, or Supabase service keys.
- **Environment Isolation:** `.env` is strictly excluded from version control via `.gitignore`.
- **Magic Byte Validation:** All image uploads are validated by content magic bytes (not client file extensions).
- **Atomic Operations:** Cloud storage uploads are cleaned up automatically if database insertion fails.
